{ config, pkgs, ... }:

let
  clientConfig."m_homeserver".base_url = "https://matrix.kaylan.dev";
  serverConfig."m_server" = "https://matrix.kaylan.dev:443";
  serverConfig."" = "";
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '${builtins.toJSON data}';
  '';
in
{
  #services.postgresql.enable = true;

  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [ "/etc/synapse-conf" ];
    settings = {
      server_name = "kaylan.dev";
      public_baseurl = "https://matrix.kaylan.dev";
      database.name = "sqlite3";
      listeners = [
        {
          port = 8008;
          bind_addresses = [ "::1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [ "client" "federation" ];
              compress = true;
            }
          ];
        }
      ];
    };
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "kaylan.dev" = {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
        locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
        locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
        #locations."/.well-known/matrix".proxyPass = "http://[::1]:8008";
      };
      "matrix.kaylan.dev" = {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
        locations."/".extraConfig = ''
          return 404;
        '';
        locations."/_matrix".proxyPass = "http://[::1]:8008";
        locations."/_synapse/client".proxyPass = "http://[::1]:8008";
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "mike+acme@kaylanm.net";
      dnsProvider = "route53";
      environmentFile = "/etc/acme-env";
    };
  };

  services.livekit = {
    enable = true;
    openFirewall = true;
    keyFile = "/etc/livekit-keys";
  };

  services.lk-jwt-service = {
    enable = true;
    keyFile = "/etc/livekit-keys";
    livekitUrl = "ws://localhost:7880/";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
