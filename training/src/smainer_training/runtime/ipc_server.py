"""
Unix socket IPC server for training service communication.

Provides HTTP over Unix socket interface with bearer token authentication
for secure communication between the provider daemon and training service.
This is the boundary where no OOP patterns leak out.
"""
from __future__ import annotations

import hmac
import json
import os
import socket
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Dict, Any, TYPE_CHECKING, Optional
from urllib.parse import urlparse, parse_qs

if TYPE_CHECKING:
    from ..service.training_service import TrainingService


class UnixHTTPServer(HTTPServer):
    """HTTP server that listens on Unix domain socket."""
    
    def __init__(self, socket_path: str, handler_class: type, training_service: TrainingService, bearer_token: str):
        self.socket_path = socket_path
        self.training_service = training_service
        self.bearer_token = bearer_token  # Store bearer token for handler access
        
        # Remove existing socket file before initialization
        try:
            os.unlink(socket_path)
        except FileNotFoundError:
            pass
        
        # Initialize base server attributes manually to avoid network initialization
        self.RequestHandlerClass = handler_class
        self.socket_type = socket.SOCK_STREAM
        self.allow_reuse_address = False
        self.server_address = socket_path
        
        # Initialize threading attributes from BaseServer
        self._BaseServer__is_shut_down = threading.Event()
        self._BaseServer__shutdown_request = False
        self.daemon_threads = False
        self.block_on_close = True
        
        # Create and configure Unix domain socket
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.socket.bind(socket_path)
        self.socket.listen(5)


class TrainingRequestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for training service endpoints."""
    
    def __init__(self, *args, **kwargs):
        # Get bearer token from environment or server config
        self._bearer_token: Optional[str] = None
        super().__init__(*args, **kwargs)
    
    def address_string(self) -> str:
        """Override address_string to handle Unix socket clients."""
        # Unix domain sockets don't have meaningful client addresses
        return "unix-socket"
        
    def log_message(self, format: str, *args) -> None:
        """Override log_message to handle Unix socket logging."""
        # Use a simplified log format for Unix sockets
        import sys
        sys.stderr.write(f"[{self.log_date_time_string()}] {format % args}\n")
    
    @property
    def bearer_token(self) -> str:
        """Get bearer token from server config, fail securely if not configured."""
        if self._bearer_token is None:
            # Get from server's bearer_token attribute (set during initialization)
            if hasattr(self.server, 'bearer_token') and self.server.bearer_token:
                self._bearer_token = self.server.bearer_token
            else:
                raise RuntimeError("Bearer token not configured - authentication unavailable")
        return self._bearer_token
    
    def _send_json_response(self, status_code: int, data: Dict[str, Any]) -> None:
        """Send JSON response with proper headers."""
        response_data = json.dumps(data).encode('utf-8')
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response_data)))
        self.end_headers()
        self.wfile.write(response_data)
        
    def _check_auth(self) -> bool:
        """Check bearer token authentication using constant-time comparison."""
        auth_header = self.headers.get('Authorization', '')
        
        if not auth_header.startswith('Bearer '):
            return False
            
        provided_token = auth_header[7:].strip()  # Remove 'Bearer ' prefix
        
        if not provided_token:
            return False
            
        try:
            expected_token = self.bearer_token
            # Use constant-time comparison to prevent timing attacks
            return hmac.compare_digest(provided_token, expected_token)
        except RuntimeError:
            # Bearer token not configured - fail securely
            return False
        
    def _get_training_service(self) -> TrainingService:
        """Get training service instance from server."""
        return self.server.training_service  # type: ignore
        
    def do_POST(self) -> None:
        """Handle POST requests."""
        if not self._check_auth():
            self._send_json_response(401, {"error": "Authentication required"})
            return
            
        if self.path == '/jobs':
            self._handle_submit_job()
        else:
            self._send_json_response(404, {"error": "Not found"})
            
    def do_GET(self) -> None:
        """Handle GET requests.""" 
        if not self._check_auth():
            self._send_json_response(401, {"error": "Authentication required"})
            return
            
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        
        if path.startswith('/jobs/') and path.endswith('/events'):
            # SSE endpoint: GET /jobs/{id}/events
            job_id = path.split('/')[-2]
            self._handle_stream_events(job_id)
        elif path.startswith('/jobs/'):
            # Status endpoint: GET /jobs/{id}
            job_id = path.split('/')[-1]
            self._handle_get_status(job_id)
        elif path == '/jobs':
            # List jobs endpoint
            self._handle_list_jobs()
        else:
            self._send_json_response(404, {"error": "Not found"})
            
    def do_DELETE(self) -> None:
        """Handle DELETE requests."""
        if not self._check_auth():
            self._send_json_response(401, {"error": "Authentication required"})
            return
            
        if self.path.startswith('/jobs/'):
            job_id = self.path.split('/')[-1]
            self._handle_cancel_job(job_id)
        else:
            self._send_json_response(404, {"error": "Not found"})
            
    def _handle_submit_job(self) -> None:
        """Handle job submission."""
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            spec_dict = json.loads(body)
            
            training_service = self._get_training_service()
            job_id = training_service.submit_job(spec_dict)
            
            self._send_json_response(201, {"job_id": job_id})
        except json.JSONDecodeError:
            self._send_json_response(400, {"error": "Invalid JSON"})
        except Exception as e:
            self._send_json_response(500, {"error": str(e)})
            
    def _handle_get_status(self, job_id: str) -> None:
        """Handle status request."""
        try:
            training_service = self._get_training_service()
            status = training_service.get_status(job_id)
            self._send_json_response(200, status)
        except Exception as e:
            self._send_json_response(500, {"error": str(e)})
            
    def _handle_list_jobs(self) -> None:
        """Handle list jobs request."""
        try:
            training_service = self._get_training_service()
            jobs = training_service.list_jobs()
            self._send_json_response(200, {"jobs": jobs})
        except Exception as e:
            self._send_json_response(500, {"error": str(e)})
            
    def _handle_cancel_job(self, job_id: str) -> None:
        """Handle job cancellation."""
        try:
            training_service = self._get_training_service()
            success = training_service.cancel_job(job_id)
            if success:
                self._send_json_response(200, {"cancelled": True})
            else:
                self._send_json_response(404, {"error": "Job not found"})
        except Exception as e:
            self._send_json_response(500, {"error": str(e)})
            
    def _handle_stream_events(self, job_id: str) -> None:
        """Handle Server-Sent Events stream for job progress."""
        try:
            training_service = self._get_training_service()
            
            # Set SSE headers
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Connection', 'keep-alive')
            self.end_headers()
            
            # Stream progress events
            for event in training_service.stream_progress(job_id):
                event_data = {
                    "job_id": event.job_id,
                    "timestamp": event.timestamp.isoformat(),
                    "step": event.step,
                    "total_steps": event.total_steps,
                    "loss": event.loss,
                    "learning_rate": event.learning_rate,
                    "throughput_tokens_per_sec": event.throughput_tokens_per_sec,
                    "gpu_utilization_pct": event.gpu_utilization_pct,
                    "vram_used_gb": event.vram_used_gb,
                }
                
                # Send SSE event
                self.wfile.write(f"data: {json.dumps(event_data)}\n\n".encode())
                self.wfile.flush()
                
        except Exception as e:
            # Send error event and close stream
            error_event = {"error": str(e)}
            self.wfile.write(f"data: {json.dumps(error_event)}\n\n".encode())


class UnixSocketIPCServer:
    """
    Unix socket IPC server for training service communication.
    
    Provides the Unix socket + HTTP + bearer token boundary that isolates
    the training system from the provider daemon. No OOP patterns leak
    across this boundary.
    """
    
    def __init__(self, socket_path: str, training_service: TrainingService, bearer_token: Optional[str] = None):
        self.socket_path = socket_path
        self.training_service = training_service
        self.server: UnixHTTPServer | None = None
        self.server_thread: threading.Thread | None = None
        
        # Configure bearer token with secure defaults
        if bearer_token is None:
            # Try to get from environment
            bearer_token = os.environ.get('TRAINING_SERVICE_BEARER_TOKEN')
            
        if not bearer_token:
            # Check if we're in production mode (no development/test indicators)
            is_production = (
                os.environ.get('TRAINING_SERVICE_ENVIRONMENT', '').lower() == 'production' or
                os.environ.get('NODE_ENV', '').lower() == 'production' or
                # If no explicit environment set, assume production for security
                (not os.environ.get('TRAINING_SERVICE_ENVIRONMENT') and 
                 not os.environ.get('NODE_ENV'))
            )
            
            if is_production:
                raise ValueError(
                    "Bearer token required for authentication. "
                    "Set TRAINING_SERVICE_BEARER_TOKEN environment variable."
                )
            else:
                # Development/test mode: use a secure default with warning
                import warnings
                bearer_token = "dev-training-token-2026-NOT-FOR-PRODUCTION"
                warnings.warn(
                    "Using development bearer token. Set TRAINING_SERVICE_BEARER_TOKEN "
                    "environment variable for production deployment.",
                    UserWarning,
                    stacklevel=2
                )
        
        self.bearer_token = bearer_token
        
    def start(self) -> None:
        """Start the IPC server in a background thread."""
        self.server = UnixHTTPServer(
            self.socket_path,
            TrainingRequestHandler,
            self.training_service,
            self.bearer_token
        )
        
        self.server_thread = threading.Thread(
            target=self.server.serve_forever,
            daemon=True
        )
        self.server_thread.start()
        
    def stop(self) -> None:
        """Stop the IPC server and clean up."""
        if self.server:
            self.server.shutdown()
            self.server.server_close()
            
        if self.server_thread:
            self.server_thread.join(timeout=5.0)
            
        # Clean up socket file
        import os
        try:
            os.unlink(self.socket_path)
        except FileNotFoundError:
            pass