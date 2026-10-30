{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Adapted from block/buzz deploy/compose at 20ba95ed8906b2b7ae1819bdddadf82c09778097.
  # Handwritten units preserve health and successful bucket-init dependencies.
  cfg = config.services.buzz;
  runtime = "/run/buzz";
  podman = lib.getExe config.virtualisation.podman.package;
  images = {
    relay.image = "ghcr.io/block/buzz:main@sha256:f8a8a2c7988a9a35dcad63b0ea5663955023bce40f43102b5b0b2426422dbac1";
    initializer.image = "docker.io/pgsty/mc:RELEASE.2026-09-16T00-00-00Z@sha256:cfc83108c3abb371f8fb84d99c1fdc88f8c237e022409b0081fb7c0a3be634dd";
  };
  containerNames = [
    "postgres"
    "redis"
    "minio"
    "relay"
    "pairing"
  ];
  unit = name: "podman-buzz-${name}.service";
  health = command: [
    "--health-cmd=${command}"
    "--health-interval=5s"
    "--health-timeout=3s"
    "--health-retries=12"
    "--health-start-period=10s"
    "--health-on-failure=kill"
  ];
  container = name: {
    autoStart = false;
    networks = [ "buzz" ];
    environmentFiles = [ "${runtime}/${name}.env" ];
    podman.sdnotify = "healthy";
    extraOptions = [ "--network-alias=${name}" ];
  };
in
{
  options.services.buzz = {
    enable = lib.mkEnableOption "the Buzz relay and its private supporting containers";
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "HTTPS hostname routed to the relay's localhost port.";
    };
    ownerPublicKey = lib.mkOption {
      type = lib.types.strMatching "[0-9a-f]{64}";
      description = "Relay owner's Nostr public key in hexadecimal form.";
    };
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/buzz/secrets.env";
      description = "Absolute runtime path to the root-owned Buzz credentials file; never a Nix store path.";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = images.relay.image;
      description = "Pinned Buzz relay image.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.oci-containers.backend == "podman";
        message = "Buzz requires the Podman container backend.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.secretsFile && !(lib.hasPrefix "/nix/store/" cfg.secretsFile);
        message = "Buzz credentials must be supplied through an absolute runtime path outside the Nix store.";
      }
      {
        assertion = builtins.match "[a-zA-Z0-9][a-zA-Z0-9.-]*" cfg.hostname != null;
        message = "services.buzz.hostname must be a hostname without a URL scheme or path.";
      }
    ];

    # A fixed bridge name permits DNS only on this container network.
    networking.firewall.interfaces.buzz0.allowedUDPPorts = [ 53 ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "buzz-init-secrets" ''
        if [ "$#" -ne 0 ]; then
          echo "Usage: sudo buzz-init-secrets" >&2
          exit 2
        fi
        exec ${pkgs.python3}/bin/python3 ${./buzz/render-env.py} --init ${lib.escapeShellArg cfg.secretsFile}
      '')
    ];

    systemd.targets.buzz = {
      description = "Buzz relay and dependencies";
      wantedBy = [ "multi-user.target" ];
      requires = map unit containerNames;
      after = map unit containerNames;
    };

    virtualisation.oci-containers.containers = {
      buzz-postgres = lib.recursiveUpdate (container "postgres") {
        image = "docker.io/library/postgres:17.11-alpine@sha256:266d3c257594e195b309ae9d1805e54c788f1d7b375f56bf6c367aac6c917e7b";
        environment = {
          POSTGRES_DB = "buzz";
          POSTGRES_USER = "buzz";
          PGDATA = "/var/lib/postgresql/data/pgdata";
        };
        volumes = [ "buzz-postgres-data:/var/lib/postgresql/data" ];
        extraOptions =
          (container "postgres").extraOptions
          ++ health ''pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'';
      };
      buzz-redis = lib.recursiveUpdate (container "redis") {
        image = "docker.io/library/redis:7.4.12-alpine@sha256:8da19c7399dca900c6822a1cf30f9d2285585e2c4b457ff4095b0f4500054d3f";
        entrypoint = "/bin/sh";
        # Expansion happens inside the container, after its runtime env is loaded.
        cmd = [
          "-ec"
          ''exec /usr/local/bin/docker-entrypoint.sh redis-server --appendonly yes --requirepass "$REDIS_PASSWORD"''
        ];
        volumes = [ "buzz-redis-data:/data" ];
        extraOptions =
          (container "redis").extraOptions
          ++ health ''REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping | grep -q PONG'';
      };
      buzz-minio = lib.recursiveUpdate (container "minio") {
        image = "docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z@sha256:635197cb9f36d01bee221d34d1c7d7960f6a95c48b0b6c01d99cd13bdae51a46";
        cmd = [
          "server"
          "/data"
          "--console-address"
          ":9001"
        ];
        volumes = [ "buzz-minio-data:/data" ];
        extraOptions =
          (container "minio").extraOptions ++ health "curl -f http://127.0.0.1:9000/minio/health/live";
      };
      buzz-relay = lib.recursiveUpdate (container "relay") {
        image = cfg.image;
        ports = [ "127.0.0.1:3030:3000" ];
        volumes = [ "buzz-git-data:/data/git" ];
        environment = {
          BUZZ_BIND_ADDR = "0.0.0.0:3000";
          BUZZ_HEALTH_PORT = "8080";
          BUZZ_METRICS_PORT = "9102";
          BUZZ_S3_ENDPOINT = "http://minio:9000";
          BUZZ_S3_ADDRESSING_STYLE = "path";
          BUZZ_S3_BUCKET = "buzz-media";
          BUZZ_S3_REGION = "us-east-1";
          BUZZ_GIT_REPO_PATH = "/data/git";
          RELAY_URL = "wss://${cfg.hostname}";
          BUZZ_PAIRING_RELAY_URL = "wss://${cfg.hostname}/pair";
          RELAY_OWNER_PUBKEY = cfg.ownerPublicKey;
          BUZZ_MEDIA_BASE_URL = "https://${cfg.hostname}/media";
          BUZZ_CORS_ORIGINS = "https://${cfg.hostname}";
          BUZZ_REQUIRE_AUTH_TOKEN = "true";
          BUZZ_REQUIRE_RELAY_MEMBERSHIP = "true";
          BUZZ_ALLOW_NIP_OA_AUTH = "true";
          BUZZ_AUTO_MIGRATE = "true";
          BUZZ_GIT_CONFORMANCE_PROBE = "true";
          BUZZ_PUSH_ENABLED = "false";
          BUZZ_PUSH_GATEWAY_DELIVERY_URL = "https://push.buzz.xyz/v1/deliveries/apns";
          RUST_LOG = "buzz_relay=info,buzz_db=info,buzz_auth=info,buzz_pubsub=info,tower_http=info";
        };
        extraOptions =
          (container "relay").extraOptions
          ++ health ''bash -ec 'exec 3<>/dev/tcp/127.0.0.1/8080; printf "GET /_readiness HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n" >&3; grep -q "200 OK" <&3' '';
      };
      # Pairing uses ephemeral identities that cannot authenticate as community
      # members. Upstream ships a separate stateless relay in the same image.
      buzz-pairing = lib.recursiveUpdate (container "pairing") {
        image = cfg.image;
        entrypoint = "/usr/local/bin/buzz-pair-relay";
        ports = [ "127.0.0.1:3031:5000" ];
        environmentFiles = [ ];
        environment.BUZZ_PAIR_RELAY_BIND_ADDR = "0.0.0.0:5000";
        extraOptions =
          (container "pairing").extraOptions
          ++ health "bash -ec 'exec 3<>/dev/tcp/127.0.0.1/5000'";
      };
    };

    systemd.services = lib.mkMerge [
      (lib.genAttrs (map (name: "podman-buzz-${name}") containerNames) (_: {
        requires = [
          "buzz-env.service"
          "buzz-network.service"
        ];
        after = [
          "buzz-env.service"
          "buzz-network.service"
        ];
        partOf = [
          "buzz.target"
          "buzz-env.service"
          "buzz-network.service"
        ];
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "10s";
          TimeoutStartSec = lib.mkForce "300s";
        };
      }))
      {
        buzz-env = {
          description = "Validate and extract Buzz runtime environment files";
          partOf = [ "buzz.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "buzz";
            RuntimeDirectoryMode = "0700";
            UMask = "0077";
            ExecStart = "${pkgs.python3}/bin/python3 ${./buzz/render-env.py} ${lib.escapeShellArg cfg.secretsFile} ${runtime}";
          };
        };

        buzz-network = {
          description = "Create Buzz's persistent Podman network and volumes";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          partOf = [ "buzz.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            if ! ${podman} network exists buzz; then
              ${podman} network create --interface-name buzz0 buzz
            fi
            for volume in postgres redis minio git; do
              ${podman} volume create --ignore "buzz-$volume-data" >/dev/null
            done
          '';
        };

        buzz-minio-init = {
          description = "Create Buzz's private object storage bucket";
          requires = [
            (unit "minio")
            "buzz-env.service"
          ];
          after = [
            (unit "minio")
            "buzz-env.service"
          ];
          partOf = [
            "buzz.target"
            (unit "minio")
            "buzz-env.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "300s";
            ExecStopPost = "${podman} rm --force --ignore buzz-minio-init";
          };
          script = ''
            ${podman} run --rm --replace --name buzz-minio-init --network buzz \
              --env-file ${runtime}/minio-init.env --entrypoint /bin/sh ${images.initializer.image} -euc '
                mc alias set local http://minio:9000 "$BUZZ_S3_ACCESS_KEY" "$BUZZ_S3_SECRET_KEY" >/dev/null
                mc mb --ignore-existing "local/$BUZZ_S3_BUCKET"
                mc anonymous set none "local/$BUZZ_S3_BUCKET"
              '
          '';
        };
        podman-buzz-relay = {
          requires = [
            "buzz-minio-init.service"
            (unit "postgres")
            (unit "redis")
          ];
          after = [
            "buzz-minio-init.service"
            (unit "postgres")
            (unit "redis")
          ];
          partOf = [
            "buzz-minio-init.service"
            (unit "postgres")
            (unit "redis")
          ];
        };
      }
    ];
  };
}
