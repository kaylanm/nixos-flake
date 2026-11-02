import json
import pathlib
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).with_name('migrate-secrets')


class MigrationTests(unittest.TestCase):
    def test_preserves_file_payloads_exactly(self):
        module = runpy.run_path(str(SCRIPT), run_name='migration_test')
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            etc = root / 'etc'
            etc.mkdir()
            values = {
                'restic-env': 'TOKEN="synthetic"\n\n',
                'restic-password': '  synthetic:\tpassword',
                'restic-repository': 's3:example.invalid/bucket\n',
            }
            for name, value in values.items():
                (etc / name).write_text(value)
            repo = root / 'repo'
            repo.mkdir()
            with patch('subprocess.run') as encrypt:
                encrypt.return_value = subprocess.CompletedProcess([], 0, b'encrypted fixture', b'')
                output = module['migrate']('optiplex2', repo, root)
            payload = json.loads(encrypt.call_args.kwargs['input'])
            self.assertEqual(payload, {
                'restic-environment': values['restic-env'],
                'restic-password': values['restic-password'],
                'restic-repository': values['restic-repository'],
            })
            self.assertEqual(output.read_bytes(), b'encrypted fixture')
            self.assertEqual(output.stat().st_mode & 0o777, 0o644)

    def test_existing_output_is_not_overwritten(self):
        module = runpy.run_path(str(SCRIPT), run_name='migration_test')
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            output = root / 'secrets' / 'optiplex2.yaml'
            output.parent.mkdir()
            output.write_bytes(b'existing ciphertext')
            with patch('subprocess.run') as encrypt:
                with self.assertRaises(FileExistsError):
                    module['migrate']('optiplex2', root, root)
                encrypt.assert_not_called()
            self.assertEqual(output.read_bytes(), b'existing ciphertext')

    def test_encryption_failure_creates_no_output(self):
        module = runpy.run_path(str(SCRIPT), run_name='migration_test')
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / 'etc').mkdir()
            for name in ('restic-env', 'restic-password', 'restic-repository'):
                (root / 'etc' / name).write_text('synthetic')
            with patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, 'sops')):
                with self.assertRaises(subprocess.CalledProcessError):
                    module['migrate']('optiplex2', root, root)
            self.assertFalse((root / 'secrets' / 'optiplex2.yaml').exists())

    def test_documented_ssh_to_age_identity(self):
        import os
        import shutil
        if not all(shutil.which(tool) for tool in ('sops', 'ssh-keygen', 'ssh-to-age')):
            self.skipTest('requires sops, ssh-keygen, ssh-to-age')
        module = runpy.run_path(str(SCRIPT), run_name='migration_test')
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            key = root / 'ssh.key'
            subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(key)], check=True)
            recipient = subprocess.check_output(['ssh-to-age', '-i', str(key) + '.pub'], text=True).strip()
            (root / '.sops.yaml').write_text(json.dumps({'creation_rules': [{'age': recipient}]}))
            (root / 'etc').mkdir()
            for source in module['SOURCES']['optiplex2'].values():
                (root / source).write_text('synthetic')
            output = module['migrate']('optiplex2', root, root)
            env = dict(os.environ, SOPS_AGE_KEY_CMD=f'ssh-to-age -private-key -i {key}')
            decrypted = subprocess.check_output(['sops', '--decrypt', '--output-type', 'json', str(output)], env=env)
            self.assertEqual(set(json.loads(decrypted).values()), {'synthetic'})

    def test_real_sops_roundtrip(self):
        import os
        import shutil
        if not shutil.which('sops') or not shutil.which('age-keygen'):
            self.skipTest('requires sops and age-keygen')
        module = runpy.run_path(str(SCRIPT), run_name='migration_test')
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            key = root / 'age.key'
            subprocess.run(['age-keygen', '-o', str(key)], capture_output=True, check=True)
            recipient = subprocess.check_output(['age-keygen', '-y', str(key)], text=True).strip()
            (root / '.sops.yaml').write_text(json.dumps({'creation_rules': [{
                'path_regex': '^secrets/optiplex[12]\\.yaml$', 'age': recipient,
            }]}))
            for host, sources in module['SOURCES'].items():
                expected = {}
                for index, (name, source) in enumerate(sources.items()):
                    payload = ('  synthetic:"value"\t\\\r\n\n' if index % 2 else 'no-newline')
                    path = root / source
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(payload.encode())
                    expected[name] = payload
                output = module['migrate'](host, root, root)
                env = dict(os.environ, SOPS_AGE_KEY_FILE=str(key))
                decrypted = subprocess.check_output([
                    'sops', '--decrypt', '--output-type', 'json', str(output),
                ], env=env)
                self.assertEqual(json.loads(decrypted), expected)
                self.assertNotIn(b'no-newline', output.read_bytes())


if __name__ == '__main__':
    unittest.main()
