{
  flake.modules.nixos.default-packages =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        gcc
        lshw
        pciutils
        usbutils
      ];
    };
}
