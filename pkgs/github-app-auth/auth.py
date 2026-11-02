"""Ephemeral GitHub App authentication; configuration and keys stay at runtime."""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request


def installation_token():
    app = os.environ["GITHUB_APP_ID"]
    installation = os.environ["GITHUB_APP_INSTALLATION_ID"]
    key = os.environ["GITHUB_APP_PRIVATE_KEY_FILE"]
    if not app.isdecimal() or not installation.isdecimal() or not os.path.isabs(key):
        raise ValueError("invalid runtime configuration")
    now = int(time.time())
    encode = lambda value: base64.urlsafe_b64encode(value).rstrip(b"=")
    body = b".".join(encode(json.dumps(part).encode()) for part in (
        {"alg": "RS256", "typ": "JWT"},
        {"iat": now - 60, "exp": now + 540, "iss": app},
    ))
    signature = subprocess.run(
        [os.environ.get("GITHUB_APP_OPENSSL", "openssl"), "dgst", "-sha256", "-sign", key],
        input=body, capture_output=True, check=True,
    ).stdout
    jwt = (body + b"." + encode(signature)).decode()
    request = urllib.request.Request(
        f"https://api.github.com/app/installations/{installation}/access_tokens",
        headers={"Authorization": "Bearer " + jwt,
                 "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28",
                 "User-Agent": "github-app-auth"},
        data=b"{}",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        token = json.load(response)["token"]
    if not isinstance(token, str) or not token or any(c in token for c in "\r\n\0"):
        raise ValueError("invalid token response")
    return token


def main(args):
    if args and args[0] == "credential":
        if len(args) != 2 or args[1] != "get":
            return 0
        fields = {}
        for line in sys.stdin:
            if line in ("\n", "\r\n"):
                break
            key, sep, value = line.rstrip("\r\n").partition("=")
            if sep:
                fields[key] = value
        if fields.get("protocol") != "https" or fields.get("host") != "github.com":
            return 0
        token = installation_token()
        sys.stdout.write("username=x-access-token\npassword=" + token + "\n\n")
    elif args and args[0] == "gh":
        token = installation_token()
        environment = dict(os.environ)
        for name in ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"):
            environment.pop(name, None)
        environment["GH_TOKEN"] = token
        environment["GH_HOST"] = "github.com"
        executable = os.environ["GITHUB_APP_GH"]
        os.execve(executable, [executable] + args[1:], environment)
    else:
        print("usage: gh-app ARGS... | git-credential-github-app get|store|erase", file=sys.stderr)
        return 2
    return 0


def run(args):
    try:
        return main(args)
    except urllib.error.HTTPError as error:
        print(f"github-app-auth: GitHub API returned HTTP {error.code}", file=sys.stderr)
        error.close()
    except Exception:
        # Exception messages, response bodies and OpenSSL stderr can contain secrets.
        print("github-app-auth: authentication failed; check runtime settings, key access and connectivity", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(run(sys.argv[1:]))
