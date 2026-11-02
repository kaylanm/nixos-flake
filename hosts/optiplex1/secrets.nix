{ config, ... }:

{
  # This remains an external path so the encrypted source is not copied to the
  # Nix store. The file is still safe to commit to this repository.
  sops = {
    defaultSopsFile = "/etc/nixos/secrets/optiplex1.yaml";
    validateSopsFiles = false;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      acme-environment = { };

      linkwarden-nextauth-secret = {
        owner = config.services.linkwarden.user;
        group = config.services.linkwarden.group;
        restartUnits = [
          "linkwarden.service"
          "linkwarden-worker.service"
        ];
      };

      mosquitto-password-hash.restartUnits = [ "mosquitto.service" ];

      nut-password.restartUnits = [
        "upsd.service"
        "upsmon.service"
      ];

      restic-environment = { };
      restic-password = { };
      restic-repository = { };

      zigbee2mqtt-secrets = {
        owner = "zigbee2mqtt";
        group = "zigbee2mqtt";
        restartUnits = [ "zigbee2mqtt.service" ];
      };
    };
  };
}
