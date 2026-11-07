# Release package updates

`Update release packages` checks weekly (Monday 08:23 UTC) and supports manual
`workflow_dispatch`. It proposes **one reviewed PR per package**, using stable
branches `automation/package-sane-scan-pdf` and `automation/package-octoapp`.
It never commits to main or enables automatic merging. This is separate from the
existing flake.lock updater, whose policy is unchanged.

## Allowlist and exclusions

Only these independent, release-based GitHub sources are automated:

| Flake package | Source | Definition |
| --- | --- | --- |
| `sane-scan-pdf` | `rocketraman/sane-scan-pdf`, stable releases (`v` prefix) | `pkgs/sane-scan-pdf/default.nix` |
| `octoapp` | `crysxd/OctoApp-Plugin`, stable releases | `pkgs/octoapp/default.nix` |

The Python allowlist and workflow matrix are explicit and covered by contracts.
`nix-update --version=stable` discovers stable releases, updates the version and
fixed-output source hash, then `nix build --no-link --no-write-lock-file` realizes
that specific package. No `--version=branch`, HEAD tracking, update scripts,
commit/push flags, or generic repository-wide rewriting is used. Every update,
including a major release, still needs compatibility review; a build alone is
not an application smoke test.

**Intentionally excluded:**

- `buzz-agent-tools`: its source revision must match optiplex3's Buzz relay.
  Updating just the GitHub revision breaks that coupling, and a source update
  also needs a newly verified `cargoHash` plus CLI/ACP/relay compatibility tests.
  Do not blindly follow HEAD or infer a relay upgrade from an upstream release.
- `hermes-official-plugins`: the Home Assistant plugin revision follows the
  catalog of the **installed Hermes version** (currently documented in
  `hosts/optiplex3/hermes.nix`), not the plugin repository's HEAD or latest tag.
  Coordinate changes with the Hermes package/catalog and provisioning tests.
- Other source pins and flake inputs: not part of this allowlist. Flake inputs
  continue to use the existing lock updater.

A dedicated coupled updater would need an agreed authoritative deployment pin
and compatibility gates. Discuss that policy separately before implementing it;
this workflow deliberately does not guess.

## Repository setup (administrator required)

Under **Settings → Secrets and variables → Actions**, configure:

1. Repository **variable** `PACKAGE_UPDATE_APP_ID`: the numeric GitHub App ID.
2. Repository **secret** `PACKAGE_UPDATE_APP_PRIVATE_KEY`: the complete PEM
   private key for that App. Do not put the key in a variable, Nix expression,
   checkout, workflow file, command-line argument, or documentation.
3. Install the App on this repository and approve repository permissions
   **Contents: read and write** and **Pull requests: read and write**.
   Metadata read is implicit. The scheduled updater does not need Workflows,
   Actions, Issues, or Administration write permissions.
4. Allow the pinned Actions in repository/organization Actions policy, enable
   scheduled workflows, and retain branch protection/review/required checks on
   main. The human merging PRs remains responsible for deployment implications.

For this deployment, `kaylanm-hermes-agent` has App ID `5470392` and installation
ID `175225255`. The installation ID is **not** the App ID; the action discovers
it, so there is no installation-ID variable. A separate least-privilege App is
also supported. These identifiers are examples, **not proof that repository
variables/secrets have been configured**. They have not been set by this change.
Publishing fails explicitly if either required setting is absent.

The ordinary job `GITHUB_TOKEN` has only `contents: read`, and checkout uses
`persist-credentials: false`. After tests, update, and targeted build succeed,
the workflow mints an App installation token restricted to **this repository**
and **contents/pull_requests write**, even if the App has broader permissions.
The token is revoked by the action's cleanup. App-created PRs trigger normal
`pull_request` checks, unlike PRs created with the ordinary `GITHUB_TOKEN`.

Only main can run the publishing job; checkout explicitly selects main. Manual
dispatches on other refs are skipped. No `pull_request_target`, PR ref checkout,
or execution of PR-controlled code with write credentials is used. The separate
`Package updater tests` workflow runs on PRs with read-only credentials and no
App secret. All third-party Actions are SHA-pinned; update those pins deliberately.

## Manual validation (no GitHub writes)

Run from the repository root, with Nix flakes enabled. Tools are a reproducible
flake output backed by the **existing nixpkgs lock**: nix-update, Nix, Git, Python
with PyYAML, and actionlint. No new input or flake.lock update is needed.

```sh
# Unit, workflow contract, and real Nix/Python-scope integration tests
nix shell --no-write-lock-file .#package-update-tools --command \
  python3 -m unittest discover -s tests -v
nix shell --no-write-lock-file .#package-update-tools --command \
  actionlint .github/workflows/package-updates.yml .github/workflows/package-update-tests.yml

# Resolve release + hash, then build, in a temporary copy; no checkout edits
nix shell --no-write-lock-file .#package-update-tools --command \
  python3 scripts/update_packages.py sane-scan-pdf --check
nix shell --no-write-lock-file .#package-update-tools --command \
  python3 scripts/update_packages.py octoapp --dry-run

# Same validation, then copy ONLY the validated package definition back locally
nix shell --no-write-lock-file .#package-update-tools --command \
  python3 scripts/update_packages.py octoapp --apply
git diff -- pkgs/octoapp/default.nix
```

Neither script mode has a GitHub write API or commits anything. No GitHub token
is required for public release checks (subject to upstream availability/rate
limits). `--check`/`--dry-run` writes only temporary files and the Nix store/cache;
it is not an offline or evaluation-only mode. It exits zero whether current or
an update is available, and nonzero on failure. Both modes print the result and
build status. Run from a trusted checkout without local secret files: the
isolated source copy excludes `.git`, Python bytecode caches and result links,
but otherwise includes checkout files. Nix source copies are world-readable in
the store. Temporary directories honor `TMPDIR` and are removed on exit.

For testing newly created, not-yet-Git-tracked Nix files, use `path:.#...` instead
of `.#...` (or stage the new files). Normal Git-backed flakes omit untracked files.

In GitHub's Actions UI, manually dispatch **Update release packages** on main
with `check_only: true` (the default) to test without any GitHub writes or App
credentials. It may modify the disposable runner checkout. Setting it to false
publishes PRs, as scheduled runs do; do not use false just to test configuration.

## Scope and OctoPrint packaging

`pkgs/default.nix` automatically calls every subdirectory with `default.nix`
through the supplied top-level `callPackage`; adding a directory is **also an
overlay change**, not just a flake-output addition. OctoApp therefore defaults to
`octoprint.python.pkgs.buildPlugin` and its scoped Python dependencies, never
`python3Packages.buildPythonPackage`. Its argument is intentionally named
`pluginPythonPackages`: top-level `pythonPackages` is a deprecated Nixpkgs alias
that `callPackage` would otherwise inject, overriding a default argument.

The pi4 module explicitly passes `pyself.buildPlugin` and `pysuper` dependencies,
preserving its prior Python dependency-set choice. The flake `octoapp` output
uses the locked unstable OctoPrint scope and stable fetcher, just like that
module. Integration tests assert the two plugin derivations are identical,
the dependency set is unchanged, auto-discovery evaluates, and nix-update's
version/source positions resolve to the local definition. The wrapper retains
local version position because Nixpkgs' `buildPlugin` reconstructs that attribute;
it does not substitute a different builder or dependency set. `format =
"setuptools"` is explicit because the pinned `buildPlugin` requires it.

The pi4 configuration currently **comments out** the OctoPrint module import.
This change does not enable it or change any service activation. CI separately
evaluates the dormant module's plugin so that disabled imports cannot hide a
broken update target. The scheduled build is x86_64-linux, not an aarch64 pi4
system build or printer runtime test.

## No-op, re-run, and failure behavior

- Every successful run builds its target, even when the release is unchanged.
  An unchanged pin causes no commit, token mint, or PR creation.
- Changes use the same branch each time; create-pull-request updates the existing
  PR rather than creating a PR for every run. Branches are automation-owned:
  do not put manual work on them. Concurrent workflow runs are serialized and
  package matrix failures do not cancel the other package.
- The updater checks all copied files after nix-update and refuses changes
  outside the selected package definition (including flake.lock). Only after a
  successful targeted build can `--apply` copy that definition back.
- Discovery, hash, evaluation, unexpected-file, or build failures abort the job
  before token creation and PR publication. Consult Actions/Nix logs, fix the
  package or tooling in a normal reviewed PR, then re-run. Nothing bypasses the
  failing build. A failed run leaves any previously opened PR as-is.
- If a pin is updated manually on main, or an upstream release is withdrawn,
  an older PR can become stale; the no-op path intentionally does not mint a
  token to close it. Close a stale PR/delete its automation branch manually.
- Review and merge approved update PRs normally. Do not enable automerge. The
  existing NixOS PR build workflow still runs for the App-created PR, alongside
  updater contracts; neither replaces hardware/service compatibility review.
