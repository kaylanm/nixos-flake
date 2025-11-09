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

  environment.systemPackages = (with pkgs; [
    inputs.colmena.packages.x86_64-linux.colmena
    ghostty
    grc
    fishPlugins.grc
    fishPlugins.bobthefisher
    python3
    xsane
    sane-frontends
  ]) ++ (with pkgsUnstable; [
    claude-code
    codex
    gemini-cli
    opencode
    yt-dlp
  ]);

  hardware.sane = {
    enable = true;
    netConf = "optiplex3";
    brscan4 = {
      enable = true;
      netDevices = {
        mfc7460dn = {
          model = "MFC-7460DN";
          name = "MFC-7460DN";
          nodename = "BRN001BA9AC6D3D";
        };
      };
    };
  };

  networking.hostName = "auriga-nixos";
  networking.firewall.enable = false;

  users.users.mike.shell = pkgs.fish;
  users.users.mike.extraGroups = [ "scanner" ];

  system.stateVersion = "23.11";
}
