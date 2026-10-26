# Buzz on optiplex3

[buzz.nix](../buzz.nix) adapts Buzz's production Compose bundle into
Podman services. The relay listens at `127.0.0.1:3030`, avoiding netboot's port
3000, and advertises `https://buzz.manx-in.ts.net` / `wss://buzz.manx-in.ts.net`.
The stateless device-pairing relay listens at `127.0.0.1:3031` and is advertised
as `wss://buzz.manx-in.ts.net/pair` for mobile QR pairing.
PostgreSQL, Redis, Silo (the MinIO-compatible object store), and their health and
metrics ports stay on the private `buzz` network. All five images are pinned by
digest; Renovate can discover their `image` assignments.

## Credentials and first start

The owner's public key is configured as `services.buzz.ownerPublicKey` in
[configuration.nix](../configuration.nix), decoded from
`npub10pn4w5qhvr5vu3crkr44sdc2far2jw0ljle8uqs9lzrrzeqvacqskzky6a`.
The runtime secrets input is `/etc/buzz/secrets.env`; it must be a
root-owned regular file with mode `0600` or `0400`. Keep it outside this checkout.

Before the first NixOS switch, initialize it on optiplex3 from the repository root
(with Python 3 available):

```sh
sudo python3 hosts/optiplex3/buzz/render-env.py --init /etc/buzz/secrets.env
```

Initialization creates and validates six independent random
secrets, and refuses to overwrite an existing file. It never prints credentials.
The configured system also installs `sudo buzz-init-secrets`
for this purpose. If configuration is activated before provisioning, Buzz's
environment service fails and its containers cannot start; initialize the file
and then restart the target.

The file uses plain `KEY=value` lines, with optional blank lines and `#` comments.
Quotes, shell substitutions, and variable interpolation are deliberately rejected.

| Input | Format | Consumers |
| --- | --- | --- |
| `BUZZ_RELAY_PRIVATE_KEY` | 64 hex characters, valid secp256k1 private key | Relay |
| `BUZZ_GIT_HOOK_HMAC_SECRET` | 64 hex characters | Relay |
| `POSTGRES_PASSWORD` | 64 hex characters | PostgreSQL; relay database URL |
| `REDIS_PASSWORD` | 64 hex characters | Redis; relay Redis URL |
| `BUZZ_S3_ACCESS_KEY` | 20–64 hex characters | Silo, bucket initializer, relay |
| `BUZZ_S3_SECRET_KEY` | 64 hex characters | Silo, bucket initializer, relay |

`buzz-env.service` extracts five service-specific files into root-only `/run/buzz`
with mode `0600`. It renders complete database/Redis URLs and translates the S3
credentials into `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` for Silo. Hexadecimal
passwords avoid URL-encoding and environment-file quoting problems. Redis expands
its password inside the container, keeping the value out of generated Nix and
systemd scripts. As with other environment-based container credentials, root and
container inspection can still access the values.

Public URLs, authentication policy, the `buzz-media` bucket, and migration settings
are explicit in Nix. Token authentication, relay membership, and NIP-OA auth are
enabled. Push and the optional admin dashboard are disabled. Database migrations
run automatically, and the git storage conformance probe remains enabled.

After activating the optiplex3 configuration:

```sh
sudo systemctl restart buzz.target
sudo systemctl status buzz.target podman-buzz-relay.service
sudo journalctl -u buzz-env -u buzz-minio-init -u podman-buzz-relay
sudo podman healthcheck run buzz-relay
```

Podman reports each supporting service ready only after its health check passes.
The relay also waits for `buzz-minio-init.service` to finish creating the private
bucket successfully. Startup has bounded timeouts, and unhealthy containers are
killed and restarted. `sudo systemctl stop buzz.target` stops the stack without
deleting its network or persistent volumes.

## HTTPS and tailnet routing

The hostname setting supplies advertised URLs; it does not create DNS or TLS.
Configure [Tailscale Services](https://tailscale.com/docs/features/tailscale-services)
with a `buzz` service on port 443, an authorized tagged optiplex3 service host,
and the appropriate tailnet access policy. On optiplex3, publish its backend:

```sh
sudo tailscale serve --service=svc:buzz --https=443 http://127.0.0.1:3030
sudo tailscale serve --service=svc:buzz --https=443 --set-path=/pair http://127.0.0.1:3031
```

Approve the service host in the Tailscale admin console if it is not automatically
approved. Verify HTTPS and WebSocket access at `buzz.manx-in.ts.net` from a tailnet
client. Ordinary node-level `tailscale serve` would use optiplex3's own hostname.
This setup does not enable public Tailscale Funnel access.

Both routes are required: `/` serves the authenticated community relay, and
`/pair` serves the separate pairing relay from the same pinned image. Pairing
identities are temporary and do not have community membership, so routing
pairing to the main relay cannot replace the sidecar. The pairing relay has no
credentials, database, or persistent volumes; it forwards signed encrypted
pairing events between connected devices. The phone must also have tailnet
access to this hostname.

After rebuilding an existing deployment to add pairing, start the new service
and add the `/pair` Tailscale route above. Verify:

```sh
sudo systemctl start podman-buzz-pairing.service
sudo podman healthcheck run buzz-pairing
curl -fsS -H 'Accept: application/nostr+json' https://buzz.manx-in.ts.net/
```

The discovery document should contain
`"pairing_relay_url":"wss://buzz.manx-in.ts.net/pair"`. A plain HTTP request
to `/pair` returns 400 because it requires a WebSocket upgrade; 404 indicates
the path is still routed to the main relay. Reopen the Desktop mobile-pairing
dialog after the new route is active. Complete the QR and verification flow on
both devices to confirm pairing end to end.

## Operations and backups

After a deliberate edit to `/etc/buzz/secrets.env`, restart `buzz.target` to
regenerate runtime files and recreate the containers. Do not regenerate secrets
on boot. Changing `POSTGRES_PASSWORD` in this file does not change the password
inside an already initialized PostgreSQL database; rotate that database role
explicitly in the same maintenance window. Back up the credentials securely.

Persistent Podman volumes are `buzz-postgres-data`, `buzz-redis-data`,
`buzz-minio-data`, and `buzz-git-data`. Take a database dump or quiesced backup,
and preserve object/git state from the same maintenance window before upgrades.
Keep the owner's client private key backed up separately; it is never supplied
to the server. Update the paired Silo and `mc` image pins together.

From the repository root, credential extraction tests run without a container engine or real secrets:

```sh
python3 -B -m unittest discover -s hosts/optiplex3/buzz -v
```

## Hermes agent

[hermes.nix](../hermes.nix) enables `hermes.service` on optiplex3. It runs
`buzz-acp` with `hermes-acp` and `buzz-dev-mcp`, connecting through
`wss://buzz.manx-in.ts.net`. The Buzz tools are built from the same pinned source
revision as the relay. No additional listening port is opened.

The dedicated `hermes` user keeps its home at `/var/lib/hermes`, Hermes state at
`/var/lib/hermes/.hermes`, and working files at `/var/lib/hermes/workspace`.
The service has no sudo access, cannot access users' home directories, and sees
the system filesystem read-only. Its persistent state directory remains writable.
Only messages from the configured relay owner trigger the agent, with the usual
Buzz mention and channel-membership filters. There is one worker and no heartbeat.
An intentional clean exit (including Buzz's owner-authorized shutdown) is not
automatically restarted; failures retry after 15 seconds.

### First start

Provision a **separate agent identity** and its owner-signed NIP-OA authorization
for this relay. Use the agent's key, never the owner's or relay's private key.
The owner attestation must authorize this agent key and be accepted by the
relay's membership and token policies. This service uses the relay's enabled
NIP-OA authentication path. Ensure the agent is a member of the intended test
channel. Do not run another harness with the same identity at the same time
(for example, a local agent in Buzz Desktop).

The installed `buzz-provision-hermes` helper creates the separate agent identity
and its owner attestation. On optiplex3, provision a **new** identity with:

```sh
sudo install -d -m 0700 -o root -g root /etc/hermes
sudo buzz-provision-hermes --output /etc/hermes/secrets.env
```

Enter the owner's private key (nsec or hex) at the hidden prompt. The helper
checks it against the configured relay owner, generates a fresh agent key, and
writes only the agent key and owner-signed authorization to a new mode-0600 file.
It prints the agent's public key for invitations and registration; it never saves
the owner's private key. Existing output files and symlinks are refused, so do
not rerun this to update a working identity. This is an interactive setup command;
the service never runs it automatically.

Without `--output`, the helper creates `hermes-secrets.env` in the current
directory. Keep generated credentials outside the checkout. To add provider
credentials or use credentials provisioned elsewhere, edit the file with
`sudoedit /etc/hermes/secrets.env`, using systemd environment-file syntax:

```ini
BUZZ_PRIVATE_KEY=nsec1_REPLACE_WITH_AGENT_KEY
BUZZ_AUTH_TAG='["auth","OWNER_HEX","CONDITIONS","OWNER_SIGNATURE_HEX"]'
# Optional model-provider credential, using that provider's environment variable:
# OPENROUTER_API_KEY=REPLACE_WITH_PROVIDER_KEY
```

The auth tag is a signed credential, not a template to fill by hand. The
provisioning helper generates it using the owner's signature. The single quotes above
preserve the JSON's double quotes. Environment files do not expand shell variables
or substitutions. The service fails visibly if its credentials file is missing.
The same file can also supply optional harness settings, such as
`BUZZ_ACP_CHANNELS` (comma-separated channel UUIDs).

### Profile and mention registration

Channel membership alone does not make an external agent mentionable in Desktop.
Desktop also needs the agent's signed kind:0 profile with its NIP-OA owner
attestation, and an owner-signed kind:30177 policy naming the agent. The harness's
`BUZZ_ACP_DISPLAY_NAME` setting does not publish either record.

Publish the profile on optiplex3 using the service's agent credentials:

```sh
sudo systemd-run --quiet --wait --pipe --collect \
  --uid=hermes --gid=hermes \
  --property=EnvironmentFile=/etc/hermes/secrets.env \
  /run/current-system/sw/bin/buzz \
  --relay https://buzz.manx-in.ts.net \
  users set-profile --name Hermes --about "Hermes agent on optiplex3"
```

After activating this configuration, register the policy from an interactive
terminal on optiplex3 (no sudo required):

```sh
buzz-register-hermes \
  --agent df6c360ff6404257aae1439e974c183f6c499f15be28d98446ff6c123a45bfb3
```

This public key identifies the provisioned Hermes identity; replace it if the
agent identity changes. Enter the **owner's** private key at the hidden prompt.
The helper never saves it or passes it as a process argument. It verifies the key
against the configured owner, checks the agent profile's signature and owner
attestation, then publishes and reads back the owner-only policy. It creates no
new identity and starts no agent process. Registration persists across restarts;
an identical existing policy is a no-op, and a different policy is preserved
with an error. Keep the owner's key out of `/etc/hermes/secrets.env`.

Reopen Buzz Desktop and select Hermes from the `@Hermes` autocomplete in a
channel where it has bot membership, while signed in as the owner. Other users
remain excluded by the owner-only policy.

The helper implementation is [register-agent.py](../hermes/register-agent.py).
Its tests use disposable keys and a local HTTP relay fixture to check signing,
registration readback, repeat runs, and rejection of forged profiles or existing
conflicting policies. Run with Python including `bech32` and `coincurve`:

```sh
python3 -B hosts/optiplex3/hermes/test-register-agent.py -v
python3 -B hosts/optiplex3/hermes/test-provision-identity.py -v
```

### Model setup and service startup

After switching to the new optiplex3 configuration, stop the service while setting
up Hermes and select the provider/model as its service user:

```sh
sudo systemctl stop hermes.service
sudo -u hermes -H hermes model
sudo systemctl restart hermes.service
sudo systemctl status hermes.service
sudo journalctl -u hermes.service -f
```

The interactive model selector runs outside the service environment: it will not
inherit `/etc/hermes/secrets.env`. Provider credentials saved by Hermes under its
own home are also supported. Keep that state private and back it up securely.
The service explicitly supplies session MCP tools and skips unrelated
profile-configured MCP startup.

The upstream Nix package patches Hermes's on-demand gateway launcher to use its
Python dependency environment. Using the bare interpreter allows ACP
initialization but fails on the first session with missing modules such as
`ruamel.yaml`. This fix requires rebuilding/switching the NixOS configuration;
restarting the old package alone does not pick it up.

### Web dashboard

The host also enables `hermes-dashboard.service` at boot. It runs as the same
`hermes` user, shares `/var/lib/hermes/.hermes` and `/etc/hermes/secrets.env`
with the Buzz agent, and uses the frontend bundled in the Nix package.

After switching the optiplex3 configuration, check the service:

```sh
sudo systemctl status hermes-dashboard.service
sudo journalctl -u hermes-dashboard.service -f
```

The public URL is <https://hermes.manx-in.ts.net>, with a backend listening on
`127.0.0.1:9119`. Setting this URL enables Hermes's authentication gate, including
on the local listener. Authentication uses the bundled self-hosted OIDC provider
with the tsidp prototype described below. Without a configured provider, the
dashboard refuses to start.

As with Buzz, the public URL setting does not create DNS or TLS. Configure a
[Tailscale Service](https://tailscale.com/docs/features/tailscale-services) named
`hermes` with TCP port 443 and authorize optiplex3 to host it. On optiplex3, run:

```sh
sudo tailscale serve --service=svc:hermes --https=443 http://127.0.0.1:9119
sudo systemctl restart hermes-dashboard.service
```

Tailscale supplies the service hostname and HTTPS certificate. Tailnet access
policy controls who can reach it; the dashboard additionally requires login.

### Tailscale OIDC prototype (tsidp)

The host's [tsidp.nix](../tsidp.nix) enables the pinned Nixpkgs `tsidp` package
as `tsidp.service`. It creates a separate tsnet node named `idp`, serving
<https://idp.manx-in.ts.net> directly
over the tailnet. It does not need another Serve route or a host firewall port.
Funnel, token exchange (STS), and the optional localhost listener are disabled.
State, including the node identity, signing key, and registered clients, lives
under `/var/lib/tsidp` (managed by systemd's dynamic-user state directory).
Back it up with `/etc/hermes/secrets.env`; do not delete it between restarts.

This prototype uses the upstream [tsidp](https://github.com/tailscale/tsidp)
client-registration flow and Hermes's
[self-hosted OIDC provider](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard#self-hosted-oidc-provider).
tsidp is experimental. Enrollment and tailnet policy are manual steps:

1. Switch to this host configuration, then follow the enrollment URL printed by
   `sudo journalctl -u tsidp.service -f`. Enroll it in `manx-in.ts.net` and assign
   `tag:tsidp` in the Tailscale admin console. If `idp` is already taken, resolve
   the name conflict or update both the node hostname and Hermes's issuer URL.
   Ensure MagicDNS and HTTPS certificates are enabled for the tailnet.

2. Add `tag:tsidp` to your tailnet policy's `tagOwners`, with an appropriate owner
   such as `autogroup:admin`. Grant only your intended users TCP 443 access to
   the IdP and the `svc:hermes` service. Also allow optiplex3 to reach the IdP's
   TCP 443 for OIDC discovery, JWKS, and token requests. Broad existing allow
   rules must be narrowed too: Tailscale grants are additive. Any user who can
   authenticate at the IdP and reach this dashboard can manage Hermes; this
   prototype does not add a separate Hermes user allowlist.

3. To allow your own user to register the Hermes client, merge this application
   capability grant into the policy's existing `grants` list, replacing the
   example login with your actual Tailscale login:

   ```json
   {
     "src": ["YOUR_TAILSCALE_LOGIN"],
     "dst": ["tag:tsidp"],
     "app": {
       "tailscale.com/cap/tsidp": [{"allow_admin_ui": true}]
     }
   }
   ```

   This grants admin UI access, in addition to the network access from step 2.
   Dynamic client registration and STS capability grants are unnecessary.

4. From a user-owned Tailscale device, visit <https://idp.manx-in.ts.net> and
   select **Add New Client**. Name it `Hermes` and register exactly this redirect:

   ```text
   https://hermes.manx-in.ts.net/auth/callback
   ```

   Save the generated client ID and secret. The pinned tsidp requires client
   authentication, and Hermes 0.22.5 supports it together with PKCE S256.

5. On optiplex3, use `sudoedit /etc/hermes/secrets.env` to add:

   ```ini
   HERMES_DASHBOARD_OIDC_CLIENT_ID="<generated client ID>"
   HERMES_DASHBOARD_OIDC_CLIENT_SECRET="<generated client secret>"
   ```

   Replace the placeholders with the actual values. Keep the existing Buzz and
   model credentials. Remove any `HERMES_DASHBOARD_BASIC_AUTH_*` and Nous
   `HERMES_DASHBOARD_OAUTH_CLIENT_ID` entries (including from Hermes's own `.env`
   or equivalent basic/Nous settings in `config.yaml`) to remove other login
   methods. Keep `/etc/hermes/secrets.env` owned by root with mode `0600`.
   Nix supplies the issuer `https://idp.manx-in.ts.net` and the scopes
   `openid profile email`; no credentials are written into the Nix store.

6. Restart `hermes-dashboard.service` and visit
   <https://hermes.manx-in.ts.net>. Choose **Sign in with Self-Hosted OIDC**.
   The browser is redirected to tsidp, which identifies your Tailscale user and
   returns you to Hermes. A tagged client device has no user identity and cannot
   complete this login; the optiplex3 backend itself can be tagged.

For validation, check discovery from optiplex3:

```sh
curl --fail https://idp.manx-in.ts.net/.well-known/openid-configuration
curl --fail http://127.0.0.1:9119/api/status
sudo journalctl -u tsidp.service -u hermes-dashboard.service -n 80 --no-pager
```

The dashboard status should report `auth_required: true` and include
`self-hosted` in `auth_providers`. Confirm browser login and chat, then restart
both services and log in again to verify state persistence. Try a device whose
user is excluded by your access policy and confirm access is denied. A Nix build
validates the units and packages but does not enroll the node, change tailnet
policy, register the client, or validate the live browser flow.

### Home Assistant plugin

The host pins the official `homeassistant` plugin source in `hermes.nix`;
Renovate tracks the upstream `main` branch and refreshes its commit and source
hash through the repository's GitHub Actions workflow. The initial pin came
from Hermes's plugin catalog. `hermes-plugins.service` runs before
the agent and dashboard, links it into
`/var/lib/hermes/.hermes/plugins/homeassistant`, and enables it in `config.yaml`.
The setup preserves other plugin selections, model settings, comments, and
platform toolsets. The Nix Hermes package already includes its `aiohttp`
dependency. No runtime PM install is needed: `hermes plugins install` fails
with this package because its install metadata does not supply a PM runtime.

If a manually installed `plugins/homeassistant` directory already exists, setup
refuses to replace it. Move that directory aside as a backup and restart
`hermes-plugins.service`, followed by the agent and dashboard. Nix-managed
symlinks are updated automatically when the plugin pin changes.

Add the actual Home Assistant endpoint and a dedicated user's long-lived token
to `/etc/hermes/secrets.env` using `sudoedit`:

```ini
HASS_URL="https://YOUR_HOME_ASSISTANT_HOST"
HASS_TOKEN="YOUR_LONG_LIVED_TOKEN"
```

Keep the file owned by root with mode `0600`. Both services inherit it. Ensure
optiplex3 can reach the configured endpoint on optiplex1, including through any
Tailscale access policy. Optional `HASS_ENTITY_ALLOWLIST` and
`HASS_ENTITY_DENYLIST` variables constrain which entities the plugin's tools
can access. Configure the actual entity IDs you intend Hermes to use.

After switching the updated configuration, restart the consumers to pick up
credentials, then check plugin registration:

```sh
sudo systemctl restart hermes.service hermes-dashboard.service
sudo systemctl status hermes-plugins.service --no-pager
sudo -u hermes -H hermes plugins list
```

The four tools are `ha_list_entities`, `ha_get_state`, `ha_list_services`, and
`ha_call_service`. They are available to CLI/dashboard and ACP sessions when
the plugin is enabled and `HASS_TOKEN` is set; explicit toolset suppression in
the existing profile still applies. Start a new chat and first ask Hermes to
read an entity state. State-change event subscriptions require separate
`platforms.homeassistant.extra.watch_entities` / `watch_domains` configuration;
this setup does not opt into watching all events.

The config migration regression checks can be run with a Python environment
containing `ruamel.yaml`:

```sh
python3 -B hosts/optiplex3/hermes/test-setup-homeassistant.py -v
```

### Live agent validation

From the owner's Buzz client, @mention Hermes in its test channel. Confirm a reply
in the expected thread and ask it to create and read a file in its workspace.
Restart the service and confirm the same agent identity reconnects. This live
check requires real credentials and model access; a Nix build alone cannot
verify it. If it connects but ignores messages, check channel membership, the
mention, and that the sender is the configured owner.

For package validation without activating the system:

```sh
nix build --impure --no-link --expr \
  'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.optiplex3.pkgs.buzz-agent-tools'
nix build .#nixosConfigurations.optiplex3.config.system.build.toplevel --no-link
```

Ensure new files are included in the flake source when building from a Git
checkout. Upgrades are managed through Nix; do not run `hermes update` against
the immutable package. Back up `/etc/hermes/secrets.env` and `/var/lib/hermes`.

To exercise the on-demand gateway path without real credentials or an inference
request, run the regression check against the Hermes package used by this host:

```sh
hermes_package=$(nix build --impure --no-link --print-out-paths --expr \
  'let c = (builtins.getFlake (toString ./.)).nixosConfigurations.optiplex3.config; in builtins.head (builtins.filter (p: (p.pname or "") == "hermes-agent") c.environment.systemPackages)')
python3 hosts/optiplex3/hermes/test-gateway-session.py "$hermes_package"
```

The check uses a temporary home and dummy local provider, starts a gateway,
creates an ACP session, and stops that isolated gateway on exit.

