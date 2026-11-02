"""Check identity provisioning with disposable keys and temporary files."""

import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shlex
import stat
import tempfile
import unittest
from unittest.mock import patch

from bech32 import bech32_encode, convertbits
from coincurve import PrivateKey

spec = importlib.util.spec_from_file_location(
    "provision", Path(__file__).with_name("provision-identity.py")
)
provision = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provision)


class ProvisionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name) / "secrets.env"
        self.owner = PrivateKey()
        self.owner_hex = self.owner.public_key_xonly.format().hex()
        self.stdout = io.StringIO()
        self.stderr = io.StringIO()

    def run_helper(self, private_key):
        with patch("sys.argv", ["provision-identity.py", "--owner", self.owner_hex,
                                "--output", str(self.output)]), \
             patch.object(provision.getpass, "getpass", return_value=private_key), \
             contextlib.redirect_stdout(self.stdout), contextlib.redirect_stderr(self.stderr):
            provision.main()

    def test_credentials_and_permissions(self):
        owner_nsec = bech32_encode("nsec", convertbits(self.owner.secret, 8, 5))
        self.run_helper(owner_nsec)
        contents = self.output.read_text()
        values = dict(line.split("=", 1) for line in contents.splitlines())
        agent = provision.parse_key(values["BUZZ_PRIVATE_KEY"])
        agent_hex = agent.public_key_xonly.format().hex()
        auth = json.loads(shlex.split(values["BUZZ_AUTH_TAG"])[0])
        self.assertEqual(auth[:3], ["auth", self.owner_hex, ""])
        self.assertTrue(self.owner.public_key_xonly.verify(bytes.fromhex(auth[3]),
            hashlib.sha256(f"nostr:agent-auth:{agent_hex}:".encode()).digest()))
        self.assertNotEqual(agent.secret, self.owner.secret)
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o600)
        self.assertIn(agent_hex, self.stdout.getvalue())
        for secret in [owner_nsec, self.owner.secret.hex()]:
            self.assertNotIn(secret, contents + self.stdout.getvalue() + self.stderr.getvalue())
        self.assertNotIn(values["BUZZ_PRIVATE_KEY"], self.stdout.getvalue())

    def test_existing_file_is_preserved(self):
        self.output.write_text("existing identity")
        with self.assertRaises(SystemExit):
            self.run_helper(self.owner.secret.hex())
        self.assertEqual(self.output.read_text(), "existing identity")

    def test_dangling_symlink_is_preserved(self):
        target = self.output.with_name("missing")
        self.output.symlink_to(target)
        with self.assertRaises(SystemExit):
            self.run_helper(self.owner.secret.hex())
        self.assertTrue(self.output.is_symlink())
        self.assertFalse(target.exists())

    def test_wrong_owner_creates_no_file(self):
        with self.assertRaises(SystemExit):
            self.run_helper(PrivateKey().secret.hex())
        self.assertFalse(self.output.exists())

    def test_invalid_key_is_not_echoed(self):
        bad_key = "private-input-" + "!" * 50
        with self.assertRaises(SystemExit):
            self.run_helper(bad_key)
        self.assertNotIn(bad_key, self.stderr.getvalue())
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
