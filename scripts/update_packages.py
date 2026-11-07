"""Update only independent release packages; never writes to GitHub."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

PACKAGES = {
    "sane-scan-pdf": "pkgs/sane-scan-pdf/default.nix",
    "octoapp": "pkgs/octoapp/default.nix",
}


def update(root, package, *, apply=False, run=subprocess.run):
    """Resolve a stable release and realize its package in an isolated copy."""
    relative = PACKAGES[package]
    root = Path(root).resolve()
    original = (root / relative).read_bytes()
    with tempfile.TemporaryDirectory(prefix="nix-package-update-") as temporary:
        copy = Path(temporary) / "repo"
        shutil.copytree(root, copy, ignore=shutil.ignore_patterns(".git", "__pycache__", "result", "result-*"))
        before = {p.relative_to(copy): p.read_bytes() for p in copy.rglob("*") if p.is_file()}
        run(["nix-update", "--flake", package, "--version=stable"], cwd=copy, check=True)
        after = {p.relative_to(copy): p.read_bytes() for p in copy.rglob("*") if p.is_file()}
        unexpected = sorted(str(p) for p in before.keys() | after.keys()
                            if before.get(p) != after.get(p) and str(p) != relative)
        if unexpected:
            raise RuntimeError(f"Unexpected updater changes: {', '.join(unexpected)}")
        run(["nix", "build", "--no-link", "--no-write-lock-file", f".#{package}"], cwd=copy, check=True)
        updated = (copy / relative).read_bytes()
        if apply and updated != original:
            (root / relative).write_bytes(updated)
        return updated != original


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", choices=PACKAGES)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", "--dry-run", action="store_true", help="update/build in a temporary copy only")
    mode.add_argument("--apply", action="store_true", help="copy the pin back only after a successful build")
    args = parser.parse_args()
    try:
        changed = update(Path.cwd(), args.package, apply=args.apply)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Package update failed: {error}\n")
    print(f"{args.package}: {'update available' if changed else 'already current'}; targeted build passed")


if __name__ == "__main__":
    main()
