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

