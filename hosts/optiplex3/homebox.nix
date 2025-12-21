{ config, pkgs, ... }:

{
  services.homebox = {
    enable = true;
    settings = {
      HBOX_OPTIONS_ALLOW_REGISTRATION = "true";
    };
  };
}

