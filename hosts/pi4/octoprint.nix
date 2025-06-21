{ config, lib, pkgs, inputs, ... }:

{
  services.octoprint = {
    enable = true;
    openFirewall = true;
    plugins = plugins: with plugins; [ obico octopod ];
  };

  users.groups.dialout.members = [ "octoprint" ];
  users.groups.video.members = [ "octoprint" ];
}

