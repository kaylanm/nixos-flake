{ lib, config, pkgs, ... }:

{
  programs.fish.enable = true;
  programs.fish.useBabelfish = true;

  users.users.root.shell = pkgs.fish;
}