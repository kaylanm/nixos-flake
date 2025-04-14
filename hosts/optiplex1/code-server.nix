{ lib, config, pkgs, ... }:

{
  services.code-server = {
    enable = true;
    disableWorkspaceTrust = true;
    disableTelemetry = true;
    disableGettingStartedOverride = true;
    auth = "none";
  };

  services.caddy.virtualHosts."https://code.manx-in.ts.net".extraConfig = ''
    bind tailscale/code

    reverse_proxy [::1]:4444
  '';
}
