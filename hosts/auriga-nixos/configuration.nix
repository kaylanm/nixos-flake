# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{
  config,
  pkgs,
  pkgsMaster,
  inputs,
  ...
}:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  wsl.enable = true;
  wsl.defaultUser = "mike";

  programs.nix-ld.enable = true;

  environment.systemPackages =
    (with pkgs; [
      fishPlugins.grc
      fishPlugins.bobthefisher
      ghostty
      grc
      inputs.colmena.packages.x86_64-linux.colmena
      python3
      sane-frontends
      xsane
    ])
    ++ (with pkgsMaster; [
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
