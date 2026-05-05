{ config, pkgs, inputs, ... }:

let
  esphomePkg = pkgs.esphome;
in
{
  services.esphome = {
    enable = true;
    package = esphomePkg;
  };

  # esphome cli for interactive use
  environment.systemPackages = [ esphomePkg ];

  services.caddy.virtualHosts."https://esphome.manx-in.ts.net".extraConfig = ''
    bind tailscale/esphome

    reverse_proxy :6052
  '';
}
