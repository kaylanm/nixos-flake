{ config, pkgs, ... }:

{
  services.esphome = {
    enable = true;
    openFirewall = true;
    address = "0.0.0.0";
    package = nixpkgs-unstable.legacyPackages.${system}.esphome;
  };
}