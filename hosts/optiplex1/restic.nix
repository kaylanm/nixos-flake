{ config, pkgs, ... }:

{
  services.restic.backups = {
    optiplex1 = {
      initialize = true;
      paths = [
        "/var/lib/home-assistant"
        "/var/lib/immich"
      ];
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 4"
        "--keep-monthly 1"
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
