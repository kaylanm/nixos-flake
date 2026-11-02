{ pkgs, ... }:

{
  services.esphome = {
    enable = true;
    remoteBuildAddress = "127.0.0.1";
  };

  # esphome cli for interactive use
  environment.systemPackages = [ pkgs.esphome ];
}
