{
  config,
  inputs,
  ...
}:

let
  inherit (inputs) nix-flatpak nixpkgs-unstable;
  inherit (import ./lib.nix { inherit config inputs; }) mkNixos;
in
{
  flake.nixosConfigurations.ryan-linux-pc = mkNixos {
    host = "ryan-linux-pc";
    nixpkgsInput = nixpkgs-unstable;
    extraModules = [ nix-flatpak.nixosModules.nix-flatpak ];
  };
}
