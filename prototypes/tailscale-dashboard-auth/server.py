"""Linux-only private UDS launcher. No TCP, no proxy-header trust, no live config."""

import argparse
import os
import socket
import stat
import struct
from contextlib import contextmanager
from pathlib import Path

import uvicorn
from tailscale_auth import IdentityGate, RequestProvider
from uvicorn.protocols.http.h11_impl import H11Protocol
from uvicorn.protocols.websockets.websockets_sansio_impl import WebSocketsSansIOProtocol


@contextmanager
def private_socket(path):
    path = Path(path).absolute()
    parent = path.parent
    info = parent.lstat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) != 0o700
    ):
        raise ValueError(
            f"socket parent must be an owned, non-symlink 0700 directory (uid={os.getuid()}, owner={info.st_uid}, mode={stat.S_IMODE(info.st_mode):o})"
        )
    if path.exists() or path.is_symlink():
        raise ValueError("refusing to replace existing socket/path")
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    bound = False
    old_umask = os.umask(0o177)
    try:
        try:
            sock.bind(str(path))
            bound = True
            os.chmod(path, 0o600)
        finally:
            os.umask(old_umask)
        sock.listen(128)
        sock.setblocking(False)
        yield sock
    finally:
        sock.close()
        if bound:
            path.unlink(missing_ok=True)


def protocols(proxy_uid, proof):
    """Authenticate the kernel peer on BOTH the HTTP and WS protocol paths."""

    class PeerGuard:
        def connection_made(self, transport):
            super().connection_made(transport)
            peer = transport.get_extra_info("socket")
            try:
                if peer.family != socket.AF_UNIX:
                    raise ValueError("Unix socket required")
                _, uid, _ = struct.unpack(
                    "3i", peer.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12)
                )
                if uid != proxy_uid:
                    raise ValueError("untrusted Unix peer uid")
            except (AttributeError, OSError, ValueError):
                # Fail closed even if bytes arrive before transport.close completes.
                async def denied(scope, receive, send):
                    if scope["type"] == "websocket":
                        await send({"type": "websocket.close", "code": 1008})
                    else:
                        await send(
                            {
                                "type": "http.response.start",
                                "status": 403,
                                "headers": [],
                            }
                        )
                        await send({"type": "http.response.body", "body": b""})

                self.app = denied
                transport.close()
                return
            downstream = self.app

            async def trusted(scope, receive, send):
                scope = dict(scope)
                scope["tailscale.transport"] = proof
                await downstream(scope, receive, send)

            self.app = trusted

    class HTTP(PeerGuard, H11Protocol):
        pass

    class WS(PeerGuard, WebSocketsSansIOProtocol):
        pass

    return HTTP, WS


def installed_app(public_origin):
    # Not the dashboard CLI startup: deliberately no cron, plugin startup, agent
    # keepalives, process ledger, or production HERMES_HOME. Only auth/route seams.
    from hermes_cli import web_server
    from hermes_cli.dashboard_auth import clear_providers, register_provider

    clear_providers()
    register_provider(RequestProvider())
    app = web_server.app
    app.state.auth_required = True
    app.state.bound_host = "127.0.0.1"
    from urllib.parse import urlsplit

    app.state.trusted_public_hosts = frozenset({urlsplit(public_origin).hostname})
    return app


def config(app, allowlist, public_origin, proxy_uid=0):
    proof = object()
    http, ws = protocols(proxy_uid, proof)
    gate = IdentityGate(app, allowlist, public_origin, proof)
    return uvicorn.Config(
        gate,
        http=http,
        ws=ws,
        proxy_headers=False,
        lifespan="off",
        access_log=False,
        log_level="warning",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True)
    parser.add_argument("--origin", required=True)
    parser.add_argument("--allow-login", action="append", required=True)
    args = parser.parse_args()
    home = Path(os.environ.get("HERMES_HOME", ""))
    # Preserve an isolated directory's explicit ownership boundary too.
    info = home.lstat() if home.is_absolute() and home.exists() else None
    if (
        info is None
        or not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) != 0o700
        or home.resolve() == (Path.home() / ".hermes").resolve()
    ):
        parser.error(
            "set HERMES_HOME to an isolated, owned, non-symlink absolute 0700 directory (not ~/.hermes)"
        )
    # Production prototype mode only accepts root (tailscaled) on the socket.
    server = uvicorn.Server(
        config(installed_app(args.origin), args.allow_login, args.origin)
    )
    with private_socket(args.socket) as sock:
        server.run(sockets=[sock])


if __name__ == "__main__":
    main()
