#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/opt/aqura-web"
RELEASES_DIR="$APP_ROOT/releases"
SHARED_DIR="$APP_ROOT/shared"
SERVICE_NAME="aqura-web.service"
NPM_CACHE_DIR="$APP_ROOT/.npm-cache"

archive_path="${1:?Usage: activate-release.sh <archive> <release-id> <revision> [health-url]}"
release_id="${2:?Usage: activate-release.sh <archive> <release-id> <revision> [health-url]}"
revision="${3:?Usage: activate-release.sh <archive> <release-id> <revision> [health-url]}"
health_url="${4:-http://localhost/}"

# The local server runs the app on Node 20 (same as production) installed at /opt/node20.
if [[ -x /opt/node20/bin/npm ]]; then
  export PATH="/opt/node20/bin:$PATH"
fi

if [[ ! "$release_id" =~ ^[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z$ ]]; then
  echo "Invalid release ID: $release_id" >&2
  exit 2
fi
if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Invalid Git revision: $revision" >&2
  exit 2
fi
if [[ ! -f "$archive_path" ]]; then
  echo "Release archive not found: $archive_path" >&2
  exit 2
fi

mkdir -p "$RELEASES_DIR" "$SHARED_DIR"
exec 9>"$APP_ROOT/deploy.lock"
flock --wait 600 9

if [[ -f "$APP_ROOT/current/REVISION" ]] && [[ "$(<"$APP_ROOT/current/REVISION")" == "$revision" ]]; then
  rm -f -- "$archive_path"
  echo "ALREADY_DEPLOYED=$revision"
  exit 0
fi

release_dir="$RELEASES_DIR/$release_id"
if [[ -e "$release_dir" ]]; then
  echo "Release already exists: $release_dir" >&2
  exit 2
fi

previous_release=""
if [[ -L "$APP_ROOT/current" ]]; then
  previous_release="$(readlink -f "$APP_ROOT/current")"
fi

mkdir "$release_dir"
cleanup_failed_release() {
  rm -rf -- "$NPM_CACHE_DIR"
  if [[ -d "$release_dir" && "$(readlink -f "$release_dir")" == "$RELEASES_DIR/"* ]]; then
    rm -rf -- "$release_dir"
  fi
}
trap cleanup_failed_release ERR

tar -xzf "$archive_path" -C "$release_dir"
test -f "$release_dir/build/index.js"
test -f "$release_dir/package.json"
test -f "$release_dir/websocket-polyfill.mjs"
test "$(<"$release_dir/REVISION")" = "$revision"

cd "$release_dir"
npm install --cache "$NPM_CACHE_DIR" --omit=dev --no-audit --no-fund --legacy-peer-deps
chown -R root:www-data "$release_dir"

ln -sfn "$release_dir" "$APP_ROOT/current"
systemctl restart "$SERVICE_NAME"

healthy=false
for attempt in {1..15}; do
  if curl --fail --silent --show-error --max-time 10 \
    --output /dev/null "$health_url"; then
    healthy=true
    break
  fi
  sleep 2
done

if [[ "$healthy" != true ]]; then
  echo "Health check failed for $release_id; rolling back." >&2
  if [[ -n "$previous_release" && -d "$previous_release" ]]; then
    ln -sfn "$previous_release" "$APP_ROOT/current"
    systemctl restart "$SERVICE_NAME"
  else
    systemctl stop "$SERVICE_NAME"
  fi
  cleanup_failed_release
  exit 1
fi

trap - ERR
touch "$release_dir/.healthy"
rm -f -- "$archive_path"
rm -rf -- "$NPM_CACHE_DIR"

# Retain the active release plus the two newest rollback releases. Only folders
# matching a known Aqura release name are eligible, and the active target is
# always protected even if timestamps or directory ordering are unexpected.
active_release="$(readlink -f "$APP_ROOT/current")"
kept=0
deleted=0
bytes_before="$(du -sb "$RELEASES_DIR" 2>/dev/null | awk '{print $1}')"
mapfile -t release_names < <(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' | sort -nr | cut -d' ' -f2-)
for candidate_name in "${release_names[@]}"; do
  if [[ ! "$candidate_name" =~ ^([0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z|[0-9]{8}-[0-9]{4})$ ]]; then
    echo "SKIPPED_UNKNOWN_RELEASE=$candidate_name"
    continue
  fi
  candidate="$RELEASES_DIR/$candidate_name"
  candidate_real="$(readlink -f "$candidate")"
  if [[ "$candidate_real" == "$active_release" || $kept -lt 3 ]]; then
    kept=$((kept + 1))
    echo "KEPT_RELEASE=$candidate_name"
    continue
  fi
  if [[ "$candidate_real" == "$RELEASES_DIR/$candidate_name" && -d "$candidate_real" && ! -L "$candidate" ]]; then
    rm -rf -- "$candidate_real"
    deleted=$((deleted + 1))
    echo "DELETED_RELEASE=$candidate_name"
  fi
done

# Interrupted uploads are safe to remove after 24 hours. Restrict deletion to
# deployment-created archive and activation-script names in the incoming folder.
find "$APP_ROOT/incoming" -mindepth 1 -maxdepth 1 -type f \
  \( -name '*.tar.gz' -o -name 'activate-*.sh' \) -mmin +1440 -print -delete

bytes_after="$(du -sb "$RELEASES_DIR" 2>/dev/null | awk '{print $1}')"
bytes_recovered=$((bytes_before - bytes_after))
echo "DEPLOYED_RELEASE=$release_id"
echo "HEALTH_URL=$health_url"
echo "OLD_RELEASES_DELETED=$deleted"
echo "BYTES_RECOVERED=$bytes_recovered"
df -h "$APP_ROOT" | tail -n 1 | awk '{print "DISK_FREE=" $4}'
systemctl is-active "$SERVICE_NAME"
