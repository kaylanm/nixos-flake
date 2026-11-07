# Mealie on optiplex3

Native nixpkgs Mealie service, using the host's PostgreSQL server. The NixOS
module provisions a dedicated `mealie` database/user with Unix-socket peer
authentication, a dynamic service user, and persistent `/var/lib/mealie` state.
The backend listens only on `127.0.0.1:9000`; no firewall port is opened.

## Before deployment

- Free disk space. During assessment the root filesystem was 97% full, with
  approximately 8 GiB available. Builds, upgrades, images and backups need room.
- Review the pinned Mealie version before merging. At drafting time nixpkgs
  supplies 3.29.0, while upstream 3.30.0 includes security-relevant fixes. This
  change intentionally does not update the shared flake lock or override Mealie.
- Provision the off-host Restic repository and runtime credential files described
  below. The backup timer is configured here, but no destination or secrets are
  provisioned; a missing file produces a failed backup unit, not a silent skip.
- Do not merge until ready for activation: the host has automatic NixOS upgrades.
  A draft PR alone does not deploy this configuration.

## Activation and private HTTPS

Activation is a separate operator action; creating this PR does not rebuild or
switch the host. Tailscale Service registration is also separate, consistent
with existing applications on this host.

1. After reviewing the prerequisites, activate the host configuration through
   the normal deployment workflow.
2. Before publishing access, bootstrap the administrator account through a
   trusted local connection or SSH tunnel:

   ```sh
   ssh -N -L 9000:127.0.0.1:9000 mike@optiplex3
   ```

   Open `http://localhost:9000`, follow Mealie's first-login instructions, and
   immediately replace the default administrator password. Keep the service
   unpublished until this is complete. Signup is disabled; provision additional
   local accounts explicitly as administrator.
3. Create/authorize the Tailscale Service `svc:mealie` in the tailnet admin
   console, restricting access to the intended household users. On optiplex3:

   ```sh
   sudo tailscale serve --service=svc:mealie --https=443 http://127.0.0.1:9000
   ```

   Verify host approval/advertisement as required by the tailnet policy. Do not
   enable Funnel. The intended URL is `https://mealie.manx-in.ts.net`.
4. Verify:

   ```sh
   systemctl status mealie
   curl --fail http://127.0.0.1:9000/api/app/about
   tailscale serve status
   ```

   From an authorized tailnet device, verify HTTPS, administrator login, recipe
   creation/import, uploads, and persistence after a Mealie service restart.
   Verify unauthorized devices cannot reach the service.

## Authentication

This initial configuration deliberately uses Mealie's local authentication.
Tailscale restricts network reachability; it does not replace application login.

For a later tsidp integration, register a confidential OIDC client with callback
`https://mealie.manx-in.ts.net/login` and the documented logout callback if
needed. Inspect actual issued claims first: Mealie requires `email_verified=true`
by default, and the deployed tsidp discovery document does not advertise it.
Only consider disabling that requirement after checking the trustworthiness of
the provider's email identity. Check the name claim mapping as well.

Keep client secrets in a runtime file via `services.mealie.credentialsFile`,
never in Nix settings or the Nix store. Control `OIDC_SIGNUP_ENABLED` separately
from `ALLOW_SIGNUP`; retain an administrator recovery path until SSO is tested.

## Backups and rollback

The daily `restic-backups-mealie.service` job runs at 03:30 local time plus up to
30 minutes of randomized delay, with persistent catch-up. It:

1. Validates repository access before stopping Mealie.
2. Stops Mealie, creates a custom-format PostgreSQL dump and archives the contents
   of the physical `/var/lib/private/mealie` directory, not its public symlink.
3. Starts Mealie before uploading the consistent pair to Restic.
4. Runs a repository metadata check after backup. This is not a full data scrub.
5. Removes local staging after success or failure. `ExecStopPost` also attempts to
   restart Mealie after preparation failure/timeout if the recovery marker exists.
   A failed recovery leaves the marker and staged files for operator inspection.

The unit is root-owned with `0700` staging at `/var/lib/mealie-backup`; dumps and
assets may contain credentials. Budget **one uncompressed copy of Mealie's state
plus a database dump**, Restic cache, and operational headroom on the root disk.
An archive/dump failure fails the backup and triggers service recovery; it must
not be interpreted as a successful snapshot. The whole job has a two-hour limit.
Mealie is unavailable during the local dump/archive, not during remote upload.
There is no automatic pruning: approve a retention policy appropriate for the
chosen repository before enabling deletion, and monitor repository growth.

### Repository provisioning and first backup

Use the existing host convention, with root-owned `0600` runtime files:

- `/etc/restic-repository`: the selected **off-host** Restic repository URL.
- `/etc/restic-password`: the encryption password, escrowed separately for recovery.
- `/etc/restic-env`: backend environment credentials in systemd EnvironmentFile
  syntax; provision an empty file if the backend needs none. For the generated
  shell wrapper, use entries compatible with shell assignments too.

Never commit these files or place secrets in Nix settings. Restrict backend
credentials to the intended repository. Initialize the chosen repository
explicitly, outside this PR; `initialize = false` avoids creating a repository
at an accidentally configured location. No destination has been selected or
contacted by drafting this configuration.

After authorized activation and credential provisioning:

```sh
sudo restic-mealie cat config
sudo systemctl start restic-backups-mealie.service
sudo journalctl -u restic-backups-mealie.service
sudo restic-mealie snapshots --host optiplex3 --tag mealie
systemctl list-timers restic-backups-mealie.timer
```

Missing credentials, unreachable repositories, inactive Mealie, failed dumps,
failed uploads and failed recovery all produce failed units. Monitor the unit,
its journal and the age of the last successful snapshot; off-host alert delivery
is not configured by this PR. If recovery fails, inspect the journal and
`/var/lib/mealie-backup/restart-mealie`, repair the underlying cause, and restart
Mealie manually before clearing the marker. A machine crash can interrupt the
process; normal boot starts Mealie through its own wantedBy dependency.

### Restore rehearsal

Use an isolated instance with the matching Mealie version, **never the production
database as a rehearsal target**. Select an explicit snapshot ID from the filtered
snapshot listing, then as root:

```sh
sudo restic-mealie check --read-data
sudo restic-mealie restore SNAPSHOT_ID --target /path/on/recovery-disk
```

The recovered pair is under
`/path/on/recovery-disk/var/lib/mealie-backup/snapshot/`:

- `database.dump`: restore with `pg_restore --exit-on-error --no-owner --no-acl`
  into a fresh disposable database. In a NixOS Mealie instance, restore as the
  dedicated `mealie` role (or use a superuser with `--role=mealie`) so the service
  owns its tables. Do not restore a raw PostgreSQL data directory.
- `assets.tar`: extract only into an empty recovery directory first and inspect
  it. Stop the disposable Mealie instance, install those contents into its real
  persistent state directory, and set ownership to that instance's state owner;
  do not assume a saved DynamicUser numeric UID is reusable.

Keep the disposable service stopped while restoring both parts, start it only
after the pair is in place, and verify login, recipes, images, uploads and restart
persistence. Save the tested snapshot ID and date in operations records. The
included isolated integration test verifies PostgreSQL dump/restore and a real
Restic archive round-trip using test data; it does not prove a production Mealie
restore or access to the future off-host repository.


A NixOS generation rollback does not reverse database migrations. Before an
upgrade, retain a matching database/state backup; use that backup if downgrading
requires it. Removing the module stops the service but is not a request to delete
its database or persistent state. Withdraw `svc:mealie` separately if rolling back
the published endpoint.

## Configuration regression check

From the repository root:

```sh
nix eval --impure --json --file hosts/optiplex3/mealie/test-config.nix
nix eval --impure --json --file hosts/optiplex3/mealie/test-backup-config.nix
python3 hosts/optiplex3/mealie/test-backup-hooks.py -v
# Include the PostgreSQL + Restic round-trip (requires PostgreSQL tools on PATH):
RESTIC_BIN="$(command -v restic)" python3 hosts/optiplex3/mealie/test-backup-hooks.py -v
```

This checks host scope, loopback binding, firewall policy, PostgreSQL provisioning,
state ownership configuration, authentication defaults and NixOS assertions.
It is an evaluation check, not a runtime or backup-restore test.
