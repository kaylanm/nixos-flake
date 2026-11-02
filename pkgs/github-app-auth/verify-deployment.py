"""Read-only optiplex3 integration check; run from the repository root.

--live uses the configured runtime key and GitHub, never prints credentials.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def command(args, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, **kwargs)
    if result.returncode:
        # Do not echo captured helper output, API bodies or inherited credentials.
        raise RuntimeError("command failed: " + args[0])
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true")
    args = parser.parse_args()
    prefix = "path:.#nixosConfigurations.optiplex3"
    environments = [json.loads(command(["nix", "eval", f"{prefix}.config.systemd.services.{service}.environment", "--json"]))
                    for service in ("hermes", "hermes-dashboard")]
    settings = environments[0]
    for name in ("GITHUB_APP_ID", "GITHUB_APP_INSTALLATION_ID", "GITHUB_APP_PRIVATE_KEY_FILE", "GIT_CONFIG_GLOBAL"):
        assert settings[name] == environments[1][name], name
    assert settings["GITHUB_APP_PRIVATE_KEY_FILE"].startswith("/etc/hermes/")
    package, config = command(["nix", "build", f"{prefix}.pkgs.github-app-auth",
                               f"{prefix}.config.systemd.services.hermes.environment.GIT_CONFIG_GLOBAL",
                               "--no-link", "--print-out-paths"]).splitlines()
    assert config == settings["GIT_CONFIG_GLOBAL"]
    helpers = command(["git", "config", "--file", config, "--get-all", "credential.https://github.com.helper"]).splitlines()
    # command() strips the leading empty reset, so verify it directly as well.
    assert "helper =\n" in Path(config).read_text()
    assert helpers[-1] == package + "/bin/git-credential-github-app"
    for environment in environments:
        assert environment["PATH"].split(":")[0] == package + "/bin"
    print("PASS: both service environments, pinned package, scoped helper and reset")
    if not args.live:
        return
    environment = dict(os.environ)
    for name in ("GITHUB_APP_ID", "GITHUB_APP_INSTALLATION_ID", "GITHUB_APP_PRIVATE_KEY_FILE", "GIT_CONFIG_GLOBAL"):
        environment[name] = settings[name]
    environment["GIT_TERMINAL_PROMPT"] = "0"
    # gh-app must work with no nix/python/openssl/gh discoverable through PATH.
    gh_environment = dict(environment, PATH="/nonexistent")
    count = command([package + "/bin/gh-app", "api", "installation/repositories", "--jq", ".total_count"], env=gh_environment)
    assert int(count) > 0
    print("PASS: packaged gh-app authenticated with an empty runtime PATH")
    with tempfile.TemporaryDirectory() as directory:
        # A previous system-level helper must be reset by our generated global config.
        # This sentinel is deliberately not a real token.
        system_config = Path(directory) / "system.gitconfig"
        system_config.write_text('[credential]\n helper = "!f() { echo username=sentinel; echo password=sentinel; }; f"\n')
        environment["GIT_CONFIG_SYSTEM"] = str(system_config)
        credentials = command(["git", "credential", "fill"], env=environment,
                              input="protocol=https\nhost=github.com\n\n")
        fields = dict(line.split("=", 1) for line in credentials.splitlines() if "=" in line)
        assert fields.get("username") == "x-access-token"
        assert fields.get("password") and fields["password"] != "sentinel"
        del credentials, fields
        print("PASS: Git credential fill reset the earlier helper (credentials not printed)")
    result = command(["git", "ls-remote", "https://github.com/kaylanm/dotfiles.git", "HEAD"], env=environment)
    assert result.endswith("\tHEAD")
    print("PASS: private repository HTTPS HEAD read")


if __name__ == "__main__":
    main()
