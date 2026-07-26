{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.flakeAutoUpgrade;

  updateUserExists = builtins.hasAttr cfg.user config.users.users;
  updateUserHome = if updateUserExists then config.users.users.${cfg.user}.home else "/var/empty";

  updateCheckout = pkgs.writeShellApplication {
    name = "update-nixos-flake-checkout";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gitMinimal
      pkgs.openssh
      pkgs.util-linux
    ];
    text = ''
      if ! repository="$(readlink --canonicalize-existing ${lib.escapeShellArg cfg.path})"; then
        echo "Cannot resolve the NixOS flake checkout at ${cfg.path}" >&2
        exit 1
      fi

      run_as_update_user() {
        runuser --user ${lib.escapeShellArg cfg.user} -- env \
          HOME=${lib.escapeShellArg updateUserHome} \
          USER=${lib.escapeShellArg cfg.user} \
          LOGNAME=${lib.escapeShellArg cfg.user} \
          GIT_SSH_COMMAND=${lib.escapeShellArg "${pkgs.openssh}/bin/ssh -o BatchMode=yes"} \
          "$@"
      }

      if [ "$(run_as_update_user git -C "$repository" rev-parse --is-inside-work-tree)" != "true" ]; then
        echo "$repository is not a Git working tree" >&2
        exit 1
      fi

      current_branch="$(run_as_update_user git -C "$repository" branch --show-current)"
      if [ "$current_branch" != ${lib.escapeShellArg cfg.branch} ]; then
        echo "Refusing to update $repository: expected branch ${cfg.branch}, found $current_branch" >&2
        exit 1
      fi

      if ! run_as_update_user git -C "$repository" diff --quiet HEAD --; then
        echo "Refusing to update $repository because it has modified tracked files" >&2
        exit 1
      fi

      echo "Fetching ${cfg.remote}/${cfg.branch} into $repository"
      remote_branch=${lib.escapeShellArg "refs/heads/${cfg.branch}"}
      remote_ref=${lib.escapeShellArg "refs/remotes/${cfg.remote}/${cfg.branch}"}
      run_as_update_user git -C "$repository" fetch --prune \
        ${lib.escapeShellArg cfg.remote} "$remote_branch:$remote_ref"

      if ! run_as_update_user git -C "$repository" merge-base --is-ancestor HEAD "$remote_ref"; then
        echo "Refusing to update $repository because its branch has diverged from ${cfg.remote}/${cfg.branch}" >&2
        exit 1
      fi

      run_as_update_user git -C "$repository" merge --ff-only "$remote_ref"
    '';
  };
in
{
  options.services.flakeAutoUpgrade = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to pull and periodically activate this host's local NixOS flake.";
    };

    path = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "Path, which may be a symlink, to the local flake checkout.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mike";
      description = "User that owns the checkout and has credentials for its Git remote.";
    };

    remote = lib.mkOption {
      type = lib.types.str;
      default = "origin";
      description = "Git remote from which to fetch updates.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git branch to fast-forward before rebuilding.";
    };

    configuration = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "NixOS configuration attribute to select from the flake.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = updateUserExists;
        message = "services.flakeAutoUpgrade.user '${cfg.user}' is not a configured user";
      }
    ];

    system.autoUpgrade = {
      enable = true;
      flake = lib.mkDefault "${cfg.path}#${cfg.configuration}";
      # Renovate owns flake.lock; the machine only consumes committed updates.
      upgrade = lib.mkDefault false;
      operation = lib.mkDefault "switch";
      dates = lib.mkDefault "daily";
      randomizedDelaySec = lib.mkDefault "1h";
      fixedRandomDelay = lib.mkDefault true;
      persistent = lib.mkDefault true;
      allowReboot = lib.mkDefault false;
    };

    systemd.services.nixos-upgrade.preStart = lib.getExe updateCheckout;
  };
}
