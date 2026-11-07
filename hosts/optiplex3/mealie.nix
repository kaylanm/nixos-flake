{ ... }:

{
  imports = [ ./mealie/backup.nix ];

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9000;
    openFirewall = false;
    database.createLocally = true;

    settings = {
      BASE_URL = "https://mealie.manx-in.ts.net";
      ALLOW_SIGNUP = "false";
      # Start with local accounts; verify tsidp claims before enabling SSO.
      OIDC_AUTH_ENABLED = "false";
    };
  };
}
