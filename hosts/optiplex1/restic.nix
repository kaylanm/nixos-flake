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
      repositoryFile = config.sops.secrets."restic-repository".path;
      passwordFile = config.sops.secrets."restic-password".path;
      environmentFile = config.sops.secrets."restic-environment".path;
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
