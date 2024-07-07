{ config, pkgs, inputs, ... }:

let
  esphomePkg = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.esphome;
in
{
  services.esphome = {
    enable = true;
    openFirewall = true;
    address = "0.0.0.0";
    package = esphomePkg;
  };

  environment.systemPackages = [ esphomePkg ];
}
