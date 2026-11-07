"""Evaluate the real flake and dormant pi4 module, without building systems."""
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NixScopeTests(unittest.TestCase):
    def test_octoapp_uses_the_same_scope_as_the_pi4_module(self):
        expression = r'''
          let
            f = builtins.getFlake ("path:" + builtins.getEnv "PACKAGE_UPDATE_TEST_ROOT");
            pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
            pkgsUnstable = f.inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
            module = import (f.outPath + "/hosts/pi4/octoprint.nix") {
              inherit pkgs pkgsUnstable;
              inherit (pkgs) lib;
              inputs = f.inputs;
              config = {};
            };
            standalone = f.packages.x86_64-linux.octoapp;
            scoped = module.services.octoprint.package.python.pkgs.octoapp;
            discovered = (import (f.outPath + "/pkgs") { inherit (pkgs) callPackage; }).octoapp;
          in {
            sameScope = standalone.drvPath == scoped.drvPath;
            localVersionPosition = builtins.unsafeGetAttrPos "version" standalone;
            localSourcePosition = builtins.unsafeGetAttrPos "src" standalone;
            dependencies = map (p: p.pname) standalone.propagatedBuildInputs;
            autoDiscoveryWorks = builtins.isString discovered.drvPath;
          }
        '''
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--no-write-lock-file", "--expr", expression],
            env={**os.environ, "PACKAGE_UPDATE_TEST_ROOT": str(ROOT)},
            text=True, capture_output=True, check=True,
        )
        data = json.loads(result.stdout)
        self.assertTrue(data["sameScope"], "flake target differs from OctoPrint's plugin scope")
        self.assertTrue(data["autoDiscoveryWorks"])
        self.assertEqual(data["dependencies"], ["pillow", "dnspython", "pycryptodome", "OctoPrint", "python3"])
        for key in ["localVersionPosition", "localSourcePosition"]:
            self.assertTrue(data[key]["file"].endswith("/pkgs/octoapp/default.nix"))


if __name__ == "__main__":
    unittest.main()
