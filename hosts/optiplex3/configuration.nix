{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./buzz.nix
    ./hermes.nix
    ./homebox.nix
    ./memos.nix
    ./multica.nix
    ./netboot.nix
    ./outline.nix
    ./paperless.nix
    ./rustdesk.nix
    ./sane.nix
    ./tsidp.nix
    #./synapse.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "optiplex3"; # Define your hostname.
  services.buzz = {
    enable = true;
    hostname = "buzz.manx-in.ts.net";
    # npub10pn4w5qhvr5vu3crkr44sdc2far2jw0ljle8uqs9lzrrzeqvacqskzky6a
    ownerPublicKey = "786757501760e8ce4703b0eb58370a4f46a939ff97f27e0205f88631640cee01";
  };
  # Disabled prototype; see multica/README.md before opting in.
  services.multica.enable = false;
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  programs.llm-agents.enable = true;

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
    useRoutingFeatures = "server";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mike = {
    isNormalUser = true;
    description = "Michael Kaylan";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      neovim
      vim
    ];
    shell = pkgs.fish;
  };

  system.stateVersion = "23.11";
}
