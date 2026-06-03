{
  inputs,
  ...
}:

{
  imports = [
    inputs.flake-parts.flakeModules.modules
    ../by-name
    ../hosts
    ./packages.nix
    ./overlays.nix
    ./home-manager.nix
    ./colmena.nix
  ];
}
