{ config, pkgs, ... }:

{
  services.homebox = {
    enable = true;
    settings = {
      HBOX_OPTIONS_ALLOW_REGISTRATION = "true";
    };
  };

  services.tailscale.serve.services.homebox.endpoints."tcp:443" = "http://localhost:7745";
}
