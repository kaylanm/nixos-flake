{ config, pkgs, ... }:

{
  services.paperless = {
    enable = true;
    settings = {
      PAPERLESS_URL = "https://paperless.manx-in.ts.net";
    };
  };
}

