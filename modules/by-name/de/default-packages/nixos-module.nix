{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    dmidecode
    gcc
    lshw
    pciutils
    usbutils
  ];
}
