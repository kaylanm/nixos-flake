# Conduit on optiplex3

`hermes.nix` pins `kaishi00/hermes-conduit-notifier` 0.128.0 to
`ea5564e735f566ad37c3e031edb9783a33e90e4c` with a fixed-output source hash.
The existing `hermes-plugins` oneshot links it into the default home's
`plugins/conduit_push` and enables the `conduit_push` registry key in
`plugins.enabled`, removing that key from `plugins.disabled` if necessary.
Other configuration, comments, and other profiles are preserved. An existing
unmanaged plugin directory causes an error rather than being overwritten.

This follows the host's existing Home Assistant provisioning pattern rather
than introducing a second Hermes service module. The Python helper retains
its old filename and two-argument Home Assistant interface for compatibility.
The setup runtime only needs ruamel.yaml. The plugin runs inside Hermes's
Python environment, not the setup runtime: the flake's Hermes 0.22.5 package
already includes cryptography, cffi, HTTP clients, FastAPI and websockets.
No pip/uv install, plugin-manager invocation, relay service or Apple signing
key is required. The upstream manifest declares no additional Python or Node
dependencies. Notification encryption uses cryptography's ChaCha20Poly1305
and HKDF; the packaged runtime was checked with imports and an AEAD round trip.

Pairing credentials and phone data remain mutable private state outside the
Nix store. No phone is paired by this configuration. Other profiles are not
enabled or provisioned. Upstream may link **already opted-in** profiles when
it starts; this change does not opt any of them in.

Update the revision/hash here through Nix, not Conduit's in-app updater or
`hermes plugins update`: the source symlink is read-only. Source changes are
restart triggers for the provisioning, agent and dashboard units on a future
normal deployment. Preparing/building this change does not deploy or restart
them. Pairing and end-to-end delivery still need separate operator validation
after an authorized deployment.

## References

- Official index: https://hermes-agent.nousresearch.com/docs/llms.txt
- Discovery/configuration: https://hermes-agent.nousresearch.com/docs/user-guide/features/plugins
- Upstream install, pairing and profile semantics: https://github.com/kaishi00/hermes-conduit-notifier/blob/ea5564e735f566ad37c3e031edb9783a33e90e4c/README.md
- Manifest: https://github.com/kaishi00/hermes-conduit-notifier/blob/ea5564e735f566ad37c3e031edb9783a33e90e4c/plugin.yaml

## Non-deploying checks

- `test-setup-homeassistant.py`: configuration preservation, idempotence,
  link updates, refusal of unmanaged directories, malformed config, and
  Conduit enablement without changing another profile.
- Evaluate `nixosConfigurations.optiplex3.config.system.build.toplevel.drvPath`.
- Build `nixosConfigurations.optiplex3.config.systemd.units."hermes-plugins.service".unit`
  and the pinned source; build/retrieve the flake's Hermes package.
- Run both evaluated setup commands with the home argument replaced by a
  scratch directory, then run the packaged `hermes plugins list --user
  --enabled --json` with `HERMES_HOME` set to that directory. This checks real
  discovery without loading the plugin, contacting the relay, or touching
  the live profile.
