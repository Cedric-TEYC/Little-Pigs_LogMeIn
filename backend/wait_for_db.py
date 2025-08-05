import socket
import time
import sys

def wait_for(host, port, timeout=60):
    start_time = time.time()
    while True:
        try:
            with socket.create_connection((host, port), timeout=3):
                print(f"{host}:{port} is available")
                return 0
        except (OSError, ConnectionRefusedError):
            if time.time() - start_time >= timeout:
                print(f"Timeout reached after {timeout}s, {host}:{port} still not available")
                return 1
            print(f"Waiting for {host}:{port}...")
            time.sleep(3)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python wait_for_db.py <host> <port> [timeout]")
        sys.exit(2)
    host = sys.argv[1]
    port = int(sys.argv[2])
    timeout = int(sys.argv[3]) if len(sys.argv) > 3 else 60
    sys.exit(wait_for(host, port, timeout))
