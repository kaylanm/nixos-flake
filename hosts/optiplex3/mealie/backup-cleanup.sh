#!/usr/bin/env bash
set -euo pipefail

staging=${1:?staging directory required}
runtime=${2:?runtime directory required}

# NixOS restic uses ExecStopPost, which also runs after a failed ExecStartPre.
# Preserve the marker and snapshot if recovery fails; report a failed unit.
if test -e "$runtime/restart-mealie"; then
  systemctl start mealie.service
  rm "$runtime/restart-mealie"
fi
rm -rf -- "$staging/snapshot"
