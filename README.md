# nixos-flake

These are my NixOS, nix-darwin, and home-manager configs. Everything is flake-based, 
so I can have my servers update automatically.  Secrets are kept in [sops-nix][sops-nix].

The current version of this flake favors explicit configuration and uses modules to share common
configuration settings.  The modules directory organization is inspired by [RFC-0140][rfc-0140].

This repository is inspired by [nixos-configs][nixos-configs].

[home-manager]: https://github.com/nix-community/home-manager
[rfc-0140]: https://github.com/NixOS/rfcs/pull/140
[sops-nix]: https://github.com/Mic92/sops-nix
[nixos-configs]: https://github.com/reckenrode/nixos-configs
