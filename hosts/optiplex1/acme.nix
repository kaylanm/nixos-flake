{ config, pkgs, ... }:

{
  security.acme = {
    acceptTerms = true;
    defaults.email = "mike+acme@kaylanm.net";
    certs."kaylan.dev" = {
      domain = "*.kaylan.dev";
      dnsProvider = "route53";
      environmentFile = "/etc/acme-env";
      postRun = ''
        cp key.pem /var/lib/ssl/privkey.pem
        cp fullchain.pem /var/lib/ssl/fullchain.pem
      '';
      reloadServices = [
        "docker-homeAssistant.service"
      ];
    };
  };
}
