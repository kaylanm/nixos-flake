# Run from the repository root:
# nix eval --impure --json --file hosts/optiplex3/mealie/test-config.nix
let
  flake = builtins.getFlake (toString ../../..);
  config = flake.nixosConfigurations.optiplex3.config;
  mealie = config.services.mealie;
  unit = config.systemd.services.mealie;
  scope = builtins.mapAttrs (_: host: host.config.services.mealie.enable) flake.nixosConfigurations;
in
assert mealie.enable;
assert mealie.listenAddress == "127.0.0.1";
assert mealie.port == 9000;
assert !mealie.openFirewall;
assert !(builtins.elem mealie.port config.networking.firewall.allowedTCPPorts);
assert mealie.database.createLocally;
assert mealie.settings.BASE_URL == "https://mealie.manx-in.ts.net";
assert mealie.settings.ALLOW_SIGNUP == "false";
assert mealie.settings.OIDC_AUTH_ENABLED == "false";
assert unit.serviceConfig.DynamicUser;
assert unit.serviceConfig.StateDirectory == "mealie";
assert builtins.elem "mealie" config.services.postgresql.ensureDatabases;
assert builtins.all (name: name == "optiplex3" || !scope.${name}) (builtins.attrNames scope);
assert builtins.all (assertion: assertion.assertion) config.assertions;
{
  inherit scope;
  version = mealie.package.version;
  result = "Mealie host configuration checks passed";
}
