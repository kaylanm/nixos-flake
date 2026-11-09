{ config, lib, pkgs, pkgsUnstable, inputs, ... }:

let
  octoprint = pkgsUnstable.octoprint.override {
    packageOverrides = pyself: pysuper: {
      octoapp = pkgs.callPackage ../../pkgs/octoapp {
        inherit (pyself) buildPlugin;
        # Keep the existing pre-override dependency set exactly as before.
        pluginPythonPackages = pysuper;
      };
    };
  };
in
{
  services.octoprint = {
    enable = true;
    openFirewall = true;
    package = octoprint;
    plugins = plugins: with plugins; [ obico octoklipper octoapp octopod ];
  };

  users.groups.dialout.members = [ "octoprint" ];
  users.groups.video.members = [ "octoprint" ];
  users.groups.klipper.members = [ "octoprint" ];
}

