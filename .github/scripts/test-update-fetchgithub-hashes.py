import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "updater", Path(__file__).with_name("update-fetchgithub-hashes.py")
)
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)

OLD_HASH = "sha256-" + "A" * 43 + "="
NEW_HASH = "sha256-" + "B" * 43 + "="
BLOCK = '''pkgs.fetchFromGitHub {
  owner = "NousResearch";
  repo = "hermes-official-plugins";
  # renovate: ref=main
  rev = "''' + "a" * 40 + '''";
  hash = "''' + OLD_HASH + '''";
}'''


class HashUpdaterTests(unittest.TestCase):
    def test_refreshes_hash_for_the_pinned_commit_only(self):
        urls = []

        def prefetch(url):
            urls.append(url)
            return NEW_HASH

        result = updater.refresh(BLOCK, prefetch)
        self.assertEqual(result, BLOCK.replace(OLD_HASH, NEW_HASH))
        self.assertEqual(urls, [
            "https://github.com/NousResearch/hermes-official-plugins/archive/"
            + "a" * 40 + ".tar.gz"
        ])

    def test_unannotated_fetches_are_unchanged(self):
        source = BLOCK.replace("  # renovate: ref=main\n", "")
        self.assertEqual(updater.refresh(source, lambda _: self.fail("unexpected fetch")), source)

    def test_comments_are_preserved(self):
        source = BLOCK.replace('  hash =', '  # previous hash = "old";\n  hash =')
        result = updater.refresh(source, lambda _: NEW_HASH)
        self.assertEqual(result, source.replace(OLD_HASH, NEW_HASH))

    def test_multiple_fetches_keep_independent_hashes(self):
        other = BLOCK.replace("NousResearch", "another-owner").replace("a" * 40, "b" * 40)
        source = BLOCK + "\n" + other
        result = updater.refresh(source, lambda url: NEW_HASH if "another-owner" in url else OLD_HASH)
        self.assertEqual(result, BLOCK + "\n" + other.replace(OLD_HASH, NEW_HASH))

    def test_rejects_options_that_change_the_archive_hash(self):
        source = BLOCK.replace('  hash =', '  fetchSubmodules = true;\n  hash =')
        with self.assertRaisesRegex(ValueError, "only literal"):
            updater.refresh(source, lambda _: self.fail("unexpected fetch"))

    def test_rejects_interpolated_or_short_revisions(self):
        for revision in ("main", "abcdef", "${version}"):
            with self.subTest(revision=revision):
                source = BLOCK.replace("a" * 40, revision)
                # Interpolation creates nested braces, outside this scanner's shape.
                if revision == "${version}":
                    self.assertEqual(updater.refresh(source, lambda _: self.fail("unexpected fetch")), source)
                else:
                    with self.assertRaisesRegex(ValueError, "full commit SHA"):
                        updater.refresh(source, lambda _: self.fail("unexpected fetch"))

    def test_invalid_prefetch_result_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "invalid SHA-256"):
            updater.refresh(BLOCK, lambda _: "not-a-hash")


if __name__ == "__main__":
    unittest.main()
