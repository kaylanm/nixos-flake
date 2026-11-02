import importlib.util
from pathlib import Path
import tempfile
import unittest

from ruamel.yaml import YAML

spec = importlib.util.spec_from_file_location(
    "setup_homeassistant", Path(__file__).with_name("setup-homeassistant.py")
)
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class SetupHomeAssistantTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.source = self.root / "plugin-v1"
        self.source.mkdir()
        (self.source / "plugin.yaml").write_text("name: homeassistant\n")
        self.config = self.home / "config.yaml"

    def test_preserves_user_settings_and_comments_and_is_idempotent(self):
        self.config.write_text(
            "# model settings\nmodel:\n  default: existing-model\n"
            "plugins:\n  enabled: [another-plugin]\n"
            "  disabled: [homeassistant, unwanted-plugin]\n"
            "platform_toolsets:\n  acp: [terminal, file]\n"
        )
        setup.configure(self.home, self.source)
        data = YAML().load(self.config)
        self.assertEqual(data["model"]["default"], "existing-model")
        self.assertEqual(data["plugins"]["enabled"], ["another-plugin", "homeassistant"])
        self.assertEqual(data["plugins"]["disabled"], ["unwanted-plugin"])
        self.assertEqual(data["platform_toolsets"]["acp"], ["terminal", "file"])
        self.assertIn("# model settings", self.config.read_text())
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        previous = self.config.read_bytes(), self.config.stat().st_mtime_ns
        setup.configure(self.home, self.source)
        self.assertEqual(previous, (self.config.read_bytes(), self.config.stat().st_mtime_ns))

    def test_creates_config_and_updates_managed_link(self):
        setup.configure(self.home, self.source)
        target = self.home / "plugins/homeassistant"
        self.assertEqual(target.resolve(), self.source)
        newer = self.root / "plugin-v2"
        newer.mkdir()
        (newer / "plugin.yaml").write_text("name: homeassistant\n")
        setup.configure(self.home, newer)
        self.assertEqual(target.resolve(), newer)
        self.assertEqual(YAML().load(self.config)["plugins"]["enabled"], ["homeassistant"])

    def test_refuses_unmanaged_plugin_without_changing_config(self):
        self.config.write_text("model: {default: existing-model}\n")
        previous = self.config.read_bytes()
        target = self.home / "plugins/homeassistant"
        target.mkdir(parents=True)
        (target / "custom.py").write_text("# local changes\n")
        with self.assertRaisesRegex(ValueError, "unmanaged plugin"):
            setup.configure(self.home, self.source)
        self.assertEqual(self.config.read_bytes(), previous)
        self.assertTrue((target / "custom.py").is_file())

    def test_rejects_malformed_settings_without_publishing_plugin(self):
        for value in ("- not-a-mapping\n", "plugins: []\n", "plugins: {enabled: all}\n"):
            with self.subTest(value=value):
                self.config.write_text(value)
                with self.assertRaises(ValueError):
                    setup.configure(self.home, self.source)
                self.assertEqual(self.config.read_text(), value)
                self.assertFalse((self.home / "plugins/homeassistant").exists())


if __name__ == "__main__":
    unittest.main()
