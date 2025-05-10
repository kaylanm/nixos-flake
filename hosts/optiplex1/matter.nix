{ config, pkgs, pkgsUnstable, inputs, ... }:

{
  services.matter-server = {
    enable = true;
    package = pkgsUnstable.python-matter-server;
  };
}
