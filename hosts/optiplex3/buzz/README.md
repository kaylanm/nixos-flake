# Buzz on optiplex3

[buzz.nix](../buzz.nix) adapts Buzz's production Compose bundle into
Podman services. The relay listens at `127.0.0.1:3030`, avoiding netboot's port
3000, and advertises `https://buzz.manx-in.ts.net` / `wss://buzz.manx-in.ts.net`.
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
```

Approve the service host in the Tailscale admin console if it is not automatically
approved. Verify HTTPS and WebSocket access at `buzz.manx-in.ts.net` from a tailnet
client. Ordinary node-level `tailscale serve` would use optiplex3's own hostname.
This setup does not enable public Tailscale Funnel access.

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

The host module also patches Hermes's on-demand gateway launcher to use the
package's Python dependency environment. Using the bare interpreter allows ACP
initialization but fails on the first session with missing modules such as
`ruamel.yaml`. This fix requires rebuilding/switching the NixOS configuration;
restarting the old package alone does not pick it up.

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

