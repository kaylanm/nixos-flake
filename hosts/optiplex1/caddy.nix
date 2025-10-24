{ lib, config, pkgs, pkgsUnstable, inputs, ... }:

{
  services.caddy = {
    enable = true;
    enableReload = false;
    environmentFile = "/etc/caddy/environment";
    globalConfig = ''
      tailscale {
        ephemeral true
      }

      grace_period 10s
    '';
    package = pkgsUnstable.caddy.withPlugins {
      plugins = [ "github.com/tailscale/caddy-tailscale@v0.0.0-20250207163903-69a970c84556" ];
      hash = "sha256-RBOL8YKZdF6WC2aK7zrErPabo8vC12EVLLM7G5csLcc=";
    };
  };
}
