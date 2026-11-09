"""Standard-library tests: python3 -m unittest discover -s tests -v."""
import importlib.util
from pathlib import Path
import unittest
import tempfile
import subprocess
import sys


def updater():
    spec = importlib.util.spec_from_file_location("update_packages", ROOT / "scripts/update_packages.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

ROOT = Path(__file__).resolve().parents[1]


class UpdaterTests(unittest.TestCase):
    def test_allowlist_contains_only_independent_release_packages(self):
        path = ROOT / "scripts/update_packages.py"
        self.assertTrue(path.exists(), "package updater is missing")
        spec = importlib.util.spec_from_file_location("update_packages", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.PACKAGES, {
            "sane-scan-pdf": "pkgs/sane-scan-pdf/default.nix",
            "octoapp": "pkgs/octoapp/default.nix",
        })


    def test_check_updates_and_builds_in_copy_without_modifying_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "pkgs/sane-scan-pdf/default.nix"
            source.parent.mkdir(parents=True)
            source.write_text("old pin")
            calls = []

            def run(command, *, cwd, check):
                self.assertNotEqual(Path(cwd), root)
                self.assertTrue(check)
                calls.append(command)
                if command[0] == "nix-update":
                    (Path(cwd) / source.relative_to(root)).write_text("new pin")

            changed = updater().update(root, "sane-scan-pdf", apply=False, run=run)
            self.assertTrue(changed)
            self.assertEqual(source.read_text(), "old pin")
            self.assertEqual(calls, [
                ["nix-update", "--flake", "sane-scan-pdf", "--version=stable"],
                ["nix", "build", "--no-link", "--no-write-lock-file", ".#sane-scan-pdf"],
            ])


    def test_apply_copies_only_built_pin_to_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "pkgs/octoapp/default.nix"
            source.parent.mkdir(parents=True)
            source.write_text("old pin")
            def run(command, *, cwd, check):
                if command[0] == "nix-update":
                    (Path(cwd) / source.relative_to(root)).write_text("new pin")
                else:
                    self.assertEqual(source.read_text(), "old pin")
            self.assertTrue(updater().update(root, "octoapp", apply=True, run=run))
            self.assertEqual(source.read_text(), "new pin")


    def test_refuses_unexpected_changes_before_build_or_apply(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "pkgs/octoapp/default.nix"
            source.parent.mkdir(parents=True)
            source.write_text("old pin")
            calls = []
            def run(command, *, cwd, check):
                calls.append(command)
                (Path(cwd) / "flake.lock").write_text("unexpected")
            with self.assertRaisesRegex(RuntimeError, "flake.lock"):
                updater().update(root, "octoapp", apply=True, run=run)
            self.assertEqual(len(calls), 1)
            self.assertEqual(source.read_text(), "old pin")


    def test_cli_documents_explicit_check_and_apply_modes(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts/update_packages.py"), "--help"],
                                text=True, capture_output=True, check=True)
        self.assertIn("--check", result.stdout)
        self.assertIn("--apply", result.stdout)


    def test_build_failure_leaves_checkout_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "pkgs/octoapp/default.nix"
            source.parent.mkdir(parents=True)
            source.write_text("old pin")
            def run(command, *, cwd, check):
                if command[0] == "nix-update":
                    (Path(cwd) / source.relative_to(root)).write_text("new pin")
                else:
                    raise subprocess.CalledProcessError(1, command)
            with self.assertRaises(subprocess.CalledProcessError):
                updater().update(root, "octoapp", apply=True, run=run)
            self.assertEqual(source.read_text(), "old pin")

    def test_current_release_is_noop_but_still_builds(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "pkgs/octoapp/default.nix"
            source.parent.mkdir(parents=True)
            source.write_text("current pin")
            calls = []
            def run(command, *, cwd, check):
                calls.append(command)
            self.assertFalse(updater().update(root, "octoapp", apply=True, run=run))
            self.assertEqual(len(calls), 2)
            self.assertEqual(source.read_text(), "current pin")

    def test_cli_rejects_excluded_package(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts/update_packages.py"),
                                 "buzz-agent-tools", "--check"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid choice", result.stderr)


if __name__ == "__main__":
    unittest.main()
