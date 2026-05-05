{ config, pkgs, inputs, ... }:

{
  services.matter-server = {
    enable = true;
  };
}
