"""Exercise registration against a local relay fixture, with disposable keys."""

import base64
import hashlib
import importlib.util
import json
from pathlib import Path
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from coincurve import PrivateKey

spec = importlib.util.spec_from_file_location(
    "registration", Path(__file__).with_name("register-agent.py")
)
registration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(registration)


class RegistrationTests(unittest.TestCase):
    def setUp(self):
        self.owner = PrivateKey()
        self.agent = PrivateKey()
        self.owner_hex = self.owner.public_key_xonly.format().hex()
        self.agent_hex = self.agent.public_key_xonly.format().hex()
        signature = self.owner.sign_schnorr(hashlib.sha256(
            f"nostr:agent-auth:{self.agent_hex}:".encode()
        ).digest()).hex()
        self.profile = registration.sign(self.agent, 0, [
            ["auth", self.owner_hex, "", signature],
        ], '{"name":"Hermes"}')
        self.policy = None
        self.writes = 0
        self.requests = []
        fixture = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                auth = json.loads(base64.b64decode(
                    self.headers["Authorization"].removeprefix("Nostr ")
                ))
                registration.verify(auth)
                fixture.assertEqual(auth["kind"], 27235)
                fixture.assertEqual(auth["pubkey"], fixture.owner_hex)
                fixture.assertIn(["u", fixture.relay + self.path], auth["tags"])
                fixture.assertIn(["method", "POST"], auth["tags"])
                fixture.assertIn(["payload", hashlib.sha256(body).hexdigest()], auth["tags"])
                fixture.requests.append(auth["id"])
                data = json.loads(body)
                if self.path == "/query":
                    value = fixture.profile if data[0]["kinds"] == [0] else fixture.policy
                    result = [value] if value else []
                else:
                    fixture.assertEqual(self.path, "/events")
                    registration.verify(data)
                    fixture.assertEqual(data["kind"], 30177)
                    fixture.assertEqual(data["pubkey"], fixture.owner_hex)
                    fixture.assertEqual(data["tags"], [["d", fixture.agent_hex]])
                    fixture.policy = data
                    fixture.writes += 1
                    result = {"accepted": True, "id": data["id"]}
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.relay = f"http://127.0.0.1:{self.server.server_port}"
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def register(self, key=None):
        return registration.register(self.relay, key or self.owner,
                                     self.owner_hex, self.agent_hex, "Hermes")

    def test_registration_and_rerun(self):
        self.assertIn("verified", self.register())
        self.assertIn("already", self.register())
        self.assertEqual(self.writes, 1)
        self.assertEqual(len(self.requests), len(set(self.requests)))
        self.assertEqual(json.loads(self.policy["content"]), {
            "name": "Hermes", "parallelism": 1,
            "respond_to": "owner-only", "respond_to_allowlist": [],
        })

    def test_wrong_owner_key_never_connects(self):
        with self.assertRaisesRegex(ValueError, "private key does not match"):
            self.register(PrivateKey())
        self.assertEqual(self.requests, [])

    def test_forged_attestation_never_publishes(self):
        self.profile = registration.sign(self.agent, 0, [
            ["auth", self.owner_hex, "", "00" * 64],
        ], '{"name":"Hermes"}')
        with self.assertRaisesRegex(ValueError, "attestation is invalid"):
            self.register()
        self.assertEqual(self.writes, 0)

    def test_existing_policy_is_preserved(self):
        self.policy = registration.sign(self.owner, 30177,
                                        [["d", self.agent_hex]], '{"respond_to":"nobody"}')
        before = self.policy.copy()
        with self.assertRaisesRegex(ValueError, "refusing to replace"):
            self.register()
        self.assertEqual(self.policy, before)
        self.assertEqual(self.writes, 0)

    def test_unsigned_profile_is_rejected(self):
        self.profile["content"] = '{"name":"Tampered"}'
        with self.assertRaisesRegex(ValueError, "invalid event signature"):
            self.register()
        self.assertEqual(self.writes, 0)


if __name__ == "__main__":
    unittest.main()
