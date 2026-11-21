"""Extract per-service environments without evaluating shell or Compose syntax."""

import os
from pathlib import Path
import re
import secrets
import stat
import sys
import tempfile


FIELDS = {
    "JWT_SECRET": (64, 64),
    "POSTGRES_PASSWORD": (64, 64),
}


def parse(text):
    values = {}
    for number, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator or key not in FIELDS or key in values:
            raise ValueError(f"invalid or duplicate setting on line {number}")
        low, high = FIELDS[key]
        if not low <= len(value) <= high or not re.fullmatch(r"[0-9a-fA-F]+", value):
            raise ValueError(f"{key} must contain {low} to {high} hexadecimal characters")
        values[key] = value.lower()
    missing = FIELDS.keys() - values.keys()
    if missing:
        raise ValueError("missing settings: " + ", ".join(sorted(missing)))
    return values


def environments(values):
    return {
        "postgres": {"POSTGRES_PASSWORD": values["POSTGRES_PASSWORD"]},
        "backend": {
            "JWT_SECRET": values["JWT_SECRET"],
            "DATABASE_URL": f"postgres://multica:{values['POSTGRES_PASSWORD']}@postgres:5432/multica?sslmode=disable",
        },
    }


def render(source, destination):
    # Reject symlinks and credentials readable by other users before reading.
    with os.fdopen(os.open(source, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)) as stream:
        metadata = os.fstat(stream.fileno())
        if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0
                or stat.S_IMODE(metadata.st_mode) not in (0o400, 0o600)):
            raise ValueError("credentials must be a root-owned regular file with mode 0600 or 0400")
        files = environments(parse(stream.read()))
    for name, values in files.items():
        descriptor, temporary = tempfile.mkstemp(dir=destination)
        try:
            with os.fdopen(descriptor, "w") as stream:
                stream.write("".join(f"{key}={value}\n" for key, value in sorted(values.items())))
            os.replace(temporary, Path(destination) / f"{name}.env")
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def initialize(destination):
    if os.geteuid() != 0:
        raise ValueError("initialize credentials as root")
    if os.path.lexists(destination):
        # Validate an existing file without regenerating credentials.
        with os.fdopen(os.open(destination, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)) as stream:
            metadata = os.fstat(stream.fileno())
            if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0
                    or stat.S_IMODE(metadata.st_mode) not in (0o400, 0o600)):
                raise ValueError("existing credentials must be root-owned with mode 0600 or 0400")
            parse(stream.read())
        return
    values = {key: secrets.token_hex(32) for key in FIELDS}
    # Validate all generated values before creating anything on disk.
    content = "".join(f"{key}={value}\n" for key, value in sorted(values.items()))
    parse(content)
    Path(destination).parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as stream:
        stream.write(content)


if __name__ == "__main__":
    try:
        if len(sys.argv) == 3 and sys.argv[1] == "--init":
            initialize(sys.argv[2])
        elif len(sys.argv) == 3:
            render(sys.argv[1], sys.argv[2])
        else:
            raise ValueError("usage: render-env.py SOURCE DESTINATION_DIRECTORY | --init DESTINATION_FILE")
    except (OSError, ValueError) as error:
        print(f"Multica environment setup failed: {error}", file=sys.stderr)
        sys.exit(1)
