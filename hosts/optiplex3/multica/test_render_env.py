import importlib.util
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("render_env", Path(__file__).with_name("render-env.py"))
renderer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)

class EnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.values = {key: f"{index:064x}" for index, key in enumerate(renderer.FIELDS, 1)}
        self.text = "".join(f"{key}={value}\n" for key, value in self.values.items())

    def test_extraction_and_credential_scope(self):
        files = renderer.environments(renderer.parse(self.text))
        self.assertEqual(files["postgres"], {"POSTGRES_PASSWORD": self.values["POSTGRES_PASSWORD"]})
        self.assertEqual(files["backend"]["JWT_SECRET"], self.values["JWT_SECRET"])
        self.assertEqual(files["backend"]["DATABASE_URL"], f"postgres://multica:{self.values['POSTGRES_PASSWORD']}@postgres:5432/multica?sslmode=disable")
        self.assertNotIn("JWT_SECRET", files["postgres"])
        self.assertNotIn("POSTGRES_PASSWORD", files["backend"])

    def test_rejects_invalid_input_without_disclosing_values(self):
        cases = [
            self.text + "POSTGRES_PASSWORD=do-not-disclose\n",
            self.text + "UNEXPECTED=do-not-disclose\n",
            self.text.replace(self.values["JWT_SECRET"], "$(do-not-disclose)"),
            self.text.replace(self.values["POSTGRES_PASSWORD"], "${do-not-disclose}"),
            self.text.replace(f"JWT_SECRET={self.values['JWT_SECRET']}\n", ""),
        ]
        for text in cases:
            with self.subTest(text=text):
                with self.assertRaises(ValueError) as error:
                    renderer.parse(text)
                self.assertNotIn("do-not-disclose", str(error.exception))

    def test_file_permissions_and_no_partial_render(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "secrets.env"
            destination = Path(directory) / "runtime"
            destination.mkdir(mode=0o700)
            source.write_text(self.text)
            source.chmod(0o600)
            # The sandbox is not necessarily root; keep the real permission checks.
            real_fstat = os.fstat

            def root_metadata(fd):
                metadata = real_fstat(fd)
                fields = list(metadata)
                fields[4] = 0
                return os.stat_result(fields)

            with patch.object(renderer.os, "fstat", side_effect=root_metadata):
                renderer.render(source, destination)
                self.assertEqual(len(list(destination.iterdir())), 2)
                for file in destination.iterdir():
                    self.assertEqual(stat.S_IMODE(file.stat().st_mode), 0o600)
                original = (destination / "backend.env").read_text()
                source.write_text("POSTGRES_PASSWORD=invalid\n")
                with self.assertRaises(ValueError):
                    renderer.render(source, destination)
                self.assertEqual((destination / "backend.env").read_text(), original)
                source.chmod(0o644)
                with self.assertRaisesRegex(ValueError, "root-owned"):
                    renderer.render(source, destination)
            link = Path(directory) / "link.env"
            link.symlink_to(source)
            with self.assertRaises(OSError):
                renderer.render(link, destination)

    def test_rejects_nonroot_owner_and_fifo(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "secrets.env"
            source.write_text(self.text)
            source.chmod(0o600)
            if os.geteuid() != 0:
                with self.assertRaisesRegex(ValueError, "root-owned"):
                    renderer.render(source, directory)
                with self.assertRaisesRegex(ValueError, "as root"):
                    renderer.initialize(source)
            source.unlink()
            os.mkfifo(source, 0o600)
            with self.assertRaises(ValueError):
                renderer.render(source, directory)

    def test_initialization_never_overwrites_existing_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "secrets.env"
            with patch.object(renderer.os, "geteuid", return_value=0):
                renderer.initialize(path)
                initial = path.read_text()
                self.assertEqual(set(renderer.parse(initial)), set(renderer.FIELDS))
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                real_fstat = os.fstat
                def root_metadata(fd):
                    fields = list(real_fstat(fd))
                    fields[4] = 0
                    return os.stat_result(fields)
                with patch.object(renderer.os, "fstat", side_effect=root_metadata):
                    renderer.initialize(path)
                self.assertEqual(path.read_text(), initial)


if __name__ == "__main__":
    unittest.main()
