#!/usr/bin/env python3
"""Fetch locked tarball URLs independently before publishing a lock update."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def validate(lock, inputs=None):
    nodes = lock["nodes"]
    names = sorted(nodes) if inputs is None else inputs
    # Do not reuse the updater's URL -> tree cache: it may contain the same
    # inconsistent immutable-URL mapping we are trying to detect. Fetch without
    # narHash so an already-present expected store path cannot bypass the URL.
    with tempfile.TemporaryDirectory(prefix="flake-tarball-validation-") as cache:
        env = dict(os.environ, XDG_CACHE_HOME=cache)
        for name in names:
            locked = nodes[name].get("locked", {})
            if locked.get("type") != "tarball":
                continue
            result = subprocess.run(
                ["nix", "flake", "prefetch", "--refresh", "--json", locked["url"]],
                check=True, capture_output=True, text=True, env=env,
            )
            actual = json.loads(result.stdout)["hash"]
            if actual != locked["narHash"]:
                raise ValueError(
                    f"{name}: hash mismatch for {locked['url']}: "
                    f"locked {locked['narHash']}, fetched {actual}; refusing publication"
                )
            print(f"{name}: verified {locked['url']}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock-file", type=Path, default=Path("flake.lock"))
    parser.add_argument("--input", action="append", dest="inputs")
    args = parser.parse_args()
    try:
        validate(json.loads(args.lock_file.read_text()), args.inputs)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Tarball validation failed: {error}\n{getattr(error, 'stderr', '') or ''}")


if __name__ == "__main__":
    main()
