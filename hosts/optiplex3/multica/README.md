# Multica prototype on optiplex3 (disabled)

[../multica.nix](../multica.nix) is imported by the host but explicitly disabled.
Merging this change creates **no Multica containers, credentials, nginx listener,
Serve route, or daemon**. Enabling is a separate operator decision and host edit.
No live NixOS activation, root container startup or Tailscale configuration was
performed while developing this prototype.

## Package audit and Compose mapping

The locked `llm-agents` input packages Multica **0.6.1**, building only the Go
`server/cmd/multica` CLI. It does not package the web frontend, backend server,
migration runner, database or a NixOS service. `multica version` and `--help`
were exercised. Installing `llm-agents#multica` is not a self-host deployment.
The package disables its Go unit suite (`doCheck=false`) and enables only an
installation version check. Its upstream license is marked unfree in the input.
The CLI can later authenticate against this deployment and run a separate agent
runtime; the web/API stack alone does not execute an agent on this host.

Audit source: [multica-ai/multica v0.6.1, commit
2ea01ae4ef55de4310b99af192d2dbd367832883](https://github.com/multica-ai/multica/tree/2ea01ae4ef55de4310b99af192d2dbd367832883).
The root `docker-compose.yml` is development PostgreSQL only. The relevant bundle
is [`docker-compose.selfhost.yml`](https://github.com/multica-ai/multica/blob/2ea01ae4ef55de4310b99af192d2dbd367832883/docker-compose.selfhost.yml).

| Upstream component/setting | Prototype mapping |
| --- | --- |
| `pgvector/pgvector:pg17` | Separate `multica-postgres` Podman container; no published DB port |
| `pgdata` | Persistent `multica-postgres-data` named volume |
| Backend image | `ghcr.io/multica-ai/multica-backend:v0.6.1`, immutable digest |
| Backend entrypoint | Unchanged: migrations run before server; no embedded migration replacement |
| `backend_uploads` | Persistent `multica-uploads`, mounted at `/app/data/uploads` |
| Frontend image | `ghcr.io/multica-ai/multica-web:v0.6.1`, immutable digest |
| Frontend runtime API upstream | `REMOTE_API_URL=http://backend:8080`, not a build-time localhost URL |
| PostgreSQL health dependency | Podman healthy sdnotify; backend requires/starts after database |
| Backend readiness | `/readyz` (`/healthz` alias) tests DB and migrations; frontend starts after healthy backend |
| Host ports 3000/8080 | Loopback 3100/8180; existing default ports are occupied |
| Private service discovery | Dedicated Podman bridge `multica` / interface `multica0`, aliases postgres/backend/frontend |
| Public URL | Candidate `https://multica.manx-in.ts.net`; manually provisioned Tailscale Service |
| TLS reverse proxy | Serve -> `127.0.0.1:3180` nginx -> frontend/backend |
| JWT/password | Independent random runtime secrets; neither committed nor stored in Nix |
| Signup | Exact explicit nonempty email allowlist, no domain-wide signup |
| Production/telemetry | `APP_ENV=production`, `DO_NOT_TRACK=1`; no fixed verification code |

All three image references in Nix pin manifest-list digests, resolved from the
registries (backend/web tag **v0.6.1**, not `0.6.1` or `latest`). Update the backend
and frontend together after rechecking release source and migrations. PostgreSQL's
pg17 tag is pinned independently. These digest pins improve reproducibility, not
an upstream signature or vulnerability attestation. The images were not pulled
or booted during prototype verification.

No Redis, replica DB, object store, managed cloud, plugin surfaces, integration
keys, worker container, or LLM-provider secret is required for the minimal stack.
The backend includes its own scheduler; uploads use local storage. VCS integration
is explicitly disabled. SMTP/Resend, Google OAuth, GitHub/webhooks, S3 and plugin
surfaces require separate reviewed configuration. Tailnet-only HTTP ingress also
means internet-originating integration webhooks cannot reach this service.
This module deliberately accepts only the two required secrets, not an unrestricted
override env file that could disable its safety policy.

## One origin and WebSockets

Follow upstream [single-origin routing](https://github.com/multica-ai/multica/blob/2ea01ae4ef55de4310b99af192d2dbd367832883/apps/docs/content/docs/self-host-quickstart.mdx#3-configure-public-urls):

* `/ws` (and its subpaths), `/api/daemon/ws`, `/health`, `/readyz`, `/healthz`
  go directly to the backend, preserving path/query and WS upgrades.
* Everything else goes to the frontend, including normal `/api/*` and uploads;
  Next.js proxies these to its runtime backend upstream.
* Next.js **cannot proxy WebSocket upgrades**. Sending all paths to port 3100
  breaks browser realtime and makes the daemon fall back to polling.
* Both advertised app and API URLs use the same HTTPS origin. Leave public
  frontend API/WS overrides empty; the runtime derives same-origin endpoints.

nginx listens only on loopback port 3180, preserves the configured public Host and
HTTPS scheme after Serve terminates TLS, and uses long unbuffered WS timeouts.
The NixOS nginx default request-body limit is 10 MiB; larger uploads need a
separately reviewed limit change. No public TCP firewall rules are added. The only firewall addition permits DNS
on the dedicated container bridge, following Buzz. This bridge is not an
outbound isolation boundary: containers can reach external networks. Published
loopback ports are reachable by other local users; tailnet ACLs do not govern
local processes. Application authentication remains necessary.

## Credentials and authentication

**Operator procedure only, not run by this PR.** Choose the actual login email;
none is inferred from repository/user identity. Enabling with an empty allowlist
fails evaluation. In `configuration.nix`, replace the disabled assignment with:

```nix
services.multica = {
  enable = true;
  hostname = "multica.manx-in.ts.net";
  allowedEmails = [ "YOUR_ACTUAL_LOGIN_EMAIL" ];
};
```

Replace the placeholder with a real email accepted by the option's conservative
validation. Provision credentials **before activation**, from the repository root:

```sh
sudo python3 hosts/optiplex3/multica/render-env.py --init /etc/multica/secrets.env
```

The initializer requires root, creates mode-0600 credentials using independent
32-byte random values, validates existing files and is idempotent (never rotates
or overwrites an existing file). Symlinks, nonregular files, non-root owners,
invalid/duplicate keys and modes other than 0400/0600 are refused. Keep the
parent directory root-only. `multica-init-secrets` is also installed after opt-in.
The input accepts only `POSTGRES_PASSWORD` and `JWT_SECRET`, each 64 hexadecimal
characters. It is not a shell script. Back it up securely outside the checkout.

`multica-env.service` emits service-scoped mode-0600 files beneath root-only
`/run/multica`: PostgreSQL gets only its password; the backend gets JWT and the
complete DB URL. No frontend credentials. Root/container inspection can still
read environment secrets. No existing native PostgreSQL roles, host databases,
Hermes profiles, Buzz credentials or provider accounts are reused.

Without mail configuration, upstream logs a random one-time verification code
even in production. Request a code in the browser, then the operator reads it
from `sudo journalctl -u podman-multica-backend.service` or `sudo podman logs
multica-backend`. **Anyone with access to these logs can complete that login**;
restrict log access and retention. There is no universal development code.
This is acceptable only for a restricted prototype; add real mail delivery before
broader use. HTTPS/tailnet access is not login, and Tailscale user identity does
not become a Multica account automatically. Keep `ALLOW_SIGNUP=true` only with
the explicit exact-email allowlist so the selected first account can be created.
Verify a non-allowlisted address is rejected during the acceptance check.

## Rollout (separate approval required)

1. Review disk/RAM capacity, registry access and backups first. Recheck loopback
   ports **3100, 3180, 8180** and the `multica` network/volume names are unused;
   reserve them exclusively. This is a shared small server. Image downloads and
   migrations consume extra disk; do not assume current free space is sufficient.
2. Make the explicit host opt-in/email edit above and provision runtime secrets.
   Build the full host closure without activation:

   ```sh
   nix build .#nixosConfigurations.optiplex3.config.system.build.toplevel --no-link
   ```

3. In a separately approved maintenance window, activate using the repository's
   normal host deployment procedure. This may restart unrelated changed host
   services: inspect the whole closure diff, not just Multica. The target is
   enabled at boot **only after opting in**. Missing credentials fail closed.

   ```sh
   sudo systemctl restart multica.target
   sudo systemctl status multica.target podman-multica-backend.service
   sudo podman healthcheck run multica-postgres
   sudo podman healthcheck run multica-backend
   sudo podman healthcheck run multica-frontend
   curl -fsS http://127.0.0.1:3180/readyz
   curl -fsS http://127.0.0.1:3180/api/config
   ```

4. Provision a Tailscale Service named `multica`, port 443, with optiplex3 as an
   authorized tagged service host. Configure narrow tailnet grants and approve
   the service host if necessary. The candidate name is not reserved by Nix.
   Only then, on optiplex3:

   ```sh
   sudo tailscale serve --service=svc:multica --https=443 http://127.0.0.1:3180
   sudo tailscale serve status
   ```

   Verify DNS/TLS and reachability from the intended user's tailnet device.
   Do not enable Funnel. Ordinary node Serve would use optiplex3's node name,
   not the service hostname. This PR changes no live Serve routes or tailnet policy.

5. At `https://multica.manx-in.ts.net`, verify signup/login, workspace creation,
   an upload/download, browser WS handshake and realtime updates. Check `/health`
   and `/readyz`, and `/api/config` advertises the HTTPS daemon URL. Restart the
   target, then verify the account, workspace and upload persist. Confirm a
   disallowed email and a tailnet client outside the grants are rejected. Keep
   daemon execution out of this first web-only rollout.

Health checks have bounded startup timeouts; unhealthy containers are killed
and restarted. Database must be healthy before backend, backend before frontend.
A migration failure fails startup; inspect logs, do not bypass migrations.
`systemctl stop multica.target` stops the three containers and environment/network
units, not the shared nginx daemon. The loopback proxy may remain and return 502
until configuration is disabled. Named volumes/network are intentionally retained.

## Daemon: separate explicit opt-in

The packaged CLI's daemon is a code-execution boundary, not a required fourth
server container. Do not auto-start it as root, add it to this target, grant a
Docker socket, or connect the live Hermes profile/provider credentials. For a
later approved trial, use a separate unprivileged account and fresh home/config,
a dedicated test workspace and fresh scoped credentials. Run `multica setup
self-host --help` from the pinned CLI first; configure both server/app URLs to
`https://multica.manx-in.ts.net`, and inspect setup's daemon-start behavior before
executing it. Verify its `/api/daemon/ws` handshake, task execution and filesystem
boundaries separately. Do not run the immutable Nix package's self-updater.

## Backup, rotation and rollback

* Back up `/etc/multica/secrets.env`, database and upload volume together before
  upgrades. Use a PostgreSQL logical dump or a cleanly stopped consistent volume
  backup; do not copy a running database's raw files. Record image digests and
  the active Nix generation. Test restoration away from the live volumes.
* Changing the env password does **not** rotate an initialized database role.
  Coordinate DB role and env rotation; JWT rotation invalidates sessions. Restart
  the target after deliberate credential changes to rerender/recreate consumers.
* To halt a trial: `sudo systemctl stop multica.target`. Remove **only this
  service's** route with `sudo tailscale serve --service=svc:multica --https=443 off`
  and verify `sudo tailscale serve status`. Never reset all Serve state.
* Set `services.multica.enable = false`, rebuild and activate the approved host
  configuration. Verify units/loopback listener are removed and existing services
  still work. Disabling does not delete secrets, `multica-postgres-data`,
  `multica-uploads` or the `multica` network. Retain these for recovery.
* A Nix generation rollback alone does **not** roll back schema migrations.
  Before returning to older backend images, restore a matching pre-upgrade DB
  and uploads backup into separate volumes and verify compatibility. Never
  automatically downgrade the database or delete volumes as cleanup.

## Reproducible checks (no activation)

From the repository root, with Python 3 and Nix available (`nix shell
nixpkgs#python3` if Python is not on PATH):

```sh
python3 -B -m unittest discover -s hosts/optiplex3/multica -v
nix eval --impure --json --file hosts/optiplex3/multica/test-eval.nix
nix build .#nixosConfigurations.optiplex3.config.system.build.toplevel --no-link
nix build --impure --no-link --expr '(builtins.getFlake (toString ./.)).inputs.llm-agents.packages.x86_64-linux.multica'
```

The evaluation checks disabled absence, explicit opt-in, invalid configuration,
all image pins, loopback-only ports, health dependency ordering, production,
telemetry, allowlist and runtime-secret separation, and evaluates both **full
host** top-level derivations. To build the opt-in closure without changing the
host file or activating, and exercise the generated proxy locally:

```sh
expr='let f = builtins.getFlake (toString ./.); in (f.nixosConfigurations.optiplex3.extendModules { modules = [ { services.multica = { enable = f.inputs.nixpkgs-unstable.lib.mkForce true; allowedEmails = [ "operator@example.invalid" ]; }; } ]; }).config'
nix build --impure --no-link --expr "($expr).system.build.toplevel"
nginx_config=$(nix build --impure --no-link --print-out-paths --expr "($expr).environment.etc.\"nginx/nginx.conf\".source")
nginx_package=$(nix build --impure --no-link --print-out-paths --expr "($expr).services.nginx.package")
python3 -B hosts/optiplex3/multica/check-proxy.py "$nginx_config" "$nginx_package/bin/nginx"
```

The proxy check uses real nginx plus explicitly labeled local HTTP/upgrade
fixtures, ephemeral ports and a temporary prefix. It tests six HTTP routes, two
101 upgrade responses and path/query/HTTPS-header preservation. It is **not** a
Multica, database, authenticated WebSocket or Tailscale smoke test. No images
were pulled and no real stack was started; actual migrations, image health
commands, auth, uploads, daemon execution, and tailnet/browser acceptance remain
operator verification. Full host builds do not prove those runtime paths.
