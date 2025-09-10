# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, pkgsUnstable, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./fix-modules.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.windows = {
    "nvme0n1p1" = {
      title = "Windows 11";
      efiDeviceHandle = "FS2";
      sortKey = "a_windows";
    };
  };

  networking.hostName = "auriga"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  time.hardwareClockInLocalTime = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Nvidia
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  boot.kernelPackages = pkgsUnstable.linuxPackages;

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [ brlaser ];

  hardware.printers.ensurePrinters = [
    {
      name = "Brother_MFC-7460DN";
      deviceUri = "http://BRN001BA9AC6D3D.home:631";
      model = "drv:///brlaser.drv/br7460d.ppd";
      ppdOptions = {
        media = "na_letter_8.5x11in";
        sides = "one-sided";
        job-sheets = "none, none";
      };
    }
  ];

  hardware.printers.ensureDefaultPrinter = "Brother_MFC-7460DN";

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  hardware.logitech.wireless.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  programs.hyprland.enable = true;
  programs.sway.enable = true;
  programs.localsend.enable = true;
  programs.steam = {
    enable = true;
    package = pkgsUnstable.steam;
  };

  services.tailscale = {
    enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mike = {
    isNormalUser = true;
    description = "Michael Kaylan";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      firefox
      google-chrome
      brave
      spotify
      wofi
      kitty
      alacritty
      vscode
      _1password-gui
      ghostty
      prismlauncher
      discord
      solaar
      gnome-extensions-cli

      (gnomeExtensions.wintile-beyond.overrideAttrs {
        src = pkgs.fetchFromGitHub {
          owner = "GrylledCheez";
          repo = "wintile-beyond";
          rev = "6c13592c9df9cbb23f33821f837a13bbccab1e79";
          sha256 = "sha256-yLPxzebc70e/d5KBRrluu4DMz6ZR6Sx+CGXfsXgwy8E=";
        };
      })

      gnomeExtensions.just-perfection
      gnomeExtensions.tophat
    ];
    shell = pkgs.fish;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [ ];

  system.stateVersion = "23.11";
}
