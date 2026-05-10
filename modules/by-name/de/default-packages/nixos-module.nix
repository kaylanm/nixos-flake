{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gcc
    lshw
    pciutils
    usbutils
  ];
}
