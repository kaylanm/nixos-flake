{ lib, config, pkgs, ... }:

{
  services.meshcentral = {
    enable = true;
  };

  services.caddy.virtualHosts."https://meshcentral.manx-in.ts.net".extraConfig = ''
    bind tailscale/meshcentral

    reverse_proxy https://localhost:1025 {
      transport http {
        tls_insecure_skip_verify
      }
    }
  '';
}
