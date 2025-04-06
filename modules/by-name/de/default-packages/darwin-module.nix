{ pkgs, inputs, ... }:

{
  imports = [
    ./nixos-module.nix
  ];

  environment.systemPackages = with pkgs; [

  ];
}
