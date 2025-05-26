{ lib, config, pkgs, ... }:

{
  services.karakeep = {
    enable = true;
    extraEnvironment = {
      PORT = "3001";
      NEXTAUTH_URL = "https://karakeep.manx-in.ts.net";
    };
  };

  services.caddy.virtualHosts."https://karakeep.manx-in.ts.net".extraConfig = ''
    bind tailscale/karakeep

    reverse_proxy :3001
  '';
}
