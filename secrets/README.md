# Encrypted host secrets

This branch migrates **optiplex1, optiplex2 and optiplex3**. It is not ready to
deploy until their encrypted payload files have been generated and decryption
verified on the actual targets. No production secrets are included yet. A
successful Nix evaluation does **not** verify activation-time decryption.

## Current-main secret inventory

Each YAML key contains a complete file, not an individual environment variable.

| Host | Encrypted key | Existing source file |
| --- | --- | --- |
| optiplex1 | `acme-environment` | `/etc/acme-env` |
| optiplex1 | `linkwarden-nextauth-secret` | `/etc/nextauth-secret` |
| optiplex1 | `mosquitto-password-hash` | `/etc/mosquitto/passwd` |
| optiplex1 | `nut-password` | `/etc/nut-passwd` |
| optiplex1, optiplex2 | `restic-environment` | `/etc/restic-env` |
| optiplex1, optiplex2 | `restic-password` | `/etc/restic-password` |
| optiplex1, optiplex2 | `restic-repository` | `/etc/restic-repository` |
| optiplex1 | `zigbee2mqtt-secrets` | `/etc/zigbee2mqtt/secret.yaml` |
| optiplex3 | `buzz-environment` | `/etc/buzz/secrets.env` |
| optiplex3 | `hermes-environment` | `/etc/hermes/secrets.env` |
| optiplex3 | `github-app-private-key` | `/etc/hermes/kaylanm-hermes-agent.2026-10-25.private-key.pem` |

The three optiplex3 files were missing from the original branch. The whole Hermes
environment preserves its Buzz agent identity/attestation, model API keys, OIDC
client credentials, and Home Assistant token if present; none should be generated
again for migration. Buzz's whole environment preserves its relay identity,
PostgreSQL and Redis passwords, S3 credentials and Git-hook HMAC secret.

Scope boundaries from the repository-wide audit:

- optiplex3's `synapse.nix` is **not imported**. Its Synapse, ACME and shared
  LiveKit key files are not active consumers and must not become mandatory SOPS
  keys. If enabled later, migrate those files before activating that module.
- pi4's pre-existing `/etc/wireless-secrets.conf` remains outside this server
  migration. It needs a separately verified host recipient and a network-safe
  activation plan; do not infer it is SOPS-managed by this PR.
- Application-managed state (Home Assistant storage, Paperless/Outline generated
  keys, Tailscale/tsidp state, Hermes `.env`/OAuth credential pools) remains in its
  application's private state directory and still needs secure backups.
- The legacy non-autostart Minecraft module's literal RCON password is not
  migrated; rotate it and move it out of the Nix store before starting that
  service. No production credential files were inspected during audit.

## Prepare each target before switching

1. Verify the host's Ed25519 SSH key corresponds to its `.sops.yaml` recipient,
   and that the recovery recipient `mike` is still controlled by the operator:

   ```console
   sudo nix shell nixpkgs#ssh-to-age -c sh -c 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
   ```

   Compare with the matching host in `.sops.yaml`. The optiplex3 recipient was
   derived from its live public key during the audit; actual private-key and
   recovery-key decryption still need verification. Do not regenerate host keys.

2. From this branch's checkout on the matching target, run **only** its command:

   ```console
   sudo nix shell nixpkgs#python3 nixpkgs#sops -c ./scripts/migrate-secrets optiplex1
   sudo nix shell nixpkgs#python3 nixpkgs#sops -c ./scripts/migrate-secrets optiplex2
   sudo nix shell nixpkgs#python3 nixpkgs#sops -c ./scripts/migrate-secrets optiplex3
   ```

   The script reads existing `/etc` files locally, sends JSON-encoded payloads to
   SOPS over a pipe, and writes only ciphertext. UTF-8, whitespace, CRLF and
   trailing newlines are preserved. Existing outputs and symlinks are refused;
   encryption failure publishes no file. The ciphertext is safe to commit.

3. Commit `secrets/<hostname>.yaml` and install it at the exact runtime location
   `/etc/nixos/secrets/<hostname>.yaml` on that target. If the checkout is already
   `/etc/nixos`, it is already there. The module uses a **string runtime path**,
   not a store path, and disables build-time SOPS validation. Copying a system
   closure alone does not deploy this file.

4. Verify decryption with the host's SSH private key, without printing secrets:

   ```console
   sudo nix shell nixpkgs#sops nixpkgs#ssh-to-age -c sh -c 'SOPS_AGE_KEY_CMD="ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key" sops --decrypt /etc/nixos/secrets/optiplex1.yaml > /dev/null'
   ```

   Substitute the correct host filename. Test recovery-key decryption separately.
   Keep legacy files, a known-good generation, and secure backups for rollback.
   **Before switching optiplex3, back up the GitHub App PEM outside its current
   path:** SOPS replaces that path with its managed symlink. A generation rollback
   alone does not restore the old regular file; restore the backup if needed.

5. Switch one host at a time and verify SOPS activation and affected services:
   - optiplex1: ACME, Linkwarden/worker, Mosquitto, NUT (`upsd`/`upsmon`), Restic,
     Zigbee2MQTT.
   - optiplex2: Restic. Verify access to the existing repository, not a new one.
   - optiplex3: `buzz-env`, all Buzz containers and health checks, Hermes ACP and
     dashboard, dashboard OIDC login, HA plugin access, and GitHub App API/Git
     authentication as the Hermes user.

   Never remove legacy files without a separately approved retention plan.

## Runtime permissions and editing

Most consumers use `/run/secrets/<key>`. On optiplex3, Buzz and Hermes environment
files are root-only. `buzz-env` uses systemd `LoadCredential` to stage the SOPS
symlink as a regular root-only credential file: its renderer deliberately rejects
symlink inputs. Restarting `buzz-env` propagates to its dependent container units.
The GitHub App PEM retains its original `/etc/hermes/...pem` path for CLI wrapper
compatibility, with `root:hermes` ownership and mode `0640`. SOPS owns its symlink
and permissions; tmpfiles no longer changes this key. Changes to either Hermes
secret restart both the agent and dashboard.

Use the recovery key locally to edit ciphertext:

```console
nix shell nixpkgs#sops nixpkgs#ssh-to-age -c sh -c 'SOPS_AGE_KEY_CMD="ssh-to-age -private-key -i /home/mike/.ssh/id_ed25519" sops secrets/optiplex3.yaml'
```

Install the updated ciphertext at the runtime path and reactivate the matching
configuration so SOPS materializes it and restarts consumers. Do not `sudoedit`
the decrypted files or rerun identity/credential initialization after migration.
Changing Buzz's PostgreSQL password also requires an explicit matching database
role rotation; changing its encrypted file alone cannot rotate database state.

These `age1` recipients use SSH-to-age X25519 conversion, not native age SSH
recipients; `SOPS_AGE_SSH_PRIVATE_KEY_FILE`/`CMD` is not equivalent. Never place a
private key or decrypted file in Git or the Nix store. ACME and Restic read their
current environment files on their next invocation.

## Regression checks

```console
nix shell nixpkgs#python3 nixpkgs#sops nixpkgs#age nixpkgs#openssh nixpkgs#ssh-to-age -c python3 -m unittest discover -s scripts -p test_migrate_secrets.py -v
nix eval --impure --json --file scripts/test-sops.nix
nix eval --raw .#nixosConfigurations.optiplex1.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.optiplex2.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.optiplex3.config.system.build.toplevel.drvPath
```

Tests use disposable keys and synthetic payloads for all three schemas, including
real SOPS encrypt/decrypt round trips. Nix assertions verify optiplex3 consumer
paths, systemd credential staging, ownership, permissions, and restart hooks.
They do not read production files or prove live target/recovery decryption.
