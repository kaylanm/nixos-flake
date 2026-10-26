"""Refresh hashes for simple fetchFromGitHub blocks marked '# renovate: ref=...'."""

import argparse
import json
from pathlib import Path
import re
import subprocess


BLOCK = re.compile(r"\b(?:pkgs\.)?fetchFromGitHub\s*\{(?P<body>[^{}]*)\}")
MARKER = re.compile(r"(?m)^\s*# renovate: ref=[A-Za-z0-9_./-]+\s*$")
FIELD = re.compile(r'\b(?P<name>owner|repo|rev|hash)\s*=\s*"(?P<value>[^"\n]+)"\s*;')


def refresh(text, prefetch):
    def replace(block):
        body = block["body"]
        if not MARKER.search(body):
            return block[0]
        # Archive prefetching only matches the simple fetchFromGitHub shape.
        # Reject fetchSubmodules, fetchLFS, postFetch, and interpolated attributes.
        uncommented = re.sub(r"(?m)#.*$", lambda m: " " * len(m[0]), body)
        fields = list(FIELD.finditer(uncommented))
        values = {field["name"]: field["value"] for field in fields}
        if len(fields) != 4 or set(values) != {"owner", "repo", "rev", "hash"} or FIELD.sub("", uncommented).strip():
            raise ValueError("Annotated fetchFromGitHub must contain only literal owner, repo, rev, and hash")
        if not re.fullmatch(r"[A-Za-z0-9-]+", values["owner"]) or not re.fullmatch(r"[A-Za-z0-9_.-]+", values["repo"]) or values["repo"] in (".", ".."):
            raise ValueError("Invalid GitHub owner or repository")
        if not re.fullmatch(r"[a-f0-9]{40}", values["rev"]):
            raise ValueError("Annotated fetchFromGitHub revision must be a full commit SHA")
        url = f'https://github.com/{values["owner"]}/{values["repo"]}/archive/{values["rev"]}.tar.gz'
        digest = prefetch(url)
        if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", digest):
            raise ValueError("Nix returned an invalid SHA-256 SRI hash")
        field = next(field for field in fields if field["name"] == "hash")
        start = block.start("body") - block.start() + field.start("value")
        end = block.start("body") - block.start() + field.end("value")
        return block[0][:start] + digest + block[0][end:]

    return BLOCK.sub(replace, text)


def prefetch(url):
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", "--unpack", url],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)["hash"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", type=Path)
    args = parser.parse_args()
    files = args.files
    if not files:
        tracked = subprocess.check_output(["git", "ls-files", "-z", "--", "*.nix"])
        files = [Path(name.decode()) for name in tracked.split(b"\0") if name]
    # Validate and fetch every replacement before writing any file.
    updates = []
    for path in files:
        original = path.read_text()
        updated = refresh(original, prefetch)
        if updated != original:
            updates.append((path, updated))
    for path, updated in updates:
        path.write_text(updated)
        print(f"Updated fetchFromGitHub hash in {path}")


if __name__ == "__main__":
    main()
