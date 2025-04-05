{ lib, config, pkgs, ... }:

{
  config = {
    environment.systemPackages = with pkgs; [
      git
      vim
      neovim
      curl
      wget
      bat
      ripgrep
      fzf
      eza
      fd
      btop
      tmux
      screen
      zip
      unzip
      xz
      p7zip
      lsof
      nix-output-monitor
      nix-tree
      usbutils
      pciutils
    ];
  };
}