{ config, pkgs, ... }:

{
  services.immich = {
    enable = true;
    machine-learning = {
      enable = false;
    };
  };

  services.tailscale.serve.services.immich.endpoints."tcp:443" = "http://localhost:2283";
}
