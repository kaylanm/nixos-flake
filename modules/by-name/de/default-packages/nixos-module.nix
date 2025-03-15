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
      tmux
      screen
      zip
      unzip
    ];
  };
}