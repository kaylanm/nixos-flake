{
  config,
  inputs,
  ...
}:

let
  inherit (inputs)
    nix-darwin
    nix-flatpak
    nixos-hardware
    nixpkgs
    nixpkgs-unstable
    ;

  commonNixosModules = builtins.attrValues config.flake.modules.nixos;
  commonDarwinModules = builtins.attrValues config.flake.modules.darwin;

  mkNixos =
    {
      host,
      system ? "x86_64-linux",
      nixpkgsInput ? nixpkgs,
      extraModules ? [ ],
      sharedModules ? commonNixosModules,
    }:
    nixpkgsInput.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ../../hosts/${host}/configuration.nix
      ]
      ++ extraModules
      ++ sharedModules;
    };

  mkDarwin =
    {
      host,
      system,
      extraModules ? [ ],
      sharedModules ? commonDarwinModules,
    }:
    nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ../../hosts/${host}/configuration.nix
      ]
      ++ extraModules
      ++ sharedModules;
    };
in
{
  flake = {
    darwinConfigurations = {
      covenant = mkDarwin {
        host = "covenant";
        system = "aarch64-darwin";
        # extraModules = [ inputs.home-manager.darwinModules.home-manager ];
      };

      nostromo = mkDarwin {
        host = "nostromo";
        system = "x86_64-darwin";
        # extraModules = [ inputs.home-manager.darwinModules.home-manager ];
      };
    };

    nixosConfigurations = {
      elite1 = mkNixos {
        host = "elite1";
        extraModules = [
          nix-flatpak.nixosModules.nix-flatpak
          # inputs.home-manager.nixosModules.home-manager
        ];
      };

      elite2 = mkNixos {
        host = "elite2";
        # extraModules = [ inputs.home-manager.nixosModules.home-manager ];
      };

      optiplex1 = mkNixos {
        host = "optiplex1";
        nixpkgsInput = nixpkgs-unstable;
        # extraModules = [ inputs.sops-nix.nixosModules.sops ];
      };

      optiplex2 = mkNixos {
        host = "optiplex2";
        nixpkgsInput = nixpkgs-unstable;
        # extraModules = [ inputs.sops-nix.nixosModules.sops ];
      };

      optiplex3 = mkNixos {
        host = "optiplex3";
        nixpkgsInput = nixpkgs-unstable;
        # extraModules = [ inputs.sops-nix.nixosModules.sops ];
      };

      auriga-nixos = mkNixos {
        host = "auriga-nixos";
        nixpkgsInput = nixpkgs-unstable;
        # extraModules = [ inputs.home-manager.nixosModules.home-manager ];
      };

      auriga = mkNixos {
        host = "auriga";
        nixpkgsInput = nixpkgs-unstable;
        # extraModules = [ inputs.home-manager.nixosModules.home-manager ];
      };

      ryan-linux-pc = mkNixos {
        host = "ryan-linux-pc";
        nixpkgsInput = nixpkgs-unstable;
        extraModules = [ nix-flatpak.nixosModules.nix-flatpak ];
      };

      pi4 = mkNixos {
        host = "pi4";
        system = "aarch64-linux";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
        sharedModules = [ config.flake.modules.nixos.unstable ];
      };
    };
  };
}
