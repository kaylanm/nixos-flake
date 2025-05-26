{ lib, config, pkgs, ... }:

{
  services.meshcentral = {
    enable = true;
  };

  services.caddy.virtualHosts."https://meshcentral.manx-in.ts.net".extraConfig = ''
    bind tailscale/meshcentral

    reverse_proxy :3000
  '';
}
