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
- Arrange off-host backups of both the `mealie` PostgreSQL database and
  `/var/lib/mealie`. No backup destination or credentials are provisioned here.
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

Back up a PostgreSQL dump of the `mealie` database together with
`/var/lib/mealie`, including uploaded recipe images and assets. With DynamicUser,
the state directory may be represented through `/var/lib/private/mealie`; run
backup tooling with appropriate privileges and verify it captures the contents,
not just a symlink. Use a quiesced snapshot or stop Mealie while taking the dump
and copying assets for a consistent pair. Store backups off this root disk and
test restoration into a disposable instance before relying on them.

A NixOS generation rollback does not reverse database migrations. Before an
upgrade, retain a matching database/state backup; use that backup if downgrading
requires it. Removing the module stops the service but is not a request to delete
its database or persistent state. Withdraw `svc:mealie` separately if rolling back
the published endpoint.

## Configuration regression check

From the repository root:

```sh
nix eval --impure --json --file hosts/optiplex3/mealie/test-config.nix
```

This checks host scope, loopback binding, firewall policy, PostgreSQL provisioning,
state ownership configuration, authentication defaults and NixOS assertions.
It is an evaluation check, not a runtime or backup-restore test.
