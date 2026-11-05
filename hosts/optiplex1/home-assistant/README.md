# Alarmo on the Home Assistant container

Alarmo is packaged at `pkgs/alarmo` from the pinned upstream release ZIP, including
its compiled configuration panel. The package is mounted read-only at
`/config/custom_components/alarmo`; HACS, another container, and additional ports
are not required. The optional separate Alarmo dashboard card is not installed.
Use Home Assistant's built-in alarm-panel card initially.

## Deployment and initial setup

1. Confirm a recoverable backup of `/var/lib/home-assistant`, including `.storage`.
   The host's Restic configuration includes this directory, but a configured path
   is not evidence that the latest backup succeeded.
2. Inspect `/var/lib/home-assistant/custom_components/alarmo` on `optiplex1`.
   The startup guard accepts an absent or empty directory only. It refuses a
   populated directory or a symlink at `alarmo` or `custom_components`, rather than
   silently masking an unmanaged installation. Back up and relocate an existing
   installation before deployment; do not delete it to bypass the check.
3. Deploy the reviewed NixOS configuration using the normal host deployment
   workflow. The changed volume source changes the generated Podman command and
   requires a Home Assistant container restart. This briefly interrupts all HA
   automations, not only the alarm. Do not run this during an armed security test.
4. Check `journalctl -u podman-homeAssistant.service` for startup/import errors.
5. In HA, use **Settings → Devices & Services → Add Integration → Alarmo**.
   Verify that the Alarmo sidebar configuration panel opens and an
   `alarm_control_panel` entity appears.
6. Leave the alarm disarmed. Configure and physically verify sensor mappings,
   PINs, entry/exit delays, and notification delivery as a separate commissioning
   task. This change does not assign doors, arm the alarm, or configure a siren.
7. Restart HA once more at a safe time and verify the integration and settings
   persist. Test any armed-state/restart behavior separately before relying on it.

The startup helper creates an empty mountpoint in the existing configuration
volume. That empty directory can persist after container removal; it is accepted
on subsequent starts. Other custom components are not replaced.

## Updates and rollback

Update `version` and the verified unpacked-content hash in
`pkgs/alarmo/default.nix`, build it, and re-run the checks below. Always inspect the
release archive layout and ensure `frontend/dist/alarm-panel.js` is included.
The ZIP has integration files at its root, so `stripRoot = false` is deliberate.
A release download's raw SHA-256 is not the unpacked Nix hash.

Alarmo code is immutable, while integration registration, alarm configuration,
and PIN hashes remain in HA-managed writable storage under `/config/.storage`
(including Alarmo's `alarmo.storage` key). Do not edit this storage through Nix.

A NixOS generation rollback can restore the earlier component code, but does not
reverse runtime storage migrations. Retain a pre-update configuration backup and
restore it with HA stopped if a downgrade requires the older storage format.
Do not uninstall the integration through HA merely to roll back its code.

## Local checks

From the repository root:

```sh
python3 -B hosts/optiplex1/home-assistant/test-alarmo.py
nix build --no-link --print-out-paths .#alarmo
nix build --no-link '.#nixosConfigurations.optiplex1.config.systemd.units."podman-homeAssistant.service".unit'
nix eval --raw .#nixosConfigurations.optiplex1.config.system.build.toplevel.drvPath
```

The regression tests evaluate the real module and generated Podman command, then
exercise the mountpoint guard in disposable directories. Package and unit builds
are not proof of live installation or full alarm behavior. Verify the exact HA
image's imports and complete commissioning after an authorized deployment.
