{ config, pkgs, ... }:

{
  services.immich = {
    enable = true;
    machine-learning = {
      enable = false;
    };
  };

  services.caddy.virtualHosts."https://immich.manx-in.ts.net".extraConfig = ''
    bind tailscale/immich

    reverse_proxy [::1]:2283
  '';
}

