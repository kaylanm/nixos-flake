import contextlib
import importlib.util
import io
import os
from pathlib import Path
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).with_name("auth.py")


class AuthTests(unittest.TestCase):
    def load(self):
        self.assertTrue(SOURCE.exists(), "authentication implementation must exist")
        spec = importlib.util.spec_from_file_location("auth", SOURCE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_credential_ignores_other_hosts_and_non_get_actions(self):
        auth = self.load()
        for action, request in [("store", "protocol=https\nhost=github.com\n\n"),
                                ("erase", ""),
                                ("get", "protocol=https\nhost=evil.example\n\n"),
                                ("get", "protocol=http\nhost=github.com\n\n")]:
            output = io.StringIO()
            with patch.dict(os.environ, {}, clear=True), patch("sys.stdin", io.StringIO(request)), contextlib.redirect_stdout(output):
                self.assertEqual(auth.main(["credential", action]), 0)
            self.assertEqual(output.getvalue(), "")

    def test_credential_mints_fresh_tokens_with_signed_runtime_identity(self):
        auth = self.load()
        environment = {"GITHUB_APP_ID": "123", "GITHUB_APP_INSTALLATION_ID": "456",
                       "GITHUB_APP_PRIVATE_KEY_FILE": "/runtime/key.pem"}
        response = unittest.mock.MagicMock()
        response.__enter__.return_value = io.BytesIO(b'{"token":"test-token"}')
        output = io.StringIO()
        with patch.dict(os.environ, environment, clear=True), patch("sys.stdin", io.StringIO("protocol=https\nhost=github.com\n\n")), contextlib.redirect_stdout(output), patch("subprocess.run") as sign, patch("urllib.request.urlopen", return_value=response) as urlopen:
            sign.return_value.stdout = b"signature"
            self.assertEqual(auth.main(["credential", "get"]), 0)
        self.assertEqual(output.getvalue(), "username=x-access-token\npassword=test-token\n\n")
        self.assertEqual(sign.call_args.args[0][-1], "/runtime/key.pem")
        request = urlopen.call_args.args[0]
        self.assertEqual(request.full_url, "https://api.github.com/app/installations/456/access_tokens")
        self.assertEqual(request.data, b"{}")
        import base64
        import json
        signed = sign.call_args.kwargs["input"].split(b".")
        claims = json.loads(base64.urlsafe_b64decode(signed[1] + b"=" * (-len(signed[1]) % 4)))
        self.assertEqual(claims["iss"], "123")
        self.assertLessEqual(claims["exp"] - claims["iat"], 600)

    def test_gh_replaces_inherited_tokens_and_uses_pinned_executable(self):
        auth = self.load()
        with patch.dict(os.environ, {"GH_TOKEN": "stale", "GITHUB_TOKEN": "stale", "GH_ENTERPRISE_TOKEN": "stale", "GITHUB_ENTERPRISE_TOKEN": "stale", "GITHUB_APP_GH": "/pinned/bin/gh"}), patch.object(auth, "installation_token", return_value="fresh") as mint, patch("os.execve") as execute:
            auth.main(["gh", "api", "installation/repositories"])
            auth.main(["gh", "api", "installation/repositories"])
        self.assertEqual(mint.call_count, 2)
        executable, arguments, environment = execute.call_args.args
        self.assertEqual(executable, "/pinned/bin/gh")
        self.assertEqual(arguments, [executable, "api", "installation/repositories"])
        self.assertEqual(environment["GH_TOKEN"], "fresh")
        self.assertEqual(environment.get("GH_HOST"), "github.com")
        self.assertNotIn("GITHUB_TOKEN", environment)
        self.assertNotIn("GH_ENTERPRISE_TOKEN", environment)
        self.assertNotIn("GITHUB_ENTERPRISE_TOKEN", environment)

    def test_errors_do_not_disclose_exception_or_output_secrets(self):
        auth = self.load()
        import urllib.error
        import subprocess
        errors = [KeyError("SECRET"), ValueError("SECRET"), OSError("SECRET"),
                  urllib.error.HTTPError("SECRET", 403, "SECRET", {}, None),
                  subprocess.CalledProcessError(1, ["SECRET"], output=b"SECRET", stderr=b"SECRET")]
        for error in errors:
            output, diagnostic = io.StringIO(), io.StringIO()
            with patch.object(auth, "main", side_effect=error), contextlib.redirect_stdout(output), contextlib.redirect_stderr(diagnostic):
                self.assertEqual(auth.run(["gh"]), 1)
            self.assertEqual(output.getvalue(), "")
            self.assertIn("github-app-auth:", diagnostic.getvalue())
            self.assertNotIn("SECRET", diagnostic.getvalue())

    def test_unknown_command_fails_without_minting(self):
        auth = self.load()
        with patch.object(auth, "installation_token") as mint, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(auth.main(["typo"]), 2)
        mint.assert_not_called()


if __name__ == "__main__":
    unittest.main()
