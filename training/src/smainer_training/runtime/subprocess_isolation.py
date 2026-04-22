"""
Subprocess isolation strategy for AGPL training engines.

Provides process isolation with resource limits and bearer token authentication
for engines with AGPL licenses that cannot be imported directly.
"""
from __future__ import annotations

import json
import secrets
import subprocess
import threading
import time
import signal
import os
from dataclasses import dataclass
from typing import Dict, Any, Optional, IO, Union
from pathlib import Path

from .container_strategy import ContainerStrategy, ContainerHandle
from ..core.exceptions import SecurityError


@dataclass(frozen=True)
class SubprocessHandle:
    """Handle to an isolated subprocess for AGPL engine execution."""
    process: subprocess.Popen[str]
    token: str
    working_dir: Path
    pid: int

    @classmethod
    def from_container_handle(cls, container_handle: ContainerHandle, process: subprocess.Popen[str], token: str, working_dir: Path) -> 'SubprocessHandle':
        """Convert from base ContainerHandle to typed SubprocessHandle."""
        return cls(
            process=process,
            token=token,
            working_dir=working_dir,
            pid=process.pid
        )


class SubprocessIsolationStrategy(ContainerStrategy):
    """
    Subprocess isolation strategy for AGPL engines.
    
    Launches training engines in isolated subprocesses with:
    - Resource limits (CPU/memory/time)
    - Bearer token authentication for IPC
    - Working directory isolation
    - Secret scrubbing on all communication
    """

    def __init__(self, 
                 max_cpu_percent: float = 80.0,
                 max_memory_gb: float = 8.0,
                 max_runtime_hours: float = 24.0,
                 sandbox_root: Path = Path("/tmp/smainer-training-sandbox")):
        self.max_cpu_percent = max_cpu_percent
        self.max_memory_gb = max_memory_gb
        self.max_runtime_hours = max_runtime_hours
        self.sandbox_root = sandbox_root
        self.active_processes: Dict[str, SubprocessHandle] = {}
        self._setup_sandbox()

    @property
    def name(self) -> str:
        return "subprocess_isolation"

    def _setup_sandbox(self) -> None:
        """Create sandbox directory with proper permissions."""
        self.sandbox_root.mkdir(mode=0o700, parents=True, exist_ok=True)
        # Ensure no other users can access sandbox
        os.chmod(self.sandbox_root, 0o700)

    def _generate_token(self) -> str:
        """Generate a secure bearer token for subprocess authentication."""
        return secrets.token_urlsafe(32)

    def _create_working_dir(self, job_id: str) -> Path:
        """Create isolated working directory for a job."""
        working_dir = self.sandbox_root / f"job_{job_id}_{int(time.time())}"
        working_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        return working_dir

    def _scrub_secrets(self, text: str) -> str:
        """Scrub potential secrets from text before logging/returning."""
        # Remove potential private keys (64 hex chars)
        import re
        text = re.sub(r'\b[a-fA-F0-9]{64}\b', '[REDACTED_PRIVATE_KEY]', text)
        # Remove potential bearer tokens
        text = re.sub(r'Bearer\s+[A-Za-z0-9_-]+', 'Bearer [REDACTED_TOKEN]', text)
        # Remove potential mnemonics (12 or more consecutive words)
        words = text.split()
        if len(words) >= 12:
            # Simple check for 12+ consecutive words that could be a mnemonic
            consecutive_words = []
            for word in words:
                if word.isalpha() and len(word) > 1:
                    consecutive_words.append(word)
                else:
                    consecutive_words = []
                
                if len(consecutive_words) >= 12:
                    # Found 12+ consecutive words, replace the whole sequence
                    sequence = ' '.join(consecutive_words)
                    text = text.replace(sequence, '[REDACTED_MNEMONIC]')
                    break
        return text

    def launch(self,
               engine_module: str,  # Changed from 'image' to be subprocess-specific 
               env: Dict[str, str],
               mounts: Dict[str, str],  # Ignored for subprocess - use working_dir
               gpu_mask: str) -> ContainerHandle:
        """Launch AGPL engine in isolated subprocess with resource limits."""
        
        # Generate secure token and working directory
        token = self._generate_token()
        job_id = env.get('JOB_ID', f'unknown_{int(time.time())}')
        working_dir = self._create_working_dir(job_id)
        
        # Prepare subprocess environment
        subprocess_env = {
            **os.environ,  # Inherit PATH, etc.
            **env,
            'CUDA_VISIBLE_DEVICES': gpu_mask,
            'AUTH_TOKEN': token,
            'WORKING_DIR': str(working_dir),
            'MAX_MEMORY_GB': str(self.max_memory_gb),
            'MAX_RUNTIME_HOURS': str(self.max_runtime_hours),
        }
        
        # Remove secrets from environment
        subprocess_env = {k: self._scrub_secrets(str(v)) if k not in ['AUTH_TOKEN'] else v 
                         for k, v in subprocess_env.items()}
        
        # Build subprocess command
        cmd = [
            'python', '-m', engine_module,
            '--token', token,
            '--working-dir', str(working_dir),
        ]
        
        try:
            # Launch subprocess with resource limits
            process = subprocess.Popen(
                cmd,
                env=subprocess_env,
                cwd=working_dir,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, 
                stderr=subprocess.PIPE,
                text=True,
                start_new_session=True,  # New process group for clean termination
            )
            
            # Create handle
            handle = SubprocessHandle(
                process=process,
                token=token,
                working_dir=working_dir,
                pid=process.pid
            )
            
            # Store handle for cleanup
            self.active_processes[str(process.pid)] = handle
            
            # Start resource monitoring thread
            self._start_resource_monitor(handle)
            
            # Return as base ContainerHandle (bridge pattern)
            return ContainerHandle(
                container_id=str(process.pid),
                strategy_name=self.name,
                pid=process.pid,
            )
            
        except Exception as e:
            # Clean up working directory on failure
            try:
                import shutil
                shutil.rmtree(working_dir, ignore_errors=True)
            except:
                pass
            # Scrub potential secrets from exception before raising
            scrubbed_error = self._scrub_secrets(str(e))
            raise SecurityError(f"Failed to launch isolated subprocess: {scrubbed_error}")

    def _start_resource_monitor(self, handle: SubprocessHandle) -> None:
        """Start background thread to monitor and enforce resource limits."""
        def monitor():
            try:
                import psutil
                process = psutil.Process(handle.pid)
                start_time = time.time()
                
                while handle.process.poll() is None:  # While process running
                    try:
                        # Check runtime limit
                        if time.time() - start_time > self.max_runtime_hours * 3600:
                            self._terminate_process(handle, "runtime limit exceeded")
                            break
                            
                        # Check memory limit
                        memory_info = process.memory_info()
                        memory_gb = memory_info.rss / (1024**3)
                        if memory_gb > self.max_memory_gb:
                            self._terminate_process(handle, f"memory limit exceeded: {memory_gb:.1f}GB")
                            break
                            
                        # Check CPU usage (average over last 1 second)
                        cpu_percent = process.cpu_percent(interval=1.0)
                        if cpu_percent > self.max_cpu_percent:
                            # Allow brief CPU spikes, only kill on sustained high usage
                            time.sleep(2)
                            cpu_percent_sustained = process.cpu_percent(interval=1.0)
                            if cpu_percent_sustained > self.max_cpu_percent:
                                self._terminate_process(handle, f"CPU limit exceeded: {cpu_percent_sustained:.1f}%")
                                break
                        
                    except psutil.NoSuchProcess:
                        # Process died naturally
                        break
                    except Exception:
                        # Monitor error - don't kill process
                        time.sleep(5)
                        
            except Exception:
                # Monitor setup failed - continue without monitoring
                pass

        monitor_thread = threading.Thread(target=monitor, daemon=True)
        monitor_thread.start()

    def _terminate_process(self, handle: SubprocessHandle, reason: str) -> None:
        """Terminate process due to resource limit violation."""
        try:
            # Send SIGTERM first, then SIGKILL if needed
            handle.process.terminate()
            try:
                handle.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                handle.process.kill()
                handle.process.wait()
        except Exception:
            pass
        finally:
            # Clean up tracking
            if str(handle.pid) in self.active_processes:
                del self.active_processes[str(handle.pid)]

    def stop(self, handle: ContainerHandle) -> None:
        """Stop isolated subprocess and clean up resources."""
        pid_str = str(handle.pid)
        if pid_str not in self.active_processes:
            return

        subprocess_handle = self.active_processes[pid_str]
        
        try:
            # Graceful termination
            subprocess_handle.process.terminate()
            try:
                subprocess_handle.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                # Force kill
                subprocess_handle.process.kill()
                subprocess_handle.process.wait()
                
        except Exception:
            pass
        finally:
            # Clean up working directory
            try:
                import shutil
                shutil.rmtree(subprocess_handle.working_dir, ignore_errors=True)
            except:
                pass
            
            # Remove from tracking
            if pid_str in self.active_processes:
                del self.active_processes[pid_str]

    def is_running(self, handle: ContainerHandle) -> bool:
        """Check if subprocess is still running."""
        pid_str = str(handle.pid)
        if pid_str not in self.active_processes:
            return False
            
        subprocess_handle = self.active_processes[pid_str]
        return subprocess_handle.process.poll() is None

    def communicate(self, handle: ContainerHandle, message: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send authenticated message to subprocess and get response.
        
        All messages include bearer token for authentication.
        All responses are scrubbed for secrets before returning.
        """
        pid_str = str(handle.pid)
        if pid_str not in self.active_processes:
            raise SecurityError(f"Subprocess {handle.pid} not found")
            
        subprocess_handle = self.active_processes[pid_str]
        
        # Add authentication token
        authenticated_message = {
            "auth_token": subprocess_handle.token,
            **message
        }
        
        try:
            # Send message
            message_json = json.dumps(authenticated_message)
            subprocess_handle.process.stdin.write(message_json + "\\n")
            subprocess_handle.process.stdin.flush()
            
            # Read response
            response_line = subprocess_handle.process.stdout.readline()
            if not response_line:
                raise SecurityError("Subprocess closed connection")
                
            response = json.loads(response_line.strip())
            
            # Scrub secrets from response
            response_str = json.dumps(response)
            scrubbed_str = self._scrub_secrets(response_str)
            return json.loads(scrubbed_str)
            
        except Exception as e:
            # Scrub potential secrets from exception before raising
            scrubbed_error = self._scrub_secrets(str(e))
            raise SecurityError(f"Failed to communicate with subprocess: {scrubbed_error}")