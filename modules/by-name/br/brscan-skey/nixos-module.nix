{ config, lib, pkgs, ... }:

let
  cfg = config.services.brscan-skey;
  brscan-skey-pkg = pkgs.custom.brscan-skey;

  # Generate the config file from options
  configFile = pkgs.writeTextFile {
    name = "brscan-skey.config";
    text = ''
      password=
      IMAGE=${cfg.imageScript}
      OCR=${cfg.ocrScript}
      EMAIL=${cfg.emailScript}
      FILE=${cfg.fileScript}
      SEMID=b
    '';
  };
in
{
  options.services.brscan-skey = {
    enable = lib.mkEnableOption "Brother scanner key tool (brscan-skey)";

    package = lib.mkOption {
      type = lib.types.package;
      default = brscan-skey-pkg;
      description = "The brscan-skey package to use";
    };

    imageScript = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Script to run when the IMAGE button is pressed";
    };

    ocrScript = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Script to run when the OCR button is pressed";
    };

    emailScript = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Script to run when the EMAIL button is pressed";
    };

    fileScript = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Script to run when the FILE button is pressed";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create systemd service with bind mount for config
    systemd.services.brscan-skey = {
      description = "Brother Scanner Key Tool";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ cfg.package ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/brscan-skey";
        Restart = "on-failure";
        RestartSec = "5s";

        # Bind mount the config file to the expected location
        BindReadOnlyPaths = [
          "${configFile}:/opt/brother/scanner/brscan-skey/brscan-skey.config"
        ];
      };
    };
  };
}
