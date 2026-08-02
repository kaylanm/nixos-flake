{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.prometheusGrafana;
  prometheusUrl = "http://127.0.0.1:${toString config.services.prometheus.port}";
  secretKeyFile = "${config.services.grafana.dataDir}/secret-key";
in
{
  options.services.prometheusGrafana = {
    enable = lib.mkEnableOption "a Grafana frontend for the local Prometheus server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "TCP port on which Grafana listens.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.prometheus.enable;
        message = "services.prometheusGrafana requires Prometheus";
      }
      {
        assertion = config.services.tailscale.enable;
        message = "services.prometheusGrafana requires Tailscale";
      }
    ];

    services.grafana = {
      enable = true;

      settings.server = {
        http_addr = "0.0.0.0";
        http_port = cfg.port;
        domain = config.networking.hostName;
      };
      settings.security.secret_key = "$__file{${secretKeyFile}}";

      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          prune = true;
          datasources = [
            {
              name = "Prometheus";
              uid = "prometheus";
              type = "prometheus";
              access = "proxy";
              url = prometheusUrl;
              isDefault = true;
              editable = false;
            }
          ];
        };
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

    # Keep Grafana private even on hosts whose firewall is disabled.
    systemd.services.grafana.serviceConfig = {
      IPAddressAllow = [
        "localhost"
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
      IPAddressDeny = "any";
    };

    systemd.services.grafana.preStart = lib.mkBefore ''
      if [[ ! -s ${lib.escapeShellArg secretKeyFile} ]]; then
        umask 077
        ${lib.getExe pkgs.openssl} rand -hex 32 > ${lib.escapeShellArg secretKeyFile}
      fi
    '';
  };
}
