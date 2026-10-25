"""Link the Nix-pinned plugin and enable it without invoking Hermes's PM."""

import io
import os
from pathlib import Path
import sys
import tempfile
from collections.abc import MutableMapping

from ruamel.yaml import YAML


def configure(home: Path, source: Path) -> None:
    if not (source / "plugin.yaml").is_file():
        raise ValueError(f"Home Assistant plugin manifest missing under {source}")
    home.mkdir(parents=True, exist_ok=True)
    config_path = home / "config.yaml"
    yaml = YAML()
    yaml.preserve_quotes = True
    original = config_path.read_text() if config_path.exists() else ""
    config = yaml.load(original) if original.strip() else {}
    if not isinstance(config, MutableMapping):
        raise ValueError("Hermes config.yaml must contain a mapping")
    plugins = config.setdefault("plugins", {})
    if not isinstance(plugins, MutableMapping):
        raise ValueError("Hermes plugins setting must contain a mapping")
    for key in ("enabled", "disabled"):
        if key in plugins and (
            not isinstance(plugins[key], list)
            or not all(isinstance(name, str) for name in plugins[key])
        ):
            raise ValueError(f"Hermes plugins.{key} must contain a list of names")
    enabled = plugins.setdefault("enabled", [])
    if "homeassistant" not in enabled:
        enabled.append("homeassistant")
    if "disabled" in plugins:
        while "homeassistant" in plugins["disabled"]:
            plugins["disabled"].remove("homeassistant")

    target = home / "plugins" / "homeassistant"
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and not target.is_symlink():
        raise ValueError(
            f"Refusing to replace an unmanaged plugin at {target}; move it aside first"
        )
    if not target.is_symlink() or target.readlink() != source:
        with tempfile.TemporaryDirectory(dir=target.parent) as staging:
            link = Path(staging) / "homeassistant"
            link.symlink_to(source, target_is_directory=True)
            link.replace(target)

    output = io.StringIO()
    yaml.dump(config, output)
    updated = output.getvalue()
    if updated != original:
        # Resolve an existing config symlink so it is preserved as well.
        destination = config_path.resolve()
        with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, delete=False) as tmp:
            try:
                tmp.write(updated)
                tmp.flush()
                os.fsync(tmp.fileno())
                os.replace(tmp.name, destination)
            finally:
                Path(tmp.name).unlink(missing_ok=True)


if __name__ == "__main__":
    configure(Path(sys.argv[1]), Path(sys.argv[2]))
