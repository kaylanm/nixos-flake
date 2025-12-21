{ config, pkgs, pkgsUnstable, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./homebox.nix
      ./memos.nix
      ./netboot.nix
      ./paperless.nix
      ./sane.nix
      #./synapse.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "optiplex3"; # Define your hostname.
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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };

  services.tailscale = {
    enable = true;
    package = pkgsUnstable.tailscale;
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
