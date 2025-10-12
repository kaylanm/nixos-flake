{ config, pkgs, pkgsUnstable, ... }:

{
  services.immich = {
    enable = true;
    package = pkgsUnstable.immich;
  };

  services.caddy.virtualHosts."https://immich.manx-in.ts.net".extraConfig = ''
    bind tailscale/immich

    reverse_proxy [::1]:2283
  '';
}

