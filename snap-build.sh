#!/bin/bash
set -euo pipefail
set -x

script_dir=$(cd "$(dirname "$0")" && pwd)
snap_dir="$script_dir/snap"
env_file="${SNAP_ENV_FILE:-}"

docker_image="${SNAPCRAFT_DOCKER_IMAGE:-ghcr.io/canonical/snapcraft:8_core24}"
container_workspace="${SNAPCRAFT_CONTAINER_WORKSPACE:-/project}"
output_dir="${SNAP_OUTPUT_DIR:-$script_dir}"
platform="${SNAPCRAFT_DOCKER_PLATFORM:-}"
apt_update="${SNAPCRAFT_APT_UPDATE:-1}"

load_env_file() {
  local candidate="$1"

  if [[ -z "$candidate" || ! -f "$candidate" ]]; then
    return 0
  fi

  set -a
  # shellcheck disable=SC1090
  . "$candidate"
  set +a
}

strip_trailing_cr() {
  printf '%s' "${1%$'\r'}"
}

if [[ -n "$env_file" ]]; then
  load_env_file "$env_file"
else
  load_env_file "$script_dir/.env"
  load_env_file "$snap_dir/.env"
fi

docker_image=$(strip_trailing_cr "${SNAPCRAFT_DOCKER_IMAGE:-$docker_image}")
container_workspace=$(strip_trailing_cr "${SNAPCRAFT_CONTAINER_WORKSPACE:-$container_workspace}")
output_dir=$(strip_trailing_cr "${SNAP_OUTPUT_DIR:-$output_dir}")
platform=$(strip_trailing_cr "${SNAPCRAFT_DOCKER_PLATFORM:-$platform}")
apt_update=$(strip_trailing_cr "${SNAPCRAFT_APT_UPDATE:-$apt_update}")

if [[ "$output_dir" != /* ]]; then
  output_dir="$script_dir/$output_dir"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to build the snap without a local snapcraft installation." >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required to prepare a clean Docker build context." >&2
  exit 1
fi

if [[ ! -f "$snap_dir/snapcraft.yaml" ]]; then
  echo "snap/snapcraft.yaml was not found." >&2
  exit 1
fi

mkdir -p "$output_dir"

build_context=$(mktemp -d)
cleanup_host() {
  if [[ -d "$build_context" ]]; then
    chmod -R u+rwX "$build_context" 2>/dev/null || true
    rm -rf "$build_context" || true
  fi
}
trap cleanup_host EXIT

rsync -a --no-owner --no-group --delete \
  --exclude '.git' \
  --exclude '.dart_tool' \
  --exclude '.flatpak-builder' \
  --exclude '.pub-cache' \
  --exclude '.snapcraft' \
  --exclude 'build' \
  --exclude 'parts' \
  --exclude 'prime' \
  --exclude 'stage' \
  --exclude '*.snap' \
  "$script_dir/" \
  "$build_context/"

docker_args=(
  run
  --rm
  --entrypoint /bin/sh
  --volume "$build_context:$container_workspace"
  --workdir "$container_workspace"
  --env "HOST_UID=$(id -u)"
  --env "HOST_GID=$(id -g)"
  --env "SNAPCRAFT_APT_UPDATE=$apt_update"
)

if [[ -n "$platform" ]]; then
  docker_args+=(--platform "$platform")
fi

docker_args+=(
  "$docker_image"
  -c
  'set -eu
cleanup() {
  chown -R "$HOST_UID:$HOST_GID" .
}
trap cleanup EXIT
if [ ! -e /usr/share/snapcraft/extensions/desktop ]; then
  extensions_desktop_dir=$(find /usr/lib -path "*/site-packages/extensions/desktop" -type d | head -n 1)
  if [ -n "$extensions_desktop_dir" ]; then
    mkdir -p /usr/share/snapcraft/extensions
    ln -s "$extensions_desktop_dir" /usr/share/snapcraft/extensions/desktop
  fi
fi
if [ "${SNAPCRAFT_APT_UPDATE:-1}" = "1" ]; then
  apt-get update
fi
snapcraft pack --destructive-mode "$@"'
  sh
)

docker "${docker_args[@]}" "$@"

mapfile -t snap_files < <(find "$build_context" -maxdepth 1 -type f -name "*.snap" -print)
if [[ "${#snap_files[@]}" -eq 0 ]]; then
  echo "No snap artifact was produced." >&2
  exit 1
fi

for snap_file in "${snap_files[@]}"; do
  mv "$snap_file" "$output_dir/"
done

printf 'Snap artifact(s):\n'
for snap_file in "${snap_files[@]}"; do
  printf '  %s\n' "$output_dir/$(basename "$snap_file")"
done
