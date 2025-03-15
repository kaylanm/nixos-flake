{ lib, config, pkgs, ... }:

{
  config = {
    programs.fish.enable = true;

    users.users.root.shell = pkgs.fish;
  };
}