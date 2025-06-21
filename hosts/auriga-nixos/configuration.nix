# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, pkgs, pkgsUnstable, inputs, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  wsl.enable = true;
  wsl.defaultUser = "mike";

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    inputs.colmena.packages.x86_64-linux.colmena
    pkgsUnstable.yt-dlp
    ghostty
    grc
    fishPlugins.grc
    fishPlugins.bobthefisher
    python3
  ];

  networking.hostName = "auriga-nixos";
  networking.firewall.enable = false;

  users.users.mike.shell = pkgs.fish;

  system.stateVersion = "23.11";
}
