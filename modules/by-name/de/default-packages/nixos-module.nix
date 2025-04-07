{ lib, config, pkgs, withGUI ? false, ... }:

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
      nixfmt-rfc-style
    ] ++ lib.optionals pkgs.stdenv.isLinux [
      usbutils
      pciutils
    ] ++ lib.optionals withGUI [
      nerdfonts
    ];
  };
}