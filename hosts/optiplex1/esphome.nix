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

  # esphome cli for interactive use
  environment.systemPackages = [ esphomePkg ];
}
