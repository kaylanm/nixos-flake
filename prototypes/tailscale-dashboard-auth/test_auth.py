import unittest

from tailscale_auth import IdentityGate


class GateTests(unittest.IsolatedAsyncioTestCase):
    async def test_direct_scope_cannot_forge_loopback_identity(self):
        reached, events = [], []

        async def app(scope, receive, send):
            reached.append(scope)

        async def send(event):
            events.append(event)

        gate = IdentityGate(
            app, {"owner@example.com"}, "https://prototype.example", object()
        )
        await gate(
            {
                "type": "http",
                "method": "GET",
                "path": "/api/auth/me",
                "headers": [
                    (b"host", b"prototype.example"),
                    (b"tailscale-user-login", b"owner@example.com"),
                ],
                "client": ("127.0.0.1", 1234),
            },
            None,
            send,
        )
        self.assertFalse(reached)
        self.assertEqual(events[0]["status"], 403)


class SocketTests(unittest.TestCase):
    def test_private_socket(self):
        import tempfile
        from pathlib import Path

        from server import private_socket

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "http.sock"
            with private_socket(path) as sock:
                self.assertEqual(sock.family, __import__("socket").AF_UNIX)
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertFalse(path.exists())


import asyncio
import json
import os
import tempfile
from pathlib import Path

import httpx
import uvicorn
from server import config, installed_app, private_socket
from websockets.asyncio.client import unix_connect
from websockets.exceptions import InvalidStatus

ORIGIN = "https://prototype.example"
LOGIN = [("Tailscale-User-Login", "owner@example.com")]


class InstalledIntegration(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "http.sock"
        self.socket_cm = private_socket(self.path)
        sock = self.socket_cm.__enter__()
        from hermes_state import SessionDB

        SessionDB().close()  # Initialize only the disposable HERMES_HOME store.
        app = installed_app(ORIGIN)
        self.server = uvicorn.Server(
            config(app, {"owner@example.com", "other@example.com"}, ORIGIN, os.getuid())
        )
        self.task = asyncio.create_task(self.server.serve(sockets=[sock]))
        for _ in range(300):
            if self.server.started:
                break
            if self.task.done():
                await self.task
            await asyncio.sleep(0.01)
        self.assertTrue(self.server.started)
        self.client = httpx.AsyncClient(
            transport=httpx.AsyncHTTPTransport(uds=str(self.path), trust_env=False),
            base_url="http://prototype.example",
        )

    async def asyncTearDown(self):
        await self.client.aclose()
        self.server.should_exit = True
        await asyncio.wait_for(self.task, 5)
        self.socket_cm.__exit__(None, None, None)
        self.directory.cleanup()

    async def test_http_verified_session_without_client_credential(self):
        r = await self.client.get("/api/auth/me", headers=LOGIN)
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual(r.json()["user_id"], "owner@example.com")
        self.assertEqual(r.json()["provider"], "tailscale-serve-prototype")
        self.assertNotIn("set-cookie", r.headers)
        self.assertNotIn("access_token", r.text)
        r = await self.client.get("/api/sessions", headers=LOGIN)
        self.assertEqual(r.status_code, 200, r.text)

    async def test_http_rejection_matrix(self):
        cases = [
            [],
            [("Tailscale-User-Login", "denied@example.com")],
            LOGIN + LOGIN,
            [("Tailscale-User-Login", "owner@example.com,denied@example.com")],
            [("Tailscale-User-Login", "Owner@example.com")],
            LOGIN + [("Origin", "https://evil.example")],
            LOGIN + [("Origin", ORIGIN), ("Origin", ORIGIN)],
            LOGIN + [("Host", "evil.example")],
            LOGIN + [("Sec-Fetch-Site", "cross-site")],
            [("Authorization", "Bearer forged"), ("Cookie", "hermes_session=forged")],
        ]
        for headers in cases:
            with self.subTest(headers=headers):
                r = await self.client.get("/api/auth/me", headers=headers)
                self.assertEqual(r.status_code, 403, r.text)
                self.assertNotIn("location", r.headers)

    async def test_csrf_mutation_and_bootstrap_disabled(self):
        r = await self.client.post(
            "/api/auth/ws-ticket", headers=LOGIN + [("Sec-Fetch-Site", "same-origin")]
        )
        self.assertEqual(r.status_code, 403)
        for headers in (
            LOGIN,
            LOGIN + [("Sec-Fetch-Site", "same-origin"), ("Origin", ORIGIN)],
        ):
            r = await self.client.post("/api/auth/ws-ticket", headers=headers)
            self.assertEqual(r.status_code, 200, r.text)
        for path in ("/login", "/auth/native/token", "/auth/login"):
            r = await self.client.get(path, headers=LOGIN)
            self.assertEqual(r.status_code, 404)

    async def test_credentials_cannot_override_identity(self):
        r = await self.client.get(
            "/api/auth/me",
            headers=LOGIN
            + [
                ("Authorization", "Bearer bogus"),
                ("Cookie", "hermes_access_token=bogus"),
                ("X-Hermes-Gateway-Ticket", "bogus"),
                ("X-Forwarded-Host", "evil.example"),
            ],
        )
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual(r.json()["user_id"], "owner@example.com")

    async def test_concurrent_identity_isolation(self):
        async def call(login):
            r = await self.client.get(
                "/api/auth/me", headers={"Tailscale-User-Login": login}
            )
            self.assertEqual(r.status_code, 200, r.text)
            self.assertEqual(r.json()["user_id"], login)

        await asyncio.gather(
            *(call(x) for x in ["owner@example.com", "other@example.com"] * 10)
        )

    async def test_real_gateway_websocket_handshake_without_token(self):
        async with unix_connect(
            str(self.path),
            uri="ws://prototype.example/api/ws",
            additional_headers=LOGIN,
        ) as ws:
            self.assertEqual(ws.response.status_code, 101)
            self.assertIsInstance(
                json.loads(await asyncio.wait_for(ws.recv(), 5)), dict
            )

    async def test_real_websocket_rejections(self):
        for headers in (
            [],
            LOGIN + LOGIN,
            [("Tailscale-User-Login", "denied@example.com")],
            LOGIN + [("Origin", "https://evil.example")],
            LOGIN + [("Sec-Fetch-Site", "same-origin")],
        ):
            with self.subTest(headers=headers):
                with self.assertRaises(InvalidStatus) as caught:
                    async with unix_connect(
                        str(self.path),
                        uri="ws://prototype.example/api/ws?token=forged&ticket=forged",
                        additional_headers=headers,
                    ):
                        pass
                self.assertEqual(caught.exception.response.status_code, 403)

    async def test_websocket_stream_broadcast(self):
        kwargs = {"additional_headers": LOGIN, "origin": ORIGIN}
        async with (
            unix_connect(
                str(self.path),
                uri="ws://prototype.example/api/events?channel=security-test",
                **kwargs,
            ) as sub,
            unix_connect(
                str(self.path),
                uri="ws://prototype.example/api/pub?channel=security-test",
                **kwargs,
            ) as pub,
        ):
            await pub.send('{"probe":"stream"}')
            self.assertEqual(
                await asyncio.wait_for(sub.recv(), 2), '{"probe":"stream"}'
            )

    async def test_wrong_kernel_uid_rejected(self):
        # Same socket path and forged headers cannot overcome SO_PEERCRED.
        self.server.should_exit = True
        await self.task
        self.socket_cm.__exit__(None, None, None)
        self.socket_cm = private_socket(self.path)
        sock = self.socket_cm.__enter__()
        self.server = uvicorn.Server(
            config(
                installed_app(ORIGIN), {"owner@example.com"}, ORIGIN, os.getuid() + 1
            )
        )
        self.task = asyncio.create_task(self.server.serve(sockets=[sock]))
        while not self.server.started:
            await asyncio.sleep(0.01)
        with self.assertRaises(httpx.TransportError):
            await self.client.get("/api/auth/me", headers=LOGIN)

    async def test_http_streaming_export(self):
        from hermes_state import SessionDB

        with SessionDB() as db:
            db.create_session("prototype-stream", "test")
            db.append_message("prototype-stream", "user", "streamed payload")
        path = "/api/sessions/prototype-stream/export"
        async with self.client.stream("GET", path, headers=LOGIN) as r:
            self.assertEqual(r.status_code, 200)
            data = json.loads(await r.aread())
            self.assertEqual(data["messages"][0]["content"], "streamed payload")
        self.assertEqual((await self.client.get(path)).status_code, 403)

    async def test_valid_ws_ticket_cannot_bypass_identity(self):
        r = await self.client.post("/api/auth/ws-ticket", headers=LOGIN)
        ticket = r.json()["ticket"]
        with self.assertRaises(InvalidStatus) as caught:
            async with unix_connect(
                str(self.path), uri=f"ws://prototype.example/api/ws?ticket={ticket}"
            ):
                pass
        self.assertEqual(caught.exception.response.status_code, 403)
        async with unix_connect(
            str(self.path),
            uri=f"ws://prototype.example/api/events?channel=valid-ticket&ticket={ticket}",
            additional_headers=LOGIN,
        ) as ws:
            self.assertEqual(ws.response.status_code, 101)

    async def test_tcp_spoofed_identity_and_forwarded_headers_rejected(self):
        import socket

        sock = socket.socket()
        sock.bind(("127.0.0.1", 0))
        sock.listen(10)
        sock.setblocking(False)
        port = sock.getsockname()[1]
        server = uvicorn.Server(
            config(installed_app(ORIGIN), {"owner@example.com"}, ORIGIN, os.getuid())
        )
        task = asyncio.create_task(server.serve(sockets=[sock]))
        try:
            while not server.started:
                await asyncio.sleep(0.01)
            async with httpx.AsyncClient(trust_env=False) as client:
                with self.assertRaises(httpx.TransportError):
                    await client.get(
                        f"http://127.0.0.1:{port}/api/auth/me",
                        headers=LOGIN
                        + [
                            ("Host", "prototype.example"),
                            ("X-Forwarded-For", "100.64.0.1"),
                        ],
                    )
        finally:
            server.should_exit = True
            await asyncio.wait_for(task, 5)
            sock.close()

    async def test_public_status_and_assets_also_require_identity(self):
        for path in ("/api/status", "/assets/test.js", "/"):
            self.assertEqual((await self.client.get(path)).status_code, 403)


class ConfigurationTests(unittest.TestCase):
    def test_provider_has_no_outside_request_credentials(self):
        from hermes_cli.dashboard_auth.base import (
            RefreshExpiredError,
            assert_protocol_compliance,
        )
        from tailscale_auth import RequestProvider

        assert_protocol_compliance(RequestProvider)
        provider = RequestProvider()
        self.assertIsNone(provider.verify_session(access_token="anything"))
        self.assertRaises(NotImplementedError, provider.start_login)
        self.assertRaises(NotImplementedError, provider.complete_login)
        self.assertRaises(RefreshExpiredError, provider.refresh_session)
        self.assertIsNone(provider.revoke_session())

    def test_empty_or_ambiguous_config_rejected(self):
        for allowlist, origin in [
            (set(), ORIGIN),
            ({"a,b"}, ORIGIN),
            ({" a"}, ORIGIN),
            ({"é"}, ORIGIN),
            ({"a"}, "http://prototype.example"),
            ({"a"}, ORIGIN + "/path"),
        ]:
            with (
                self.subTest(allowlist=allowlist, origin=origin),
                self.assertRaises(ValueError),
            ):
                IdentityGate(None, allowlist, origin, object())

    def test_socket_parent_and_existing_path_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            path = parent / "http.sock"
            parent.chmod(0o755)
            with self.assertRaises(ValueError), private_socket(path):
                pass
            parent.chmod(0o700)
            path.write_text("do not replace")
            with self.assertRaises(ValueError), private_socket(path):
                pass
            self.assertEqual(path.read_text(), "do not replace")


class ReviewRegressionTests(unittest.IsolatedAsyncioTestCase):
    def scope(self, proof, kind="http"):
        return {
            "type": kind,
            "method": "GET",
            "path": "/api/auth/me",
            "query_string": b"",
            "headers": [
                (b"host", b"prototype.example"),
                (b"tailscale-user-login", b"owner@example.com"),
            ],
            "tailscale.transport": proof,
        }

    async def test_inherited_context_invalidated_and_token_not_replayable(self):
        from tailscale_auth import RequestProvider

        proof, release, captured = object(), asyncio.Event(), []
        provider = RequestProvider()

        async def app(scope, receive, send):
            token = dict(scope["headers"])[b"authorization"].decode().split()[1]
            self.assertIsNotNone(provider.verify_session(access_token=token))
            if captured:
                self.assertIsNone(provider.verify_session(access_token=captured[0]))
            else:
                captured.append(token)

                async def inherited():
                    await release.wait()
                    return provider.verify_session(access_token=token)

                captured.append(asyncio.create_task(inherited()))

        gate = IdentityGate(app, {"owner@example.com"}, ORIGIN, proof)
        await gate(self.scope(proof), None, None)
        release.set()
        self.assertIsNone(await captured[1])
        self.assertIsNone(provider.verify_session(access_token=captured[0]))
        await gate(self.scope(proof), None, None)

    async def test_malformed_query_is_controlled_rejection(self):
        proof, reached, events = object(), [], []

        async def app(scope, receive, send):
            reached.append(scope)

        async def send(event):
            events.append(event)

        scope = self.scope(proof, "websocket")
        scope["query_string"] = b"q=\xff"
        await IdentityGate(app, {"owner@example.com"}, ORIGIN, proof)(scope, None, send)
        self.assertFalse(reached)
        self.assertEqual(events, [{"type": "websocket.close", "code": 1008}])

    async def test_private_socket_does_not_change_process_umask(self):
        with tempfile.TemporaryDirectory() as directory:
            before = os.umask(0o077)
            os.umask(before)
            with private_socket(Path(directory) / "http.sock"):
                during = os.umask(before)
                self.assertEqual(during, before)


if __name__ == "__main__":
    unittest.main()
