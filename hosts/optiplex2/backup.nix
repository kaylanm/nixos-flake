{ config, pkgs, ... }:

{
  services.restic.backups = {
    optiplex2 = {
      initialize = true;
      repository = "rest:https://l9de4zro:35TurEpMF3PgUB38@l9de4zro.repo.borgbase.com";
      paths = [
        "/var/lib/minecraft-servers/**/world"
        "/var/lib/bedrock-server/worlds"
      ];
      passwordFile = "/etc/restic-password";
      timerConfig = {
        OnCalendar = "0/6:00"; # every 6 hours
        Persistent = true;
      };
    };
  };
}
