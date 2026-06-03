{
  config,
  inputs,
}:

let
  inherit (inputs)
    nix-darwin
    nixpkgs
    ;

  commonNixosModules = builtins.attrValues config.flake.modules.nixos;
  commonDarwinModules = builtins.attrValues config.flake.modules.darwin;
in
{
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
}
