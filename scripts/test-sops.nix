# Run: nix eval --impure --json --file scripts/test-sops.nix
let
  flake = builtins.getFlake (toString ../.);
  c = flake.nixosConfigurations.optiplex3.config;
  s = c.sops.secrets;
  hermes = c.systemd.services.hermes;
  dashboard = c.systemd.services.hermes-dashboard;
  buzz = c.systemd.services.buzz-env;
in
assert builtins.attrNames s == [ "buzz-environment" "github-app-private-key" "hermes-environment" ];
assert c.services.buzz.secretsFile == s.buzz-environment.path;
assert buzz.serviceConfig.LoadCredential == [ "buzz-environment:${s.buzz-environment.path}" ];
assert builtins.match ".*%d/buzz-environment.*" buzz.serviceConfig.ExecStart != null;
assert hermes.serviceConfig.EnvironmentFile == s.hermes-environment.path;
assert dashboard.serviceConfig.EnvironmentFile == s.hermes-environment.path;
assert hermes.environment.GITHUB_APP_PRIVATE_KEY_FILE == s.github-app-private-key.path;
assert dashboard.environment.GITHUB_APP_PRIVATE_KEY_FILE == s.github-app-private-key.path;
assert s.github-app-private-key.path == "/etc/hermes/kaylanm-hermes-agent.2026-10-25.private-key.pem";
assert s.github-app-private-key.owner == "root";
assert s.github-app-private-key.group == "hermes";
assert s.github-app-private-key.mode == "0640";
assert s.buzz-environment.owner == "root" && s.buzz-environment.mode == "0400";
assert s.hermes-environment.owner == "root" && s.hermes-environment.mode == "0400";
assert s.buzz-environment.restartUnits == [ "buzz-env.service" ];
assert s.hermes-environment.restartUnits == [ "hermes.service" "hermes-dashboard.service" ];
assert s.github-app-private-key.restartUnits == [ "hermes.service" "hermes-dashboard.service" ];
{
  optiplex3 = "secret consumers, credential staging, permissions and restart hooks pass";
}
