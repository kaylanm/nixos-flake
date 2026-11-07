# Standalone, deliberately NOT added to the flake or any host configuration.
{ pkgs, hermes }:
let
  source = pkgs.lib.cleanSourceWith {
    src = ./.;
    filter = path: type:
      builtins.baseNameOf path != "__pycache__"
      && !(pkgs.lib.hasSuffix ".pyc" path);
  };
in
pkgs.runCommand "hermes-tailscale-auth-prototype" {
  nativeBuildInputs = [ pkgs.python3 pkgs.makeWrapper ];
  HERMES_INSTALLED_LAUNCHER = "${hermes}/bin/hermes";
} ''
  cp -r ${source} prototype
  chmod -R u+w prototype
  python3 prototype/installed.py test
  mkdir -p "$out/lib/hermes-tailscale-auth" "$out/bin"
  cp prototype/*.py prototype/README.md "$out/lib/hermes-tailscale-auth/"
  makeWrapper ${pkgs.python3}/bin/python3 "$out/bin/hermes-tailscale-auth-prototype" \
    --add-flags "$out/lib/hermes-tailscale-auth/installed.py" \
    --set HERMES_INSTALLED_LAUNCHER ${hermes}/bin/hermes
''
