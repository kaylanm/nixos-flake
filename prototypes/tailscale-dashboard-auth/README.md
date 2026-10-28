# Tailscale Serve identity auth — isolated experiment

**Not enabled. Do not replace the live dashboard with this prototype.** No host,
flake output, systemd unit, Serve route, OIDC settings, or immutable Hermes file
is modified. This is a server authentication experiment, not proof that either
iOS application works.

## Design and privilege boundary

Tailscale Serve terminates tailnet HTTPS and supplies `Tailscale-User-Login`.
Only an exact, case-sensitive, explicitly supplied ASCII login allowlist is
accepted. Missing, disallowed, duplicate, comma-joined, and encoded/non-ASCII
identities fail closed. Display name and avatar are never authorization inputs.
Tagged-device and Funnel requests lacking a user identity are denied. Shared
users are not automatically trusted. **Each allowed identity receives full
Hermes dashboard owner/operator privileges across profiles, not a scoped account.**

A private, owned, non-symlink `0700` socket directory and `0600` Unix socket
remove the TCP ingress. Both Uvicorn HTTP and WebSocket protocol handlers check
`AF_UNIX` and Linux `SO_PEERCRED`; the CLI accepts **only UID 0**, matching the
root tailscaled on this host. A private object marks accepted scopes. Neither
loopback nor ASGI client IP nor forwarded headers prove trusted ingress. Even
an accidental TCP bind is rejected. Nonroot processes including the service UID
cannot forge a root peer. Root, the application process/code owner, and the
kernel remain trusted; root's identity does not distinguish tailscaled from
other root processes. A socket-directory owner can disrupt service. No claim
is made about confinement against a compromised dashboard process.

The gate runs for every HTTP request, asset, health probe, and WS upgrade, with
no public-path identity exemptions. It validates one exact Host and at most one
exact HTTPS Origin. Cross-site/same-site `Sec-Fetch-Site` values are denied;
browser mutations and WS identified by Fetch Metadata require Origin. Native
clients may omit both Origin and Fetch Metadata. Wrong or `null` Origin is
always rejected. This relies on standard browsers sending Origin on mutations
and upgrades; it cannot distinguish a native client from a nonconforming browser
that omits all browser-origin signals. No CORS relaxation is added. GET endpoints
must remain non-mutating; audit this invariant before any production integration.

No auth middleware is bypassed or monkeypatched. A registered request-scoped
`DashboardAuthProvider` bridges accepted identity into Hermes' **existing HTTP
session verifier and WS bearer verifier**. A random internal credential is valid
only in its ContextVar request context; it is not persisted, returned as a client
credential, or usable in another request. The HTTP gate attaches the verified
Session; WS verification stamps the principal used by the real gateway.
Authorization, cookies, native gateway tickets and forwarded authority fields
are stripped; WS query token/ticket/internal and ticket subprotocols cannot
override identity. Interactive/native login routes are disabled. Existing WS
ticket issuance is available for the SPA but such tickets cannot bypass the
identity gate, and clients do not need one. Service-token-only registered routes
remain fail-closed (the provider intentionally does not implement token scopes).

## Run the complete prototype suite against installed Hermes

From the repository root:

```sh
nix shell nixpkgs#python3 --command python3 prototypes/tailscale-dashboard-auth/installed.py test
```

`installed.py` reads the Nix launcher's literal interpreter/source settings
without evaluating shell, then runs that interpreter and its bundled dependencies.
No pip/uv installs or modifications to Hermes. The test command creates disposable
HOME/HERMES_HOME and initializes a disposable session database. Network traffic
is local Unix sockets, plus one ephemeral loopback listener explicitly tested
for rejection. Tests use the real installed Hermes routes/middleware, not a
replacement auth service: `/api/auth/me`, session listing/streaming export,
`/api/ws` handshake, and `/api/pub` → `/api/events` streamed frames.

The suite also exercises identity/Host/Origin ambiguity, CSRF, valid WS-ticket
non-bypass, credential stripping, public-path guarding, concurrent principals,
untrusted kernel UID, TCP spoofing, and unsafe socket paths/config. Test mode
uses the current UID to simulate the root proxy without sudo; a second server
uses a different expected UID and rejects the very same caller. That is **not**
a claim to have tested tailscaled's root process or unprivileged OS users.

Tested implementation: Hermes **0.22.5**, upstream `bf0203a7`, Nix store package
`qx5cprfp31mi9fyvg5ksihhdsd0c7bq6-hermes-agent-0.22.5`. Retest every Hermes or
Uvicorn update. The wrapper format is Nix-package-specific, not a general installer.

## Build the isolated package (not a flake output)

`default.nix` takes `{ pkgs, hermes }`, executes the complete prototype suite in
the derivation, then installs `hermes-tailscale-auth-prototype`. Example from
repository root, with no result symlink:

```sh
nix build --impure --no-link --expr 'let
  f = builtins.getFlake (toString ./.);
  pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; };
in import ./prototypes/tailscale-dashboard-auth {
  inherit pkgs;
  hermes = f.inputs.llm-agents.packages.${builtins.currentSystem}.hermes-agent;
}'
```

## Manual server boundary and deliberately missing production integration

`server.py` supports `--socket PATH --origin https://prototype.example
--allow-login owner@example.com` (repeat for each approved login). It requires an
isolated absolute `0700` HERMES_HOME and an existing private socket parent. The
production-mode CLI hardcodes root proxy UID. It never opens a TCP listener.
Use disposable state only; **do not use the live Hermes profile**. The launcher
intentionally skips normal dashboard lifespan/startup: no plugin startup, cron,
agent keepalive, process registration, or complete frontend/bootstrap validation.
This is not a drop-in replacement for `hermes dashboard`.

No Serve configuration is changed. Before proposing deployment, add and review
an upstream first-class request-identity provider/UDS launcher covering normal
startup, internal child HTTP/WS calls, health self-tests and token-route policy.
Internal helpers lack tailnet user identity and will currently be rejected.
Verify a separate test Serve service, actual header stripping/identity insertion,
root Unix peer, filesystem permissions, no alternate TCP listener, tailnet ACLs,
and explicit allowlist. Do not infer these from the injected-header tests.
Production cutover/rollback and removal of TCP 9119 require separate approval.

Hermex documents username/password onboarding for direct Hermes connections;
a tokenless/manual endpoint mode may need client changes. Fleet's owner-login
pairing uses `/api/fleet/devices/enroll` and `/api/fleet/connection`; these routes
were not found in the installed core Hermes source. Fleet manual JSON-RPC WS is
a separate path to test. Neither app was run here. End-to-end pairing, RPC calls,
streaming, reconnect, browser UI, and tailnet Serve spoofing remain unverified.

## Sources

- [Hermes dashboard documentation](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard)
- [Tailscale Serve identity/UDS documentation](https://tailscale.com/docs/features/tailscale-serve)
- [Hermex README](https://github.com/uzairansaruzi/hermex/blob/master/README.md)
- [Fleet gateway pairing](https://github.com/AIowa-LLC/hermes-fleet/blob/main/docs/gateway-pairing.md)
- Installed source seams: `dashboard_auth/middleware.py`, `base.py`, `registry.py`,
  `token_auth.py`, `web_server.py`, `web_server_chat.py`, `web_server_boundary.py`,
  `web_routers/chat_ws.py`.
