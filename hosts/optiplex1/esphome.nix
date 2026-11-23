{ pkgs, ... }:

{
  services.esphome = {
    enable = true;
    remoteBuildAddress = "127.0.0.1";
  };

  # Add bash so that compiles which need it succeed
  # See https://github.com/NixOS/nixpkgs/issues/586902
  systemd.services.esphome.path = [ pkgs.bash ];

  # esphome cli for interactive use
  environment.systemPackages = [ pkgs.esphome ];
}
