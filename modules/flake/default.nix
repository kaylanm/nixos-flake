{
  inputs,
  ...
}:

{
  imports = [
    inputs.flake-parts.flakeModules.modules
    ./modules.nix
    ./packages.nix
    ./overlays.nix
    ./hosts.nix
    ./home-manager.nix
    ./colmena.nix
  ];
}
