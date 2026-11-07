"""Bootstrap the exact Nix-installed Hermes interpreter; never install dependencies."""

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    launcher = Path(
        os.environ.get("HERMES_INSTALLED_LAUNCHER", "/run/current-system/sw/bin/hermes")
    ).resolve()
    text = launcher.read_text()

    def setting(name):
        match = re.search(r"^export " + name + r"='([^']+)'$", text, re.MULTILINE)
        if not match:
            raise SystemExit(f"Unsupported Nix wrapper: missing {name}")
        return match.group(1)

    python, source = setting("HERMES_PYTHON"), setting("HERMES_PYTHON_SRC_ROOT")
    root = Path(__file__).resolve().parent
    # This experiment never needs model/API secrets, OIDC settings or proxy
    # credentials from the invoking dashboard service environment.
    env = {
        key: os.environ[key]
        for key in ("PATH", "TMPDIR", "LANG", "LC_ALL", "TZ", "HOME", "HERMES_HOME")
        if key in os.environ
    }
    env.update(PYTHONPATH=source, PYTHONNOUSERSITE="1", PYTHONDONTWRITEBYTECODE="1")
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        with tempfile.TemporaryDirectory(
            prefix="tailscale-auth-", dir=os.environ.get("TMPDIR")
        ) as temp:
            env.update(HOME=temp, HERMES_HOME=temp, HERMES_SERVE_HEADLESS="1")
            # No production secrets inherited by the installed dashboard import.
            for key in list(env):
                if key.startswith(
                    ("HERMES_DASHBOARD_", "OPENAI_", "ANTHROPIC_", "NOUS_")
                ):
                    del env[key]
            result = subprocess.run(
                [python, "-m", "unittest", "discover", "-s", str(root), "-v"],
                check=False,
                env=env,
            )
            raise SystemExit(result.returncode)
    os.execve(python, [python, str(root / "server.py"), *sys.argv[1:]], env)


if __name__ == "__main__":
    main()
