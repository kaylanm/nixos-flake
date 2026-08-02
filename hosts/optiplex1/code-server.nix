{
  lib,
  config,
  pkgs,
  ...
}:

{
  services.code-server = {
    enable = true;
    disableWorkspaceTrust = true;
    disableTelemetry = true;
    disableGettingStartedOverride = true;
    auth = "none";
  };

  services.tailscale.serve.services.code.endpoints."tcp:443" = "http://localhost:4444";
}
