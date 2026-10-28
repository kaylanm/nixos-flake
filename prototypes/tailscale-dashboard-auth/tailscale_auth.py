"""Fail-closed Tailscale identity adapter using Hermes' existing verifier seams.

Internal bearer credentials exist only in request context, never in client storage.
Transport proof is an object owned by the Unix-only launcher, not a header/client IP.
"""

import hmac
import secrets
import time
from contextvars import ContextVar
from urllib.parse import parse_qsl, urlencode, urlsplit

from hermes_cli.dashboard_auth.base import (
    DashboardAuthProvider,
    RefreshExpiredError,
    Session,
)

_current = ContextVar("tailscale_request_session", default=None)


class RequestProvider(DashboardAuthProvider):
    name = "tailscale-serve-prototype"
    display_name = "Tailscale Serve (prototype)"

    def verify_session(self, *, access_token):
        current = _current.get()
        if current and current["active"]:
            session = current["session"]
            if session.expires_at > time.time() and hmac.compare_digest(
                access_token, session.access_token
            ):
                return session
        return None

    def start_login(self, **kwargs):
        raise NotImplementedError("No interactive login")

    def complete_login(self, **kwargs):
        raise NotImplementedError("No interactive login")

    def refresh_session(self, **kwargs):
        raise RefreshExpiredError("No refresh tokens")

    def revoke_session(self, **kwargs):
        return None


class IdentityGate:
    def __init__(self, app, allowlist, public_origin, proof):
        url = urlsplit(public_origin)
        if (
            url.scheme != "https"
            or not url.netloc
            or url.path
            or url.query
            or url.fragment
            or url.username
        ):
            raise ValueError("public_origin must be a bare HTTPS origin")
        if not allowlist or any(
            not x or not x.isascii() or any(c.isspace() for c in x) or "," in x
            for x in allowlist
        ):
            raise ValueError("nonempty exact ASCII login allowlist required")
        self.app, self.allowlist = app, frozenset(allowlist)
        self.origin, self.host, self.proof = public_origin, url.netloc.encode(), proof

    async def __call__(self, scope, receive, send):
        if scope["type"] not in ("http", "websocket"):
            return await self.app(scope, receive, send)
        headers = scope.get("headers", [])

        def values(name):
            return [v for k, v in headers if k.lower() == name]

        login = values(b"tailscale-user-login")
        host, origins = values(b"host"), values(b"origin")
        identity_ok = (
            len(login) == 1
            and login[0].isascii()
            and login[0].decode("ascii") in self.allowlist
        )
        # Native apps may omit Origin. Browsers must send the exact configured
        # origin for mutations and upgrades; Fetch Metadata blocks no-Origin CSRF.
        fetch = values(b"sec-fetch-site")
        origin_ok = not origins or origins == [self.origin.encode()]
        browser = bool(fetch)
        sensitive = scope["type"] == "websocket" or scope.get("method") not in (
            "GET",
            "HEAD",
            "OPTIONS",
        )
        csrf_ok = (
            len(fetch) <= 1
            and (not fetch or fetch[0] in (b"same-origin", b"none"))
            and not (browser and sensitive and not origins)
        )
        ok = (
            scope.get("tailscale.transport") is self.proof
            and identity_ok
            and host == [self.host]
            and origin_ok
            and csrf_ok
        )
        if not ok:
            if scope["type"] == "websocket":
                await send({"type": "websocket.close", "code": 1008})
            else:
                await send(
                    {
                        "type": "http.response.start",
                        "status": 403,
                        "headers": [
                            (b"content-type", b"application/json"),
                            (b"cache-control", b"no-store"),
                        ],
                    }
                )
                await send(
                    {
                        "type": "http.response.body",
                        "body": b'{"error":"tailscale_identity_rejected"}',
                    }
                )
            return
        # Disable interactive/native bootstrap endpoints; WS-ticket issuance below
        # remains available but never substitutes for the transport/identity gate.
        if scope["path"].startswith(("/auth/", "/login")):
            if scope["type"] == "websocket":
                await send({"type": "websocket.close", "code": 1008})
            else:
                await send(
                    {"type": "http.response.start", "status": 404, "headers": []}
                )
                await send({"type": "http.response.body", "body": b""})
            return
        token = secrets.token_urlsafe(32)
        identity = login[0].decode("ascii")
        session = Session(
            user_id=identity,
            email=identity,
            display_name=identity,
            org_id="",
            provider=RequestProvider.name,
            expires_at=int(time.time()) + 60,
            access_token=token,
            refresh_token="",
            issuer="tailscale-serve",
        )
        stripped = {
            b"authorization",
            b"cookie",
            b"x-hermes-session-token",
            b"x-hermes-gateway-ticket",
            b"x-forwarded-host",
            b"x-forwarded-proto",
            b"x-forwarded-prefix",
            b"forwarded",
        }
        child = dict(scope)
        child["state"] = {}  # Never inherit an alternate authenticated principal.
        child["scheme"] = "wss" if scope["type"] == "websocket" else "https"
        child["headers"] = [(k, v) for k, v in headers if k.lower() not in stripped]
        child["headers"].append((b"authorization", f"Bearer {token}".encode()))
        if scope["type"] == "websocket":
            # Preserve ordinary subprotocol negotiation, remove credential subprotocols.
            child["subprotocols"] = [
                p
                for p in scope.get("subprotocols", [])
                if not p.startswith("hermes-gateway-ticket.")
            ]
            child["headers"] = [
                (k, v)
                for k, v in child["headers"]
                if k.lower() != b"sec-websocket-protocol"
            ]
            if child["subprotocols"]:
                child["headers"].append(
                    (
                        b"sec-websocket-protocol",
                        ", ".join(child["subprotocols"]).encode(),
                    )
                )
            try:
                query = [
                    (k, v)
                    for k, v in parse_qsl(
                        scope.get("query_string", b"").decode("ascii"),
                        keep_blank_values=True,
                    )
                    if k not in ("token", "ticket", "internal")
                ]
            except (UnicodeError, ValueError):
                await send({"type": "websocket.close", "code": 1008})
                return
            child["query_string"] = urlencode(query + [("token", token)]).encode()
        # A shared revocation flag also invalidates ContextVar copies inherited
        # by child tasks. A WS context lasts for its connection, not just upgrade.
        lease = {"session": session, "active": True}
        context = _current.set(lease)
        try:
            await self.app(child, receive, send)
        finally:
            lease["active"] = False
            _current.reset(context)
