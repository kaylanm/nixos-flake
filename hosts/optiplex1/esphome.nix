{
  config,
  pkgs,
  inputs,
  ...
}:

let
  esphomePkg = pkgs.esphome;
in
{
  services.esphome = {
    enable = true;
    package = esphomePkg;
  };

  services.tailscale.serve.services.esphome.endpoints."tcp:443" = "http://localhost:6052";

  # esphome cli for interactive use
  environment.systemPackages = [ esphomePkg ];
}
