"""Extract per-service environments without evaluating shell or Compose syntax."""

import os
from pathlib import Path
import re
import secrets
import stat
import sys
import tempfile


FIELDS = {
    "BUZZ_RELAY_PRIVATE_KEY": (64, 64),
    "BUZZ_GIT_HOOK_HMAC_SECRET": (64, 64),
    "POSTGRES_PASSWORD": (64, 64),
    "REDIS_PASSWORD": (64, 64),
    "BUZZ_S3_ACCESS_KEY": (20, 64),
    "BUZZ_S3_SECRET_KEY": (64, 64),
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
    order = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    if not 0 < int(values["BUZZ_RELAY_PRIVATE_KEY"], 16) < order:
        raise ValueError("BUZZ_RELAY_PRIVATE_KEY must be a valid secp256k1 secret scalar")
    return values


def environments(values):
    s3 = {key: values[key] for key in ("BUZZ_S3_ACCESS_KEY", "BUZZ_S3_SECRET_KEY")}
    return {
        "relay": {
            **s3,
            **{key: values[key] for key in (
                "BUZZ_RELAY_PRIVATE_KEY", "BUZZ_GIT_HOOK_HMAC_SECRET"
            )},
            "DATABASE_URL": f"postgres://buzz:{values['POSTGRES_PASSWORD']}@postgres:5432/buzz",
            "REDIS_URL": f"redis://:{values['REDIS_PASSWORD']}@redis:6379",
        },
        "postgres": {"POSTGRES_PASSWORD": values["POSTGRES_PASSWORD"]},
        "redis": {"REDIS_PASSWORD": values["REDIS_PASSWORD"]},
        "minio": {
            "MINIO_ROOT_USER": values["BUZZ_S3_ACCESS_KEY"],
            "MINIO_ROOT_PASSWORD": values["BUZZ_S3_SECRET_KEY"],
        },
        "minio-init": {**s3, "BUZZ_S3_BUCKET": "buzz-media"},
    }


def render(source, destination):
    # Reject symlinks and credentials readable by other users before reading.
    with os.fdopen(os.open(source, os.O_RDONLY | os.O_NOFOLLOW)) as stream:
        metadata = os.fstat(stream.fileno())
        if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0
                or stat.S_IMODE(metadata.st_mode) & 0o077):
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
    values = {key: secrets.token_hex(32) for key in FIELDS}
    values["BUZZ_S3_ACCESS_KEY"] = secrets.token_hex(16)
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
        print(f"Buzz environment setup failed: {error}", file=sys.stderr)
        sys.exit(1)
