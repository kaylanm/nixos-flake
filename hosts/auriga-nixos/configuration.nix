# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  wsl.enable = true;
  wsl.defaultUser = "mike";

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    inputs.colmena.packages.x86_64-linux.colmena
    inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.yt-dlp
  ];

  networking.hostName = "auriga-nixos";
  networking.firewall.enable = false;

  system.stateVersion = "23.11";
}
