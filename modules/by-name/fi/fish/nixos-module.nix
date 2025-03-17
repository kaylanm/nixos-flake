{ lib, config, pkgs, ... }:

{
  config = {
    programs.fish.enable = true;
    programs.fish.useBabelfish = true;

    users.users.root.shell = pkgs.fish;
  };
}