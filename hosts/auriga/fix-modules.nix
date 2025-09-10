{ config, lib, ... }:

let
  inherit (config.boot.kernelPackages) kernel;
in
{
  system.modulesTree = [
    (lib.getOutput "modules" kernel)
  ];
}

