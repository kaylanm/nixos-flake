{
  sops = {
    defaultSopsFile = "/etc/nixos/secrets/optiplex2.yaml";
    validateSopsFiles = false;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      restic-environment = { };
      restic-password = { };
      restic-repository = { };
    };
  };
}
