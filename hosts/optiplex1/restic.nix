{ config, pkgs, ... }:

{
  services.restic.backups = {
    optiplex1 = {
      initialize = true;
      paths = [
        "/var/lib/home-assistant"
      ];
      repositoryFile = "/etc/restic-repository";
      passwordFile = "/etc/restic-password";
      environmentFile = "/etc/restic-env";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
