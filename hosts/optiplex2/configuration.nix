{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./backup.nix
      ./minecraft-server.nix
      ./minecraft-server-bedrock.nix
      ./minecraft-server-atm9tts.nix
      ./minecraft-server-atm10.nix
      ./minecraft-server-atm10tts.nix
      ./minecraft-server-monifactory.nix
      ./minecraft-server-stoneblock3.nix
      ./minecraft-server-stoneblock4.nix
      ./minecraft-server-oceanblock2.nix
      ./minecraft-server-tekxit4.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "optiplex2"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Remove this after https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = pkgs.lib.mkForce false;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mike = {
    isNormalUser = true;
    description = "Michael Kaylan";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ neovim vim ];
    shell = pkgs.fish;
  };

  system.stateVersion = "23.11";
}
