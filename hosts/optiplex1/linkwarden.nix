{ config, pkgs, pkgsUnstable, inputs, ... }:

{
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/linkwarden.nix"
  ];

  services.linkwarden = {
    enable = true;
    enableRegistration = true;
    environment = {
      NEXTAUTH_URL = "https://linkwarden.manx-in.ts.net";
    };
    package = pkgsUnstable.linkwarden;
    port = 2293;
    secretFiles = {
      NEXTAUTH_SECRET = "/etc/nextauth-secret";
    };
  };

  services.caddy.virtualHosts."https://linkwarden.manx-in.ts.net".extraConfig = ''
    bind tailscale/linkwarden

    reverse_proxy [::1]:2293
  '';
}

