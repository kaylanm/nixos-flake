{
  config,
  inputs,
  ...
}:

let
  inherit (inputs) nixos-hardware;
  inherit (import ./lib.nix { inherit config inputs; }) mkNixos;
in
{
  flake.nixosConfigurations.pi4 = mkNixos {
    host = "pi4";
    system = "aarch64-linux";
    extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
    sharedModules = [ config.flake.modules.nixos.unstable ];
  };
}
