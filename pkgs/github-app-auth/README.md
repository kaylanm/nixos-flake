# GitHub App authentication for Hermes

`github-app-auth` installs `gh-app` and `git-credential-github-app`. Python,
OpenSSL, GitHub CLI, and CA certificates are pinned by the flake and referenced
by store paths: neither command runs `nix shell` or requires those binaries in
`PATH`. Every authenticated invocation signs a short-lived App JWT and requests
a fresh installation token. Tokens stay in process memory / the `gh` child
environment or Git's credential protocol; no token cache or gh login is written.

The package is generic. Supply these **runtime environment variables**:

- `GITHUB_APP_ID`
- `GITHUB_APP_INSTALLATION_ID`
- `GITHUB_APP_PRIVATE_KEY_FILE`: absolute path to an existing PEM key

The wrappers set the pinned `GITHUB_APP_OPENSSL` and `GITHUB_APP_GH` executables.
`gh-app` replaces inherited token variables and defaults explicitly to github.com.
This package supports github.com only, not GitHub Enterprise. Do not override the
host through gh arguments. Commands such as `gh-app auth token` explicitly reveal
the token; never use them in agent logs. Normal authentication errors omit API
bodies, signing output, key contents, and exception details.

## optiplex3 deployment

`hosts/optiplex3/hermes.nix` supplies App `5470392`, installation `175225255`, and
`/etc/hermes/kaylanm-hermes-agent.2026-10-25.private-key.pem` to **both** Hermes
services. These identifiers and the key's *pathname* are public configuration;
the key's **contents are never evaluated, copied, or included in the Nix store**.
Provision/rotate that file separately through the host's secret-management process.
Never stage it or use a Nix path literal / `builtins.readFile` for it.

Tmpfiles manages `/etc/hermes` as `root:hermes 0710`, the key as
`root:hermes 0640`, and `secrets.env` as `root:root 0600`. Hermes gets directory
traversal and key read access, **not directory listing or secrets.env read access**.
Systemd reads `EnvironmentFile` as root before dropping privileges. No files are
recursively chmodded and missing key material is not generated. Ensure secrets.env
does not override the managed `GITHUB_APP_*` or `GIT_CONFIG_GLOBAL` variables.

The service-only `GIT_CONFIG_GLOBAL` points at a generated, immutable Git config.
It replaces loading mutable `~/.gitconfig` (and the usual XDG global config) in
these processes. The github.com HTTPS credential section first resets earlier
helpers, then selects the packaged helper by absolute path. Other users' Git
configuration and Hermes's existing mutable files are untouched. Repository-local
or command-line Git config can still override global settings; this is standard
Git precedence, not an enforced security sandbox. Non-GitHub credentials are not
handled by this helper. Existing Git identity/settings in the replaced global
config are not inherited; add any required service identity declaratively.

Build and evaluate before deploying, from the repository root:

```sh
nix build .#github-app-auth --no-link -L
nix build .#nixosConfigurations.optiplex3.pkgs.github-app-auth --no-link -L
nix eval .#nixosConfigurations.optiplex3.config.system.build.toplevel.drvPath --raw
```

New files must be Git-tracked for `.#...` flake commands. During development,
`path:.#...` includes untracked files (inspect the tree for secrets first).
Deploy through the repository's normal optiplex3 NixOS deployment workflow; then
restart/check `hermes` and `hermes-dashboard` and inspect non-secret file metadata
with `stat`. A package build is **not** a host deployment.

After deployment, use `gh-app` on the services' PATH (or explicitly
`/run/current-system/sw/bin/gh-app`). The old absolute
`/var/lib/hermes/.local/bin/gh-app` still invokes the mutable, nix-shell-based
implementation and is **not replaced**. Update old instructions or remove the
legacy files separately after verifying deployment; this change neither edits
nor deletes them. Interactive shells need the runtime settings explicitly and
must opt into the generated Git config; the service environment is not a
host-wide export.

## Tests

```sh
nix shell nixpkgs#python3 --command python3 -m unittest discover -s pkgs/github-app-auth -v
nix shell nixpkgs#python3 --command python3 pkgs/github-app-auth/verify-deployment.py
# Requires the runtime key and installation's private kaylanm/dotfiles access:
nix shell nixpkgs#python3 --command python3 pkgs/github-app-auth/verify-deployment.py --live
```

Unit tests run automatically in the package's sandboxed check phase. They exercise
credential host/action scoping, JWT identity/timing, token exchange, fresh token
creation, inherited-token removal, pinned gh execution and redacted failures.
The integration check evaluates both service environments and builds the **host's**
package and generated Git config. `--live` proves gh API access without any runtime
PATH tools, verifies the Git helper resets an earlier credential helper without
printing its output, and reads a private repository's HEAD. It performs no pushes,
PR creation, login persistence, configuration edits, or service deployment.
Do not run `git credential fill` directly in logs: its stdout contains a token.
Read access does not independently prove write permissions or support for
user-token-only gh features.
