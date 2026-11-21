# Evaluate the actual host both disabled and explicitly opted in; no activation.
let
  flake = builtins.getFlake (toString ../../..);
  lib = flake.inputs.nixpkgs-unstable.lib;
  base = flake.nixosConfigurations.optiplex3;
  disabled = base.config;
  enabled =
    (base.extendModules {
      modules = [
        {
          services.multica = {
            enable = lib.mkForce true;
            hostname = "multica.manx-in.ts.net";
            allowedEmails = [ "operator@example.invalid" ];
          };
        }
      ];
    }).config;
  rejected =
    settings:
    builtins.any (a: !a.assertion)
      (base.extendModules {
        modules = [
          {
            services.multica = {
              enable = lib.mkForce true;
              allowedEmails = [ "operator@example.invalid" ];
            }
            // settings;
          }
        ];
      }).config.assertions;
  containers = enabled.virtualisation.oci-containers.containers;
in
assert !(disabled.services.multica.enable or false);
assert !(disabled.systemd.targets ? multica);
assert !(disabled.systemd.services ? multica-env);
assert !(disabled.virtualisation.oci-containers.containers ? multica-backend);
assert !(disabled.services.nginx.enable);
assert rejected { allowedEmails = [ ]; };
assert rejected { secretsFile = "/nix/store/unsafe-secret"; };
assert rejected { secretsFile = "relative.env"; };
assert rejected { hostname = "https://invalid/path"; };
assert enabled.services.multica.enable;
assert containers.multica-postgres.ports == [ ];
assert containers.multica-backend.ports == [ "127.0.0.1:8180:8080" ];
assert containers.multica-frontend.ports == [ "127.0.0.1:3100:3000" ];
assert containers.multica-backend.environment.APP_ENV == "production";
assert containers.multica-backend.environment.DO_NOT_TRACK == "1";
assert containers.multica-backend.environment.ALLOWED_EMAILS == "operator@example.invalid";
assert containers.multica-backend.environment.ALLOWED_EMAIL_DOMAINS == "";
assert !(containers.multica-backend.environment ? JWT_SECRET);
assert !(containers.multica-backend.environment ? MULTICA_DEV_VERIFICATION_CODE);
assert containers.multica-frontend.environment.REMOTE_API_URL == "http://backend:8080";
assert builtins.all (c: builtins.match ".*@sha256:[0-9a-f]{64}" c.image != null) (
  builtins.attrValues (lib.filterAttrs (n: _: lib.hasPrefix "multica-" n) containers)
);
assert builtins.elem "podman-multica-postgres.service"
  enabled.systemd.services.podman-multica-backend.requires;
assert builtins.elem "podman-multica-backend.service"
  enabled.systemd.services.podman-multica-frontend.after;
assert builtins.all (a: a.assertion) enabled.assertions;
{
  disabled = disabled.system.build.toplevel.drvPath;
  enabled = enabled.system.build.toplevel.drvPath;
  passed = true;
}
