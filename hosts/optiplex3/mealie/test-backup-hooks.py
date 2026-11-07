"""Isolated hook tests: fake service/database commands, real filesystem/archive."""
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


class BackupHooksTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.stage = self.root / "stage"
        self.runtime = self.root / "run"
        self.runtime.mkdir()
        self.state = self.root / "state"
        self.state.mkdir()
        (self.state / "recipe.txt").write_text("test recipe asset\n")
        self.log = self.root / "commands"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}", LOG=str(self.log))
        self.shim("systemctl", 'printf "%s\\n" "$*" >> "$LOG"\nexit 0\n')
        self.shim("runuser", 'printf "test database dump fixture\\n"\n')

    def shim(self, name, text):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + text)
        path.chmod(0o755)

    def hook(self, name):
        return subprocess.run(
            ["bash", str(HERE / name), str(self.stage), str(self.runtime), str(self.state)],
            env=self.env, text=True, capture_output=True,
        )

    def test_snapshot_prepared_and_service_restarted_before_upload(self):
        result = self.hook("backup-prepare.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.stage / "snapshot/database.dump").is_file())
        self.assertTrue((self.stage / "snapshot/assets.tar").is_file())
        self.assertEqual(self.log.read_text().splitlines(), [
            "is-active --quiet mealie.service", "stop mealie.service", "start mealie.service",
        ])
        self.assertFalse((self.runtime / "restart-mealie").exists())

    def test_failed_dump_cleanup_restarts_service_and_removes_partial_snapshot(self):
        self.shim("runuser", 'exit 42\n')
        result = self.hook("backup-prepare.sh")
        self.assertEqual(result.returncode, 42)
        self.assertTrue((self.runtime / "restart-mealie").exists())
        cleanup = self.hook("backup-cleanup.sh")
        self.assertEqual(cleanup.returncode, 0, cleanup.stderr)
        self.assertFalse((self.runtime / "restart-mealie").exists())
        self.assertFalse((self.stage / "snapshot").exists())
        self.assertEqual(self.log.read_text().splitlines()[-1], "start mealie.service")

    def test_inactive_application_is_not_started(self):
        self.shim("systemctl", 'printf "%s\\n" "$*" >> "$LOG"\nexit 3\n')
        self.assertNotEqual(self.hook("backup-prepare.sh").returncode, 0)
        self.assertEqual(self.hook("backup-cleanup.sh").returncode, 0)
        self.assertEqual(self.log.read_text().splitlines(), ["is-active --quiet mealie.service"])

    def test_archive_failure_leaves_recovery_marker_for_cleanup(self):
        self.shim("tar", 'exit 28\n')
        self.assertEqual(self.hook("backup-prepare.sh").returncode, 28)
        self.assertTrue((self.runtime / "restart-mealie").exists())
        self.assertEqual(self.hook("backup-cleanup.sh").returncode, 0)
        self.assertEqual(self.log.read_text().splitlines()[-1], "start mealie.service")

    def test_failed_recovery_keeps_marker_and_snapshot(self):
        self.shim("systemctl", 'case "$1" in start) exit 1;; esac\nexit 0\n')
        self.assertNotEqual(self.hook("backup-prepare.sh").returncode, 0)
        self.assertNotEqual(self.hook("backup-cleanup.sh").returncode, 0)
        self.assertTrue((self.runtime / "restart-mealie").exists())
        self.assertTrue((self.stage / "snapshot/database.dump").exists())

    @unittest.skipUnless(os.environ.get("RESTIC_BIN") and shutil.which("initdb"),
                         "set RESTIC_BIN and provide PostgreSQL tools for integration test")
    def test_real_postgresql_dump_restic_restore_and_asset_roundtrip(self):
        # Only systemctl and privilege switching are shimmed. PostgreSQL, pg_dump,
        # Restic backup/check/restore, pg_restore, and tar extraction are real.
        data = self.root / "postgres"
        socket = self.root / "socket"
        socket.mkdir()
        self.env.update(PGHOST=str(socket), PGPORT="55439")

        def run(*args):
            return subprocess.run(args, env=self.env, text=True, capture_output=True, check=True)

        run("initdb", "-D", str(data), "--auth=trust", "--no-locale")
        run("pg_ctl", "-D", str(data), "-l", str(self.root / "postgres.log"),
            "-o", f"-k {socket} -p 55439 -c listen_addresses=''", "-w", "start")
        self.addCleanup(lambda: run("pg_ctl", "-D", str(data), "-m", "immediate", "-w", "stop"))
        run("createdb", "mealie")
        run("psql", "-d", "mealie", "-v", "ON_ERROR_STOP=1", "-c",
            "CREATE TABLE backup_probe (recipe text); INSERT INTO backup_probe VALUES ('restore probe');")
        self.shim("runuser", 'shift 3\nexec "$@"\n')
        result = self.hook("backup-prepare.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        restic = os.environ["RESTIC_BIN"]
        self.env.update(RESTIC_REPOSITORY=str(self.root / "repository"),
                        RESTIC_PASSWORD="isolated-test-only-password",
                        RESTIC_CACHE_DIR=str(self.root / "cache"))
        run(restic, "init")
        run(restic, "backup", "--tag", "mealie-test", str(self.stage / "snapshot"))
        run(restic, "check", "--read-data")
        self.assertEqual(self.hook("backup-cleanup.sh").returncode, 0)
        target = self.root / "restore"
        run(restic, "restore", "latest", "--target", str(target))
        restored = target / str(self.stage / "snapshot").lstrip("/")
        run("createdb", "restored")
        run("pg_restore", "--exit-on-error", "--no-owner", "--no-acl", "-d", "restored",
            str(restored / "database.dump"))
        rows = run("psql", "-d", "restored", "-Atc", "SELECT recipe FROM backup_probe").stdout.strip()
        self.assertEqual(rows, "restore probe")
        with tarfile.open(restored / "assets.tar") as archive:
            self.assertEqual(archive.extractfile("./recipe.txt").read(), b"test recipe asset\n")


if __name__ == "__main__":
    unittest.main()
