# Flake lock update validation

The scheduled `Bump flake.lock` workflow still tracks the input policies in
`flake.nix`, including Rex's snapshot channel. It now validates tarball sources
and evaluates `auriga-nixos` **before** the auto-commit step. A failed fetch,
hash mismatch, or evaluation prevents publication; it does not rewrite a hash
or retry until some different release happens to pass. Full system builds
remain in the separate build workflow.

## Rex mismatch investigation

The updater run [44756729499](https://github.com/kaylanm/nixos-flake/actions/runs/44756729499)
ran ordinary `nix flake update` and committed `2318c4000b221d523d2d9e94a97f5ba923cf33b7`.
Its own update log already paired:

- URL: `https://pkgs.superlogical.com/rex/nix/snapshot/0.0.1795116584-ga086db.tar.gz`
- hash: `sha256-OFLLkgLobxm6EOnOdtn3eADsPT+KnYlis1WbeNCMvU0=`
- `lastModified`: `1795185608`

Independent fetches establish that this URL actually has hash
`sha256-9dchpzOQUrTNiEPBnLzPq0DW2JJrF0ZXKghVgpeYUa4=` and its `sources.json`
identifies release `0.0.1795116584-ga086db`. The locked hash belongs to release
`0.0.1795185608-gb04a65`; both the rolling snapshot endpoint and that release's
versioned URL produced it. Comparing the unpacked archives showed only
`sources.json` changed (version, commit, and binary URLs/hashes).

The repair changes only the URL to the new release, retaining the existing
hash and timestamp. Replacing the hash with the old archive's hash instead
would silently downgrade the intended update.

The subsequent [build run 44756865592](https://github.com/kaylanm/nixos-flake/actions/runs/44756865592)
failed on this mismatch before the host build matrix could be created. This
is not an auriga-specific package compilation failure.

Rex's rolling endpoint redirects to a mutable blob and advertises a versioned
URL through `Link: <...>; rel="immutable"`. The observed lock combines the old
version URL with the new content's hash and timestamp, consistent with a
publication/cache race between that metadata and the mutable blob. Historical
response headers are not available, so the precise upstream/CDN race cannot
be proven from the Actions logs. There is no evidence here that the old
versioned archive was overwritten or that our workflow manually calculated
the wrong hash. Upstream should ensure immutable-link metadata and the bytes
it describes stay consistent during releases, preferably redirecting the
rolling endpoint to the exact immutable archive.

The repository-side defect is certain: a successful update command was
published directly to main without checking whether another client could
fetch the resulting lock. Post-publication builds detected it too late.

## Independent tarball check

```sh
python3 -m unittest discover -s tests -p 'test_validate_flake_tarballs.py' -v
python3 scripts/validate_flake_tarballs.py
# Targeted diagnosis / historical lock:
python3 scripts/validate_flake_tarballs.py --input rex --lock-file flake.lock
nix eval --raw --no-write-lock-file .#nixosConfigurations.auriga-nixos.config.system.build.toplevel.drvPath
```

The checker validates every `type = tarball` lock node, including transitive
inputs, using its exact locked URL with no supplied expected hash. It uses a
fresh temporary `XDG_CACHE_HOME` and `--refresh` so the updater's cached URL
mapping cannot mask a bad lock. It compares the independently returned NAR
hash with the recorded one and fails closed on fetch errors or missing data.
Other fetcher types are unchanged. This catches inconsistent tarball pins,
not application incompatibility or every possible future upstream mutation.

This change does not switch to stable Rex releases, install new publishing
credentials, or redesign all dependency updates around PRs. Reviewed update
PRs would provide a stronger general gate for full-build regressions; the
current change addresses this incident without requiring new repository
secrets. There has been no host deployment as part of this repair.
