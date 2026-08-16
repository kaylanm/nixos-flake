{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    dmidecode
    gcc
    ghostty.terminfo
    lshw
    pciutils
    usbutils
  ];
}
