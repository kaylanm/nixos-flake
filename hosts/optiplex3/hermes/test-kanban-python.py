"""Check the packaged Kanban worker's interpreter and dependency visibility.

Usage: python3 test-kanban-python.py /nix/store/...-hermes-agent
"""

import os
from pathlib import Path
import re
import subprocess
import sys
import unittest
from unittest.mock import patch


class WorkerPythonTests(unittest.TestCase):
    def test_packaged_interpreter_can_import_worker_dependencies(self):
        from hermes_cli.kanban_db_dispatch import _worker_argv

        python = os.environ["HERMES_PYTHON"]
        # Console-script wrappers run with a bare sys.executable on Nix.
        with patch.object(sys, "executable", "/bare/python"):
            argv = _worker_argv(None, "default", None)
        self.assertEqual(argv, [python, "-m", "hermes_cli.kanban_worker_client"])
        subprocess.run(
            [argv[0], "-c", "import hermes_cli.kanban_worker_client; "
             "from websockets.asyncio.client import connect"],
            check=True,
        )

    def test_unset_override_preserves_running_interpreter(self):
        from hermes_cli.kanban_db_dispatch import _worker_argv

        with patch.dict(os.environ):
            os.environ.pop("HERMES_PYTHON", None)
            self.assertEqual(
                _worker_argv(None, "default", None),
                [sys.executable, "-m", "hermes_cli.kanban_worker_client"],
            )


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] != "--worker-tests":
        package = Path(sys.argv[1])
        wrapper = (package / "bin/hermes").read_text()
        python = re.search(r"export HERMES_PYTHON='([^']+)'", wrapper)[1]
        root = re.search(r"export HERMES_PYTHON_SRC_ROOT='([^']+)'", wrapper)[1]
        env = dict(os.environ, HERMES_PYTHON=python, PYTHONPATH=root,
                   PYTHONDONTWRITEBYTECODE="1")
        raise SystemExit(subprocess.run(
            [python, str(Path(__file__).resolve()), "--worker-tests"], env=env,
        ).returncode)
    unittest.main(argv=[sys.argv[0]], verbosity=2)
