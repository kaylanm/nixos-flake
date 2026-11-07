{ config, lib, pkgs, ... }:

let
  staging = "/var/lib/mealie-backup";
  # Use the physical DynamicUser directory, not /var/lib/mealie's symlink.
  state = "/var/lib/private/mealie";
  prepare = pkgs.writeShellApplication {
    name = "mealie-backup-prepare";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.util-linux
      config.services.postgresql.package
      pkgs.gnutar
    ];
    text = builtins.readFile ./backup-prepare.sh;
  };
  cleanup = pkgs.writeShellApplication {
    name = "mealie-backup-cleanup";
    runtimeInputs = [ pkgs.coreutils pkgs.systemd ];
    text = builtins.readFile ./backup-cleanup.sh;
  };
in
{
  services.restic.backups.mealie = {
    user = "root";
    repositoryFile = "/etc/restic-repository";
    passwordFile = "/etc/restic-password";
    environmentFile = "/etc/restic-env";
    # Provision and verify the intended off-host repository explicitly.
    initialize = false;
    paths = [ "${staging}/snapshot" ];
    extraBackupArgs = [ "--tag mealie" "--host optiplex3" ];
    # Retain snapshots until a repository-specific retention policy is approved.
    pruneOpts = [ ];
    runCheck = true;
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
    backupPrepareCommand = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      # Check credentials/repository before causing application downtime.
      ${lib.getExe pkgs.restic} cat config > /dev/null
      ${lib.getExe prepare} ${staging} ${staging} ${state}
    '';
    backupCleanupCommand = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      ${lib.getExe cleanup} ${staging} ${staging}
    '';
  };

  systemd.services.restic-backups-mealie = {
    wants = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
    serviceConfig = {
      StateDirectory = "mealie-backup";
      StateDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStartSec = "2h";
      TimeoutStopSec = "5min";
    };
  };
}
