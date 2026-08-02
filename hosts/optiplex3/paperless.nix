{ config, pkgs, ... }:

{
  services.paperless = {
    enable = true;
    settings = {
      PAPERLESS_URL = "https://paperless.manx-in.ts.net";
    };
  };

  services.tailscale.serve.services.paperless.endpoints."tcp:443" = "http://localhost:28981";
}
