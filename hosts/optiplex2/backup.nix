{ config, pkgs, ... }:

{
  services.restic.backups = {
    optiplex2 = {
      initialize = true;
      paths = [
        "/var/lib/minecraft-servers/**/world**"
        "/var/lib/bedrock-server/worlds"
      ];
      repositoryFile = config.sops.secrets."restic-repository".path;
      passwordFile = config.sops.secrets."restic-password".path;
      environmentFile = config.sops.secrets."restic-environment".path;
      timerConfig = {
        OnCalendar = "0/6:00"; # every 6 hours
        Persistent = true;
      };
    };
  };
}
