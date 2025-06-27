{ lib, config, pkgs, pkgsUnstable, inputs, ... }:

{
  services.caddy = {
    enable = true;
    # TODO: Switch when available
    # environmentFile = "/etc/caddy/environment";
    globalConfig = ''
      tailscale {
        ephemeral true
      }
    '';
    package = pkgsUnstable.caddy.withPlugins {
      plugins = [ "github.com/tailscale/caddy-tailscale@v0.0.0-20250207163903-69a970c84556" ];
      hash = "sha256-mGJcpvs3XqW5UNUkIADdz/poyr96cq+SzCFdKyWdMKY=";
    };
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = [ "/etc/caddy/environment" ];
}
