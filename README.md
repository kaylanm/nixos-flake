# nixos-flake

These are my NixOS, nix-darwin, and home-manager configs. Everything is flake-based, 
so I can have my servers update automatically.  Secrets are kept in [sops-nix][sops-nix].

The current version of this flake favors explicit configuration and uses modules to share common
configuration settings.  The modules directory organization is inspired by [RFC-0140][rfc-0140].

This repository is inspired by [nixos-configs][nixos-configs].

Rex is installed from the [official Nix flake][rex-nix], pinned in `flake.lock`.
The client is enabled on `auriga` and `auriga-nixos`. On `optiplex1`, `optiplex2`,
`optiplex3`, and `elite2`, `rex.service` starts at boot as `mike` and listens on
the owner-only socket `/run/rex/server.sock`. Sessions run with Mike's home and
permissions; persistent server state is stored in `/var/lib/rex`.

After rebuilding the hosts, connect with existing SSH credentials and an explicit
socket path to reach the managed server:

```sh
rex -S ssh://mike@optiplex1/run/rex/server.sock ls
rex hosts add optiplex1 ssh://mike@optiplex1/run/rex/server.sock
```

Use the same address pattern for the other servers. Omitting the socket path uses
Rex's separate personal server instead. Update the pinned release with
`nix flake update rex`.

[home-manager]: https://github.com/nix-community/home-manager
[rfc-0140]: https://github.com/NixOS/rfcs/pull/140
[sops-nix]: https://github.com/Mic92/sops-nix
[nixos-configs]: https://github.com/reckenrode/nixos-configs
[rex-nix]: https://www.superlogical.com/rex/docs/linux/installation#nix-and-nixos
