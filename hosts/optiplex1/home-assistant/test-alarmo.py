"""Regression checks: python3 -B hosts/optiplex1/home-assistant/test-alarmo.py."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]


class AlarmoContainerTests(unittest.TestCase):
    def test_container_mounts_alarmo_read_only_and_keeps_config(self):
        result = subprocess.run(
            [
                "nix", "eval", "--json", "--no-write-lock-file",
                ".#nixosConfigurations.optiplex1.config",
                "--apply", """c: {
                  volumes = c.virtualisation.oci-containers.containers.homeAssistant.volumes;
                  script = c.systemd.services.podman-homeAssistant.script;
                  preStart = c.systemd.services.podman-homeAssistant.preStart;
                }""",
            ],
            cwd=ROOT, check=True, capture_output=True, text=True,
        )
        config = json.loads(result.stdout)
        mounts = [v for v in config["volumes"] if ":/config/custom_components/alarmo:" in v]
        self.assertEqual(len(mounts), 1, "Alarmo must be mounted exactly once")
        self.assertTrue(mounts[0].endswith(":ro"))
        self.assertTrue(mounts[0].startswith("/nix/store/"))
        self.assertIn("/var/lib/home-assistant:/config", config["volumes"])
        self.assertIn("/var/lib/ssl:/ssl", config["volumes"])
        self.assertIn(mounts[0], config["script"], "Generated podman command must include the mount")
        self.assertIn("prepare-alarmo.sh", config["preStart"])
        self.assertIn("/var/lib/home-assistant", config["preStart"])


class AlarmoMountpointTests(unittest.TestCase):
    def prepare(self, config):
        return subprocess.run(
            ["bash", str(Path(__file__).with_name("prepare-alarmo.sh")), str(config)],
            capture_output=True, text=True,
        )

    def test_refuses_symlink_mountpoints_and_symlink_parents(self):
        for link_parent in (False, True):
            with self.subTest(link_parent=link_parent), tempfile.TemporaryDirectory() as directory:
                config = Path(directory) / "config"
                config.mkdir()
                elsewhere = Path(directory) / "elsewhere"
                elsewhere.mkdir()
                if link_parent:
                    (config / "custom_components").symlink_to(elsewhere, target_is_directory=True)
                else:
                    (config / "custom_components").mkdir()
                    (config / "custom_components/alarmo").symlink_to(elsewhere, target_is_directory=True)
                result = self.prepare(config)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Refusing", result.stderr)
                self.assertEqual(list(elsewhere.iterdir()), [])

    def test_refuses_populated_unmanaged_installation_without_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            target = config / "custom_components/alarmo"
            target.mkdir(parents=True)
            existing = target / ".unmanaged"
            existing.write_text("keep me")
            result = self.prepare(config)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Refusing", result.stderr)
            self.assertEqual(existing.read_text(), "keep me")

    def test_creates_empty_mountpoint_idempotently(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            for _ in range(2):
                result = self.prepare(config)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((config / "custom_components/alarmo").is_dir())


if __name__ == "__main__":
    unittest.main()
