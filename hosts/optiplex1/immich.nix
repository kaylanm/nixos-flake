{ config, pkgs, ... }:

{
  services.immich = {
    enable = true;
    machine-learning = {
      enable = false;
    };
  };
}
