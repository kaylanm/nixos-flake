{ config, pkgs, ... }:

{
  services.restic.backups = {
    optiplex2 = {
      initialize = true;
      paths = [
        "/var/lib/minecraft-servers/**/world**"
        "/var/lib/bedrock-server/worlds"
      ];
      repositoryFile = "/etc/restic-repository";
      passwordFile = "/etc/restic-password";
      environmentFile = "/etc/restic-env";
      timerConfig = {
        OnCalendar = "0/6:00"; # every 6 hours
        Persistent = true;
      };
    };
  };
}
