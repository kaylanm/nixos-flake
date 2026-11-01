"""Exercise generated nginx routing against local fixtures, never the live stack.

Usage: python3 check-proxy.py NGINX_CONFIG NGINX_BINARY
Only pid/log/temp paths, worker count and listen/upstream ports are isolated.
"""
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time


def fixture(name):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            upgrade = self.headers.get("Upgrade", "").lower() == "websocket"
            if upgrade:
                self.send_response(101)
                self.send_header("Upgrade", "websocket")
                self.send_header("Connection", "Upgrade")
                self.send_header("X-Fixture", name)
                self.send_header("X-Fixture-Path", self.path)
                self.end_headers()
            else:
                body = json.dumps({"fixture": name, "path": self.path,
                    "host": self.headers.get("Host"),
                    "proto": self.headers.get("X-Forwarded-Proto")}).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        def log_message(self, *args):
            pass
    return Handler


def main():
    servers = [ThreadingHTTPServer(("127.0.0.1", 0), fixture(n)) for n in ("frontend", "backend")]
    for server in servers:
        threading.Thread(target=server.serve_forever, daemon=True).start()
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        config = Path(sys.argv[1]).read_text()
        config = config.replace("pid /run/nginx/nginx.pid;", f"pid {root}/nginx.pid;")
        config = config.replace("worker_processes auto;", "worker_processes 1;")
        config = config.replace("listen 127.0.0.1:3180;", f"listen 127.0.0.1:{port};")
        for original, server in zip((3100, 8180), servers):
            config = config.replace(f"127.0.0.1:{original}", f"127.0.0.1:{server.server_port}")
        config = config.replace("http {", f"http {{\naccess_log off;\nclient_body_temp_path {root}/body;\nproxy_temp_path {root}/proxy;")
        path = root / "nginx.conf"
        path.write_text(config)
        command = [sys.argv[2], "-p", str(root), "-c", str(path), "-e", "stderr"]
        subprocess.run(command + ["-t"], check=True)
        with (root / "nginx.log").open("w+") as log:
            process = subprocess.Popen(command, stdout=log, stderr=log)
            try:
                for _ in range(100):
                    try:
                        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                            break
                    except OSError:
                        if process.poll() is not None:
                            raise RuntimeError("nginx exited during startup")
                        time.sleep(0.05)
                for target, expected in (("/", "frontend"), ("/api/config?probe=1", "frontend"),
                        ("/uploads/example", "frontend"), ("/health", "backend"),
                        ("/readyz", "backend"), ("/healthz", "backend")):
                    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=3)
                    connection.request("GET", target, headers={"Host": "untrusted.invalid", "X-Forwarded-Proto": "http"})
                    response = connection.getresponse()
                    body = json.loads(response.read())
                    assert response.status == 200, (target, response.status)
                    assert body == {"fixture": expected, "path": target,
                        "host": "multica.manx-in.ts.net", "proto": "https"}, body
                    connection.close()
                for target in ("/ws?probe=1", "/api/daemon/ws?probe=1"):
                    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=3)
                    connection.request("GET", target, headers={"Upgrade": "websocket", "Connection": "Upgrade"})
                    response = connection.getresponse()
                    assert response.status == 101, (target, response.status)
                    assert response.getheader("X-Fixture") == "backend"
                    assert response.getheader("X-Fixture-Path") == target
                    assert response.getheader("Upgrade").lower() == "websocket"
                    connection.close()
                print("PASS: generated nginx syntax, six HTTP routes, two WebSocket upgrades, path/query and HTTPS header preservation")
            finally:
                process.terminate()
                process.wait(timeout=5)
                log.seek(0)
                errors = log.read()
                if errors:
                    print(errors, file=sys.stderr)
    for server in servers:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
