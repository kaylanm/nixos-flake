{
  config,
  inputs,
  ...
}:

let
  inherit (import ./lib.nix { inherit config inputs; }) mkDarwin;
in
{
  flake.darwinConfigurations.covenant = mkDarwin {
    host = "covenant";
    system = "aarch64-darwin";
    # extraModules = [ inputs.home-manager.darwinModules.home-manager ];
  };
}
