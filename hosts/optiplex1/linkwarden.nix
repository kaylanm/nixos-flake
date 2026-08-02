{
  config,
  pkgs,
  inputs,
  ...
}:

{
  services.linkwarden = {
    enable = true;
    enableRegistration = true;
    environment = {
      NEXTAUTH_URL = "https://linkwarden.manx-in.ts.net";
    };
    port = 2293;
    secretFiles = {
      NEXTAUTH_SECRET = "/etc/nextauth-secret";
    };
  };
}
