{
  config,
  inputs,
  ...
}:

let
  inherit (inputs) nix-flatpak;
  inherit (import ./lib.nix { inherit config inputs; }) mkNixos;
in
{
  flake.nixosConfigurations.elite1 = mkNixos {
    host = "elite1";
    extraModules = [
      nix-flatpak.nixosModules.nix-flatpak
      # inputs.home-manager.nixosModules.home-manager
    ];
  };
}
