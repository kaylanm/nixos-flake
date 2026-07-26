{ config, pkgs, ... }:

{
  services.restic.backups = {
    optiplex1 = {
      initialize = true;
      paths = [
        "/var/lib/acme"
        "/var/lib/esphome"
        "/var/lib/home-assistant"
        "/var/lib/immich"
        "/var/lib/linkwarden"
        "/var/lib/matterjs-server"
        "/var/lib/music-assistant"
        "/var/lib/tailscale"
        "/var/lib/zigbee2mqtt"
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
