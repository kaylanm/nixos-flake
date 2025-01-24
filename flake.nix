{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs?ref=nixos-unstable";

    home-manager.url = "github:nix-community/home-manager?ref=release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";

    #ghostty.url = "github:ghostty-org/ghostty";
    #ghostty.inputs.nixpkgs-stable.follows = "nixpkgs";
    #ghostty.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nix-darwin, home-manager, home-manager-unstable, sops-nix, ... }@inputs:
    let
      modules = import ./modules/top-level/all-modules.nix { inherit (nixpkgs) lib; };
    in
    rec {
      darwinConfigurations = {
      #   josette = nix-darwin.lib.darwinSystem {
      #     inherit inputs;
      #     system = "aarch64-darwin";
      #     modules = [
      #       ./hosts/josette/configuration.nix
      #       home-manager.darwinModules.home-manager
      #     ] ++ modules.darwin;
      #   };

      #   natalia = nix-darwin.lib.darwinSystem {
      #     inherit inputs;
      #     system = "aarch64-darwin";
      #     modules = [
      #       ./hosts/natalia/configuration.nix
      #       home-manager.darwinModules.home-manager
      #     ] ++ modules.darwin;
      #   };

      #   iMac = nix-darwin.lib.darwinSystem {
      #     inherit inputs;
      #     system = "x86_64-darwin";
      #     modules = [
      #       ./hosts/imac/configuration.nix
      #       home-manager.darwinModules.home-manager
      #     ] ++ modules.darwin;
      #   };
      };

      nixosConfigurations = {
        elite1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/elite1/configuration.nix
          ];
        };

        optiplex1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/optiplex1/configuration.nix
            { _module.args = { inherit inputs; }; }
          ];
        };

        optiplex2 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/optiplex2/configuration.nix
          ];
        };

        optiplex3 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/optiplex3/configuration.nix
          ];
        };

        cybernix = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/cybernix/configuration.nix
          ];
        };

        auriga-nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/auriga-nixos/configuration.nix
          ];
        };

        nixos-1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/nixos-1/configuration.nix
          ];
        };

        nixos-2 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/nixos-2/configuration.nix
          ];
        };


        # meteion = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   modules = [
        #     ./hosts/meteion/configuration.nix
        #     home-manager.nixosModules.home-manager
        #     sops-nix.nixosModules.sops
        #     { _module.args = { inherit inputs; }; }
        #   ] ++ modules.nixos;
        # };

        # vamp = nixpkgs-unstable.lib.nixosSystem {
        #   system = "aarch64-linux";
        #   modules = [
        #     ./hosts/vamp/configuration.nix
        #     home-manager-unstable.nixosModules.home-manager
        #     sops-nix.nixosModules.sops
        #     { _module.args = { inherit inputs; }; }
        #   ] ++ modules.nixos;
        # };

        # web-server = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   modules = [
        #     ./hosts/web-server/configuration.nix
        #     home-manager.nixosModules.home-manager
        #     foundryvtt.nixosModules.foundryvtt
        #     sops-nix.nixosModules.sops
        #     { _module.args = { inherit inputs; }; }
        #   ] ++ modules.nixos;
        # };

        # zhloe = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   modules = [
        #     ./hosts/zhloe/configuration.nix
        #     home-manager.nixosModules.home-manager
        #     sops-nix.nixosModules.sops
        #     { _module.args = { inherit inputs; }; }
        #   ] ++ modules.nixos;
        # };
      };

      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [];
          };
        };
      } // builtins.mapAttrs (name: value: { imports = value._module.args.modules; }) nixosConfigurations;

      hmModules = {
      #   reckenrode = {
      #     imports = [ ./home-manager/reckenrode/home.nix ] ++ modules.home;
      #     _module.args = { inherit inputs; };
      #   };
      #   server-admin = {
      #     imports = [ ./home-manager/server-admin/home.nix ] ++ modules.home;
      #     _module.args = { inherit inputs; };
      #   };
      };
    };
}
