{ config, pkgs, ... }:

{
  security.acme = {
    acceptTerms = true;
    defaults.email = "mike+acme@kaylanm.net";
    certs."kaylan.dev" = {
      domain = "*.kaylan.dev";
      dnsProvider = "route53";
      environmentFile = "/etc/acme-env";
    };
  };
}
