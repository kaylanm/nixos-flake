{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs?ref=nixos-unstable";

    home-manager.url = "github:nix-community/home-manager?ref=release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin?ref=nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nix-darwin, home-manager, home-manager-unstable, sops-nix, ... }@inputs:
    let
      modules = import ./modules/top-level/all-modules.nix { inherit (nixpkgs) lib; };
    in
    rec {
      darwinConfigurations = {
        covenant = nix-darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/covenant/configuration.nix
            # home-manager.darwinModules.home-manager
          ] ++ modules.darwin;
        };
      };

      nixosConfigurations = {
        elite1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/elite1/configuration.nix
            # home-manager.nixosModules.home-manager
          ] ++ modules.nixos;
        };

        optiplex1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/optiplex1/configuration.nix
            # sops-nix.nixosModules.sops
          ] ++ modules.nixos;
        };

        optiplex2 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/optiplex2/configuration.nix
            # sops-nix.nixosModules.sops
          ] ++ modules.nixos;
        };

        optiplex3 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/optiplex3/configuration.nix
            # sops-nix.nixosModules.sops
          ] ++ modules.nixos;
        };

        auriga-nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/auriga-nixos/configuration.nix
            # home-manager.nixosModules.home-manager
          ] ++ modules.nixos;
        };

        auriga = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/auriga/configuration.nix
            # home-manager.nixosModules.home-manager
          ] ++ modules.nixos;
        };
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
        mike = {
          imports = [ ./home-manager/mike/home.nix ] ++ modules.home;
          specialArgs = { inherit inputs; };
          # _module.args = { inherit inputs; };
        };
      };
    };
}
