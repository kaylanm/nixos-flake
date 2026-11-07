# nix eval --impure --json --file hosts/optiplex3/mealie/test-backup-config.nix
let
  flake = builtins.getFlake (toString ../../..);
  config = flake.nixosConfigurations.optiplex3.config;
  backups = config.services.restic.backups;
  backup = backups.mealie;
  unit = config.systemd.services.restic-backups-mealie;
  scope = builtins.mapAttrs (_: host: builtins.hasAttr "mealie" host.config.services.restic.backups) flake.nixosConfigurations;
in
assert builtins.hasAttr "mealie" backups;
assert backup.user == "root";
assert !backup.initialize;
assert backup.repositoryFile == "/etc/restic-repository";
assert backup.passwordFile == "/etc/restic-password";
assert backup.environmentFile == "/etc/restic-env";
assert backup.paths == [ "/var/lib/mealie-backup/snapshot" ];
assert backup.timerConfig.Persistent;
assert backup.pruneOpts == [ ];
assert backup.runCheck;
assert unit.serviceConfig.StateDirectory == "mealie-backup";
assert unit.serviceConfig.StateDirectoryMode == "0700";
assert unit.serviceConfig.TimeoutStartSec == "2h";
assert unit.serviceConfig.ExecStopPost != [ ];
assert builtins.all (name: name == "optiplex3" || !scope.${name}) (builtins.attrNames scope);
assert builtins.all (assertion: assertion.assertion) config.assertions;
{
  inherit scope;
  result = "Mealie backup configuration checks passed";
}
