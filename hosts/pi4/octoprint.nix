{ config, lib, pkgs, pkgsUnstable, inputs, ... }:

let
  octoprint = pkgsUnstable.octoprint.override {
    packageOverrides = pyself: pysuper: {
      octoapp = pyself.buildPlugin rec {
        pname = "octoapp";
        version = "2.1.14";

        src = pkgs.fetchFromGitHub {
          owner = "crysxd";
          repo = "OctoApp-Plugin";
          rev = version;
          sha256 = "sha256-5SBM1QJ4Gh5kIgeFf5SrO6h+E0F/6ZNZ4kUYTTK+sAI=";
        };

        propagatedBuildInputs = with pysuper; [ pillow dnspython pycryptodome ];

        meta = with lib; {
          description = "OctoApp extension for OctoPrint";
          homepage = "https://github.com/crysxd/OctoApp-Plugin";
          license = licenses.agpl3Only;
          #maintainers = with maintainers; [ tri-ler ];
        };
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

