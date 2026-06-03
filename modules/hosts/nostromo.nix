{
  config,
  inputs,
  ...
}:

let
  inherit (import ./lib.nix { inherit config inputs; }) mkDarwin;
in
{
  flake.darwinConfigurations.nostromo = mkDarwin {
    host = "nostromo";
    system = "x86_64-darwin";
    # extraModules = [ inputs.home-manager.darwinModules.home-manager ];
  };
}
