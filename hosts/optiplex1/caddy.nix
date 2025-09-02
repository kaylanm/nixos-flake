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
      hash = "sha256-r7wX9zZ9b7ct0N0PFkKqn8Nb0ywRR4nIaKOvswFp/o4=";
    };
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = [ "/etc/caddy/environment" ];
}
