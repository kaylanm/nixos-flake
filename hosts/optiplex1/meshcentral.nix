{
  lib,
  config,
  pkgs,
  ...
}:

{
  services.meshcentral = {
    enable = true;
  };

  services.tailscale.serve.services.meshcentral.endpoints."tcp:443" =
    "https+insecure://localhost:1025";
}
