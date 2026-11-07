{ config, ... }:
{
  sops = {
    defaultSopsFile = "/etc/nixos/secrets/optiplex3.yaml";
    validateSopsFiles = false;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      buzz-environment = {
        owner = "root";
        restartUnits = [ "buzz-env.service" ];
      };
      hermes-environment = {
        owner = "root";
        restartUnits = [
          "hermes.service"
          "hermes-dashboard.service"
        ];
      };
      github-app-private-key = {
        owner = "root";
        # Preserve the public runtime API used by CLI GitHub App wrappers too.
        path = "/etc/hermes/kaylanm-hermes-agent.2026-10-25.private-key.pem";
        group = "hermes";
        mode = "0640";
        restartUnits = [
          "hermes.service"
          "hermes-dashboard.service"
        ];
      };
    };
  };

  services.buzz.secretsFile = config.sops.secrets.buzz-environment.path;
}
