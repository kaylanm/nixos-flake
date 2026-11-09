# Scope matters: buildPlugin and Python dependencies must come from OctoPrint's
# Python package set, not the top-level python3Packages.
{
  lib,
  fetchFromGitHub,
  octoprint,
  pluginPythonPackages ? octoprint.python.pkgs,
  buildPlugin ? pluginPythonPackages.buildPlugin,
}:

let
  plugin = rec {
    pname = "octoapp";
    version = "2.1.14";
    format = "setuptools";

    src = fetchFromGitHub {
      owner = "crysxd";
      repo = "OctoApp-Plugin";
      rev = version;
      sha256 = "sha256-5SBM1QJ4Gh5kIgeFf5SrO6h+E0F/6ZNZ4kUYTTK+sAI=";
    };

    propagatedBuildInputs = with pluginPythonPackages; [ pillow dnspython pycryptodome ];

    meta = with lib; {
      description = "OctoApp extension for OctoPrint";
      homepage = "https://github.com/crysxd/OctoApp-Plugin";
      license = licenses.agpl3Only;
    };
  };
in
# buildPlugin reconstructs version in nixpkgs; retain the local source position
# for nix-update without rebuilding with a different Python dependency set.
(buildPlugin plugin) // { inherit (plugin) version; }
