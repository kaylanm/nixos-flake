# This file is automatically called by the overlay to import all custom packages
# Each subdirectory in this folder should be a Nix package
# Example structure:
# /pkgs/
#   /my-package/
#     default.nix
#     my-script.sh
#     ...

{ callPackage }:

# Import all packages from subdirectories
# Each subdirectory should contain a default.nix file that defines a package
let
  # Helper function to get all subdirectories
  getDirs = path: with builtins;
    map (n: path + "/${n}")
      (filter (n: builtins.pathExists (path + "/${n}/default.nix"))
        (attrNames (readDir path)));
  
  # Import all packages from subdirectories
  packagesList = if builtins.pathExists ./. then getDirs ./. else [];
  
  # Create an attribute set with all packages
  packages = builtins.listToAttrs
    (map (p: { 
      name = builtins.baseNameOf p; 
      value = callPackage p {}; 
    }) packagesList);
in
  packages
