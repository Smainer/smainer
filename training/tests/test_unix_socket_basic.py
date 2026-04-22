"""
Simple test to verify Unix socket server functionality.
"""
import os
import socket
import tempfile


def test_unix_socket_basic():
    """Test basic Unix socket creation and binding."""
    temp_dir = tempfile.mkdtemp()
    socket_path = os.path.join(temp_dir, "test.sock")
    
    # Create Unix socket
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    
    try:
        # Remove existing socket file
        try:
            os.unlink(socket_path)
        except FileNotFoundError:
            pass
            
        # Bind and listen
        sock.bind(socket_path)
        sock.listen(5)
        
        print(f"Successfully bound Unix socket to {socket_path}")
        
        # Verify socket file exists
        assert os.path.exists(socket_path)
        print("Socket file created successfully")
        
    finally:
        sock.close()
        try:
            os.unlink(socket_path)
        except FileNotFoundError:
            pass
        os.rmdir(temp_dir)


if __name__ == "__main__":
    test_unix_socket_basic()
    print("Unix socket test passed!")