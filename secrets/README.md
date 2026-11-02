# Encrypted host secrets

This branch migrates **optiplex1 and optiplex2 only**. It is not ready to deploy
until their encrypted payload files have been generated and decryption verified
on the actual targets. No production secrets are included in the repository yet.
A successful Nix evaluation does **not** verify that activation can decrypt them.

## Prepare each target before switching

1. Verify that the host's Ed25519 SSH key corresponds to its recipient in
   `.sops.yaml`, and that the recovery recipient named `mike` is still controlled
   by the operator. For example, on optiplex1:

   ```console
   sudo nix shell nixpkgs#ssh-to-age -c sh -c 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
   ```

   Compare the public result with `optiplex1` in `.sops.yaml`. Do not regenerate
   host SSH keys during migration. Verify the recovery recipient independently.

2. From this branch's checkout on the matching target, run **only** its command:

   ```console
   sudo nix shell nixpkgs#python3 nixpkgs#sops -c ./scripts/migrate-secrets optiplex1
   sudo nix shell nixpkgs#python3 nixpkgs#sops -c ./scripts/migrate-secrets optiplex2
   ```

   The script reads the existing `/etc` files locally. It sends JSON-encoded file
   payloads to SOPS over a pipe; plaintext is never written to a temporary file.
   UTF-8 contents, whitespace, CRLF, and trailing newlines are preserved. It
   refuses to overwrite an existing output, including symlinks, and publishes no
   file if encryption fails. The resulting ciphertext is safe to commit.

3. Commit `secrets/<hostname>.yaml`. Install it at the exact runtime location
   `/etc/nixos/secrets/<hostname>.yaml` on that target (if the checkout is already
   `/etc/nixos`, it is already there). The Nix module uses a **string runtime
   path**, not a store path, and deliberately disables build-time SOPS validation.
   Copying a system closure alone does not deploy this file.

4. Verify decryption using that host's SSH private key, without printing secrets:

   ```console
   sudo nix shell nixpkgs#sops nixpkgs#ssh-to-age -c sh -c 'SOPS_AGE_KEY_CMD="ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key" sops --decrypt /etc/nixos/secrets/optiplex1.yaml > /dev/null'
   ```

   Substitute optiplex2 on that host. Test recovery-key decryption separately.
   Keep the old `/etc` secret files and a known-good generation for rollback.

5. Switch one host at a time; verify SOPS activation and the affected services.
   On optiplex1 check ACME, Linkwarden and its worker, Mosquitto, NUT
   (`upsd`/`upsmon`), Restic, and Zigbee2MQTT. On optiplex2 check Restic. Verify
   a backup can access its existing repository; do not initialize a new one.
   Remove legacy files only after a separately approved retention/rollback plan.

## Editing

Use the matching private SSH key for the recovery recipient locally:

```console
nix shell nixpkgs#sops nixpkgs#ssh-to-age -c sh -c 'SOPS_AGE_KEY_CMD="ssh-to-age -private-key -i /home/mike/.ssh/id_ed25519" sops secrets/optiplex1.yaml'
```

These `age1` recipients use SSH-to-age X25519 conversion, not native age SSH
recipients; `SOPS_AGE_SSH_PRIVATE_KEY_FILE`/`CMD` is not the correct identity
mechanism for them.

Never put a private key or decrypted file in the repository or Nix store. YAML
keys represent complete file payloads, not individual environment variables.
The ACME and Restic environment-file formats and nested Zigbee2MQTT YAML remain
unchanged. Services read runtime paths under `/run/secrets`; long-running
consumers that need it have secret-change restart hooks. ACME and Restic read
updated secrets on their next invocation.

## Regression checks

```console
nix shell nixpkgs#python3 nixpkgs#sops nixpkgs#age nixpkgs#openssh nixpkgs#ssh-to-age -c python3 -m unittest discover -s scripts -p test_migrate_secrets.py -v
nix eval --raw .#nixosConfigurations.optiplex1.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.optiplex2.config.system.build.toplevel.drvPath
```

Tests generate disposable age keys and synthetic payloads for both hosts, then
perform real SOPS encrypt/decrypt round trips. They do not access production
secret files or prove the recipients in `.sops.yaml` match live host keys.
