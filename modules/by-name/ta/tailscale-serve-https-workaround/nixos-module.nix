{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.tailscale.serve;
  workaroundCfg = cfg.httpsWorkaround;
  tailscale = lib.getExe config.services.tailscale.package;

  mkEndpointCommand =
    serviceName: source: target:
    let
      portMatch = builtins.match "tcp:([0-9]+)" source;
      port = if portMatch == null then null else builtins.head portMatch;
    in
    if port == null then
      throw "Tailscale Serve HTTPS workaround only supports tcp:<port> endpoints, got ${source}"
    else
      ''
        ${tailscale} serve --yes --service=${lib.escapeShellArg "svc:${serviceName}"} --https=${port} --bg ${lib.escapeShellArg target}
      '';

  mkServiceCommands = serviceName: serviceCfg: ''
    ${tailscale} serve clear ${lib.escapeShellArg "svc:${serviceName}"}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (mkEndpointCommand serviceName) serviceCfg.endpoints
    )}
  '';

  applyConfig = pkgs.writeShellScript "tailscale-serve-https" ''
    set -euo pipefail

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkServiceCommands cfg.services)}
  '';
in
{
  options.services.tailscale.serve.httpsWorkaround.enable = lib.mkEnableOption ''
    the HTTPS listener workaround for Tailscale Services configuration files
  '';

  config = lib.mkIf workaroundCfg.enable {
    assertions = [
      {
        assertion = cfg.enable;
        message = "services.tailscale.serve.httpsWorkaround requires services.tailscale.serve.enable";
      }
    ];

    # Tailscale's version 0.0.1 Services format infers the listener protocol
    # from the upstream target protocol, so it cannot encode HTTPS -> HTTP.
    # https://github.com/tailscale/tailscale/issues/18381
    systemd.services.tailscale-serve.serviceConfig = {
      ExecStartPre = "${tailscale} wait --timeout=2m";
      ExecStart = lib.mkForce applyConfig;
    };
  };
}
