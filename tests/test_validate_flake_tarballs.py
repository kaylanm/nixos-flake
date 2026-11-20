"""Regression coverage for independently checking locked tarball URLs."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/validate_flake_tarballs.py"


class ValidationTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("validator", SCRIPT)
        self.validator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.validator)

    def test_rejects_rex_old_url_new_hash_pair(self):
        locked = {"type": "tarball", "url": "https://example.test/old.tar.gz",
                  "narHash": "sha256-new-release"}
        with patch.object(self.validator.subprocess, "run") as run:
            run.return_value.stdout = json.dumps({"hash": "sha256-old-release"})
            with self.assertRaisesRegex(ValueError, "rex.*hash mismatch"):
                self.validator.validate({"nodes": {"rex": {"locked": locked}}})
            args, kwargs = run.call_args
            self.assertEqual(args[0], ["nix", "flake", "prefetch", "--refresh", "--json", locked["url"]])
            self.assertNotIn("narHash", args[0][-1])
            self.assertIn("XDG_CACHE_HOME", kwargs["env"])


    def test_matching_hash_passes_and_non_tarballs_are_skipped(self):
        lock = {"nodes": {"root": {"inputs": {}}, "github": {"locked": {"type": "github"}},
                          "rex": {"locked": {"type": "tarball", "url": "https://example.test/new.tar.gz",
                                             "narHash": "sha256-matching"}}}}
        with patch.object(self.validator.subprocess, "run") as run:
            run.return_value.stdout = json.dumps({"hash": "sha256-matching"})
            self.validator.validate(lock)
            self.assertEqual(run.call_count, 1)
            cache = Path(run.call_args.kwargs["env"]["XDG_CACHE_HOME"])
            self.assertFalse(cache.exists())

    def test_network_failure_is_not_treated_as_success(self):
        lock = {"nodes": {"rex": {"locked": {"type": "tarball", "url": "https://example.test/rex.tar.gz",
                                             "narHash": "sha256-expected"}}}}
        with patch.object(self.validator.subprocess, "run") as run:
            run.side_effect = self.validator.subprocess.CalledProcessError(1, "nix", stderr="fetch failed")
            with self.assertRaises(self.validator.subprocess.CalledProcessError):
                self.validator.validate(lock)

    def test_missing_hash_fails_closed(self):
        lock = {"nodes": {"rex": {"locked": {"type": "tarball", "url": "https://example.test/rex.tar.gz"}}}}
        with patch.object(self.validator.subprocess, "run") as run:
            run.return_value.stdout = json.dumps({"hash": "sha256-fetched"})
            with self.assertRaises(KeyError):
                self.validator.validate(lock)

    def test_explicit_input_does_not_fetch_other_tarballs(self):
        locked = {"type": "tarball", "url": "https://example.test/rex.tar.gz", "narHash": "sha256-matching"}
        lock = {"nodes": {"rex": {"locked": locked}, "other": {"locked": locked}}}
        with patch.object(self.validator.subprocess, "run") as run:
            run.return_value.stdout = json.dumps({"hash": "sha256-matching"})
            self.validator.validate(lock, ["rex"])
            self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
