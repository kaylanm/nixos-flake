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
}
