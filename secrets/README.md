# Encrypted host secrets

`optiplex1.yaml` and `optiplex2.yaml` are SOPS-encrypted YAML files. They are
intentionally absent until the existing files have been migrated on each host.

From an up-to-date `/etc/nixos` checkout on each target, run:

```console
sudo nix shell nixpkgs#sops -c ./scripts/migrate-secrets optiplex1
sudo nix shell nixpkgs#sops -c ./scripts/migrate-secrets optiplex2
```

Run only the command matching that host. The script reads the existing root-only
files locally, encrypts their complete contents, and creates
`secrets/<hostname>.yaml`. Commit the encrypted file before rebuilding.

To inspect or edit one of the files locally using the SSH key whose public key
is listed as `mike` in `.sops.yaml`, run:

```console
SOPS_AGE_SSH_PRIVATE_KEY_CMD='cat /home/mike/.ssh/id_ed25519' sops secrets/optiplex1.yaml
```

Substitute the other hostname as needed. SOPS receives the private key through
the command's standard output; it is not placed in the repository or Nix store.

The encrypted YAML keys are file payloads, not individual environment variables.
This preserves the existing ACME and Restic environment-file formats and the
Zigbee2MQTT secrets YAML without exposing their contents to Nix evaluation.
