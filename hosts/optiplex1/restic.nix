{ config, pkgs, ... }:

{
  services.restic.backups = {
    optiplex1 = {
      initialize = true;
      repository = "rest:https://w5t0q43x:DMRHt6Q1zmnlY0KR@w5t0q43x.repo.borgbase.com";
      paths = [
        "/var/lib/home-assistant"
      ];
      passwordFile = "/etc/restic-password";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
