#!/usr/bin/env bash
set -euo pipefail
umask 077

staging=${1:?staging directory required}
runtime=${2:?runtime directory required}
state=${3:?Mealie state directory required}

# Refuse an absent/inactive application instead of uploading a misleading backup.
systemctl is-active --quiet mealie.service
test -d "$state"
mkdir -p "$staging/snapshot"

# ExecStopPost sees this even if this process is killed during preparation.
touch "$runtime/restart-mealie"
systemctl stop mealie.service
runuser -u postgres -- pg_dump --format=custom --no-owner --no-acl mealie \
  > "$staging/snapshot/database.dump"
tar --create --file "$staging/snapshot/assets.tar" --directory "$state" .

# Upload/check can be slow: restore availability before contacting the repository.
systemctl start mealie.service
rm "$runtime/restart-mealie"
