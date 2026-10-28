{
  config,
  lib,
  pkgs,
  ...
}:
let
  # multica-ai/multica v0.6.1 docker-compose.selfhost.yml, not the dev Compose.
  cfg = config.services.multica;
  runtime = "/run/multica";
  podman = lib.getExe config.virtualisation.podman.package;
  names = [
    "postgres"
    "backend"
    "frontend"
  ];
  unit = name: "podman-multica-${name}.service";
  health = command: [
    "--health-cmd=${command}"
    "--health-interval=5s"
    "--health-timeout=3s"
    "--health-retries=12"
    "--health-start-period=20s"
    "--health-on-failure=kill"
  ];
  container = name: {
    autoStart = false;
    networks = [ "multica" ];
    podman.sdnotify = "healthy";
    extraOptions = [ "--network-alias=${name}" ];
  };
  origin = "https://${cfg.hostname}";
  proxyHeaders = ''
    proxy_set_header Host ${cfg.hostname};
    proxy_set_header X-Forwarded-Host ${cfg.hostname};
    proxy_set_header X-Forwarded-Proto https;
  '';
  route = upstream: {
    proxyPass = "http://127.0.0.1:${upstream}";
    recommendedProxySettings = false;
    extraConfig = proxyHeaders;
  };
  websocket = (route "8180") // {
    proxyWebsockets = true;
    extraConfig = proxyHeaders + "proxy_read_timeout 3600s; proxy_buffering off;";
  };
in
{
  options.services.multica = {
    enable = lib.mkEnableOption "the isolated Multica self-host prototype";
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "multica.manx-in.ts.net";
      description = "Manually provisioned Tailscale Service HTTPS hostname.";
    };
    allowedEmails = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}");
      default = [ ];
      description = "Explicit signup/login email allowlist; enabling requires at least one address.";
    };
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/multica/secrets.env";
      description = "Root-only runtime JWT/database secrets, never a Nix store path.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend == "podman";
        message = "Multica requires the Podman backend.";
      }
      {
        assertion = cfg.allowedEmails != [ ];
        message = "Multica requires an explicit nonempty services.multica.allowedEmails allowlist.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.secretsFile && !(lib.hasPrefix "/nix/store/" cfg.secretsFile);
        message = "Multica secrets must be an absolute runtime path outside the Nix store.";
      }
      {
        assertion = builtins.match "[a-zA-Z0-9][a-zA-Z0-9.-]*" cfg.hostname != null;
        message = "Multica hostname must not contain a scheme, path, or port.";
      }
    ];
    networking.firewall.interfaces.multica0.allowedUDPPorts = [ 53 ];
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "multica-init-secrets" ''
        if [ "$#" -ne 0 ]; then echo "Usage: sudo multica-init-secrets" >&2; exit 2; fi
        exec ${pkgs.python3}/bin/python3 ${./multica/render-env.py} --init ${lib.escapeShellArg cfg.secretsFile}
      '')
    ];
    systemd.targets.multica = {
      description = "Multica prototype and isolated dependencies";
      wantedBy = [ "multi-user.target" ];
      requires = map unit names;
      after = map unit names;
    };
    virtualisation.oci-containers.containers = {
      multica-postgres = lib.recursiveUpdate (container "postgres") {
        image = "docker.io/pgvector/pgvector:pg17@sha256:ac08538c6f8b9904c33c8224c5e5706dbe760aca29db1d096972b4052c22a75d";
        environment = {
          POSTGRES_DB = "multica";
          POSTGRES_USER = "multica";
        };
        environmentFiles = [ "${runtime}/postgres.env" ];
        volumes = [ "multica-postgres-data:/var/lib/postgresql/data" ];
        extraOptions =
          (container "postgres").extraOptions ++ health "pg_isready -h 127.0.0.1 -U multica -d multica";
      };
      multica-backend = lib.recursiveUpdate (container "backend") {
        image = "ghcr.io/multica-ai/multica-backend:v0.6.1@sha256:824d42a4a4436efad96a2d15354a5512786c895672ac48fa05f9b2be4d8fbd5c";
        ports = [ "127.0.0.1:8180:8080" ];
        volumes = [ "multica-uploads:/app/data/uploads" ];
        environmentFiles = [ "${runtime}/backend.env" ];
        # Preserve upstream entrypoint: migrate up, then exec server.
        environment = {
          PORT = "8080";
          APP_ENV = "production";
          DO_NOT_TRACK = "1";
          FRONTEND_ORIGIN = origin;
          CORS_ALLOWED_ORIGINS = origin;
          MULTICA_APP_URL = origin;
          MULTICA_PUBLIC_URL = origin;
          MULTICA_DAEMON_SERVER_URL = origin;
          ALLOW_SIGNUP = "true";
          ALLOWED_EMAILS = lib.concatStringsSep "," cfg.allowedEmails;
          ALLOWED_EMAIL_DOMAINS = "";
          COOKIE_DOMAIN = "";
          MULTICA_DATABASE_STARTUP_TIMEOUT = "3m";
          MULTICA_DATABASE_CONNECT_TIMEOUT = "5s";
          REDIS_URL = "";
          S3_BUCKET = "";
          MULTICA_CLOUD_URL = "";
          MULTICA_VCS_INTEGRATION_ENABLED = "false";
        };
        extraOptions =
          (container "backend").extraOptions ++ health "wget -q -O /dev/null http://127.0.0.1:8080/readyz";
      };
      multica-frontend = lib.recursiveUpdate (container "frontend") {
        image = "ghcr.io/multica-ai/multica-web:v0.6.1@sha256:cc8260b0371661896dce52f968c8822d8275e0b275a43484347e5a59efffbb7c";
        ports = [ "127.0.0.1:3100:3000" ];
        environment = {
          HOSTNAME = "0.0.0.0";
          REMOTE_API_URL = "http://backend:8080";
          NEXT_PUBLIC_API_URL = "";
          NEXT_PUBLIC_WS_URL = "";
          DO_NOT_TRACK = "1";
        };
        extraOptions =
          (container "frontend").extraOptions ++ health "wget -q -O /dev/null http://127.0.0.1:3000/";
      };
    };
    # One origin, with WebSocket upgrades bypassing Next.js. No host firewall ports.
    services.nginx = {
      enable = true;
      virtualHosts.multica = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 3180;
          }
        ];
        serverName = cfg.hostname;
        locations = {
          "/" = route "3100";
          "= /health" = route "8180";
          "= /readyz" = route "8180";
          "= /healthz" = route "8180";
          "/ws" = websocket;
          "= /api/daemon/ws" = websocket;
        };
      };
    };
    systemd.services = lib.mkMerge [
      (lib.genAttrs (map (name: "podman-multica-${name}") names) (_: {
        requires = [
          "multica-env.service"
          "multica-network.service"
        ];
        after = [
          "multica-env.service"
          "multica-network.service"
        ];
        partOf = [
          "multica.target"
          "multica-env.service"
          "multica-network.service"
        ];
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "10s";
          TimeoutStartSec = lib.mkForce "300s";
        };
      }))
      {
        multica-env = {
          description = "Validate and render root-only Multica environments";
          partOf = [ "multica.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "multica";
            RuntimeDirectoryMode = "0700";
            UMask = "0077";
            ExecStart = "${pkgs.python3}/bin/python3 ${./multica/render-env.py} ${lib.escapeShellArg cfg.secretsFile} ${runtime}";
          };
        };
        multica-network = {
          description = "Create persistent Multica Podman network and volumes";
          partOf = [ "multica.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            if ! ${podman} network exists multica; then
              ${podman} network create --interface-name multica0 multica
            fi
            for volume in multica-postgres-data multica-uploads; do
              ${podman} volume create --ignore "$volume" >/dev/null
            done
          '';
        };
        podman-multica-backend = {
          requires = [ (unit "postgres") ];
          after = [ (unit "postgres") ];
          partOf = [ (unit "postgres") ];
        };
        podman-multica-frontend = {
          requires = [ (unit "backend") ];
          after = [ (unit "backend") ];
          partOf = [ (unit "backend") ];
        };
      }
    ];
  };
}
