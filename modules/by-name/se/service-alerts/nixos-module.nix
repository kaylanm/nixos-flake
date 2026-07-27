{
  config,
  lib,
  ...
}:

let
  cfg = config.services.serviceAlerts;
  systemdExporterPort = config.services.prometheus.exporters.systemd.port;
  exporterTargets = map (host: "${host}:${toString systemdExporterPort}") cfg.server.targets;
in
{
  options.services.serviceAlerts = {
    agent.enable = lib.mkEnableOption "exporting systemd unit health to the monitoring server";

    server = {
      enable = lib.mkEnableOption "central service failure alerting";

      targets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "optiplex1"
          "optiplex2"
          "optiplex3"
          "pi4"
          "h2plus"
        ];
        description = "Tailscale hostnames whose systemd exporters should be monitored.";
      };

      ntfyBaseUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://ntfy.sh";
        description = "Base URL of the ntfy server used for alert notifications.";
      };

      ntfyConfigFile = lib.mkOption {
        type = lib.types.path;
        default = "/etc/alertmanager-ntfy.yml";
        description = ''
          Runtime-only alertmanager-ntfy configuration containing the secret
          ntfy topic and, when needed, authentication credentials.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.agent.enable {
      assertions = [
        {
          assertion = config.services.tailscale.enable;
          message = "services.serviceAlerts.agent requires Tailscale";
        }
      ];

      services.prometheus.exporters.systemd = {
        enable = true;
        listenAddress = "0.0.0.0";
        extraFlags = [ "--systemd.collector.enable-restart-count" ];
      };

      # The firewall rule handles hosts with the firewall enabled. The systemd
      # IP policy also protects hosts such as optiplex1 that disable it.
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ systemdExporterPort ];
      systemd.services.prometheus-systemd-exporter.serviceConfig = {
        IPAddressAllow = [
          "localhost"
          "100.64.0.0/10"
          "fd7a:115c:a1e0::/48"
        ];
        IPAddressDeny = "any";
      };
    })

    (lib.mkIf cfg.server.enable {
      assertions = [
        {
          assertion = cfg.agent.enable;
          message = "services.serviceAlerts.server requires the monitoring agent";
        }
      ];

      services.prometheus = {
        enable = true;
        listenAddress = "127.0.0.1";
        retentionTime = "30d";

        globalConfig = {
          scrape_interval = "30s";
          evaluation_interval = "30s";
        };

        scrapeConfigs = [
          {
            job_name = "systemd";
            static_configs = [ { targets = exporterTargets; } ];
          }
        ];

        alertmanagers = [
          {
            static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ];
          }
        ];

        rules = [
          ''
            groups:
              - name: systemd
                rules:
                  - alert: SystemdExporterDown
                    expr: up{job="systemd"} == 0
                    for: 3m
                    labels:
                      severity: critical
                    annotations:
                      summary: "{{ $labels.instance }} is unreachable"
                      description: "Prometheus has been unable to scrape the systemd exporter for three minutes."

                  - alert: SystemdUnitFailed
                    expr: systemd_unit_state{state="failed"} == 1
                    for: 2m
                    labels:
                      severity: critical
                    annotations:
                      summary: "{{ $labels.name }} failed on {{ $labels.instance }}"
                      description: "The systemd unit has remained in the failed state for two minutes."

                  - alert: SystemdServiceRestarting
                    expr: increase(systemd_service_restart_total[15m]) > 5
                    for: 5m
                    labels:
                      severity: warning
                    annotations:
                      summary: "{{ $labels.name }} is repeatedly restarting on {{ $labels.instance }}"
                      description: "The service restarted more than five times in fifteen minutes."
          ''
        ];

        alertmanager = {
          enable = true;
          listenAddress = "127.0.0.1";
          configuration = {
            global.resolve_timeout = "5m";
            route = {
              receiver = "ntfy";
              group_by = [
                "alertname"
                "instance"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            };
            receivers = [
              {
                name = "ntfy";
                webhook_configs = [
                  {
                    url = "http://127.0.0.1:8000/hook";
                    send_resolved = true;
                  }
                ];
              }
            ];
          };
        };

        alertmanager-ntfy = {
          enable = true;
          settings = {
            http.addr = "127.0.0.1:8000";
            ntfy = {
              baseurl = cfg.server.ntfyBaseUrl;
              notification.topic = "";
            };
          };
          extraConfigFiles = [ cfg.server.ntfyConfigFile ];
        };
      };

      # Allow the monitoring stack to deploy before the host-specific secret is
      # provisioned. Starting this service after creating the file enables
      # notifications without another NixOS rebuild.
      systemd.services.alertmanager-ntfy.unitConfig.ConditionPathExists = cfg.server.ntfyConfigFile;
    })
  ];
}
