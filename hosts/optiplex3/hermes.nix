{
  config,
  inputs,
  pkgs,
  ...
}:

let
  hermes = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hermes-agent;
  tools = pkgs.buzz-agent-tools;
  credentialPython = pkgs.python3.withPackages (ps: [
    ps.bech32
    ps.coincurve
  ]);
  registerAgent = pkgs.writeShellApplication {
    name = "buzz-register-hermes";
    text = ''
      exec ${credentialPython}/bin/python3 ${./hermes/register-agent.py} \
        --relay https://${config.services.buzz.hostname} \
        --owner ${config.services.buzz.ownerPublicKey} "$@"
    '';
  };
  provisionIdentity = pkgs.writeShellApplication {
    name = "buzz-provision-hermes";
    text = ''
      exec ${credentialPython}/bin/python3 ${./hermes/provision-identity.py} \
        --owner ${config.services.buzz.ownerPublicKey} "$@"
    '';
  };
  state = "/var/lib/hermes";
in
{
  environment.systemPackages = [
    hermes
    tools
    registerAgent
    provisionIdentity
  ];

  users.groups.hermes = { };
  users.users.hermes = {
    isSystemUser = true;
    group = "hermes";
    home = state;
    description = "Hermes agent for Buzz";
  };

  systemd.tmpfiles.rules = [
    "d ${state} 0700 hermes hermes -"
    "d ${state}/workspace 0700 hermes hermes -"
    "d ${state}/.hermes 0700 hermes hermes -"
  ];

  systemd.services.hermes-dashboard = {
    description = "Hermes web dashboard";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "tsidp.service"
    ];
    after = [
      "network-online.target"
      "tsidp.service"
    ];

    path = config.systemd.services.hermes.path;
    environment = {
      HOME = state;
      HERMES_HOME = "${state}/.hermes";
      HERMES_DASHBOARD_PUBLIC_URL = "https://hermes.manx-in.ts.net";
      HERMES_DASHBOARD_OIDC_ISSUER = "https://idp.manx-in.ts.net";
      HERMES_DASHBOARD_OIDC_SCOPES = "openid profile email";
    };

    serviceConfig = {
      User = "hermes";
      Group = "hermes";
      StateDirectory = "hermes";
      StateDirectoryMode = "0700";
      WorkingDirectory = "${state}/workspace";
      EnvironmentFile = "/etc/hermes/secrets.env";
      # Tailscale Services terminates HTTPS and proxies to this local listener.
      ExecStart = "${hermes}/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open";
      Restart = "on-failure";
      RestartSec = "15s";
      RestartPreventExitStatus = [ 78 ];
      TimeoutStopSec = "30s";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
    };
  };

  systemd.services.hermes = {
    description = "Hermes agent connected to Buzz through ACP";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "buzz.target"
    ];
    after = [
      "network-online.target"
      "buzz.target"
    ];
    unitConfig.StartLimitIntervalSec = 0;

    path = [
      tools
      hermes
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.ripgrep
      pkgs.curl
    ];
    environment = {
      HOME = state;
      HERMES_HOME = "${state}/.hermes";
      HERMES_ACP_SKIP_CONFIGURED_MCP = "1";
      BUZZ_RELAY_URL = "wss://${config.services.buzz.hostname}";
      BUZZ_ACP_AGENT_COMMAND = "${hermes}/bin/hermes-acp";
      # hermes-acp is already the ACP entry point; Goose's default "acp" arg is invalid.
      BUZZ_ACP_AGENT_ARGS = "";
      BUZZ_ACP_MCP_COMMAND = "${tools}/bin/buzz-dev-mcp";
      BUZZ_ACP_AGENT_OWNER = config.services.buzz.ownerPublicKey;
      BUZZ_ACP_RESPOND_TO = "owner-only";
      BUZZ_ACP_DISPLAY_NAME = "Hermes";
      BUZZ_ACP_AGENTS = "1";
      BUZZ_ACP_HEARTBEAT_INTERVAL = "0";
    };

    serviceConfig = {
      User = "hermes";
      Group = "hermes";
      StateDirectory = "hermes";
      StateDirectoryMode = "0700";
      WorkingDirectory = "${state}/workspace";
      EnvironmentFile = "/etc/hermes/secrets.env";
      ExecStart = "${tools}/bin/buzz-acp";
      Restart = "on-failure";
      RestartSec = "15s";
      TimeoutStopSec = "30s";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
    };
  };
}
