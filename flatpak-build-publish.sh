#!/bin/bash
set -euo pipefail
set -x

script_dir=$(cd "$(dirname "$0")" && pwd)
flatpak_dir="$script_dir/flatpak"
env_file="${FLATPAK_ENV_FILE:-}"

app_id="app.openauthenticator.OpenAuthenticator"
repo_clone_dir="${FLATPAK_PUBLISH_CLONE_DIR:-$flatpak_dir/OpenAuthenticatorFlatpak}"
publish_remote="${FLATPAK_PUBLISH_REMOTE:-https://github.com/openauthenticator-app/flatpak.git}"
publish_branch="${FLATPAK_PUBLISH_BRANCH:-main}"
force_sync="${FLATPAK_PUBLISH_FORCE_SYNC:-1}"
repo_url="${FLATPAK_REPO_URL:-https://flatpak.openauthenticator.app/repo}"
repo_title="${FLATPAK_REPO_TITLE:-Open Authenticator Flatpak}"
repo_name="${FLATPAK_REPO_NAME:-app.openauthenticator.OpenAuthenticator}"
default_branch="${FLATPAK_REPO_DEFAULT_BRANCH:-master}"
flatpakrepo_output_name="${FLATPAK_PUBLISH_REPO_FILE:-openauthenticator.flatpakrepo}"
flatpakref_output_name="${FLATPAK_PUBLISH_REF_FILE:-openauthenticator.flatpakref}"

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

write_flatpakref_file() {
  local destination_file="$1"
  local gpg_key_base64=""

  if [[ -n "${FLATPAK_GPG_IMPORT:-}" ]]; then
    gpg_key_base64=$(base64 --wrap=0 < "$FLATPAK_GPG_IMPORT")
  fi

  cat > "$destination_file" <<EOF
[Flatpak Ref]
Name=$app_id
Branch=$default_branch
Title=$repo_title
IsRuntime=false
Url=$repo_url
EOF

  if [[ -n "$gpg_key_base64" ]]; then
    printf 'GPGKey=%s\n' "$gpg_key_base64" >> "$destination_file"
  fi

  if [[ -n "${FLATPAK_RUNTIME_REPO:-}" ]]; then
    printf 'RuntimeRepo=%s\n' "$FLATPAK_RUNTIME_REPO" >> "$destination_file"
  fi
}

if [[ -n "$env_file" ]]; then
  load_env_file "$env_file"
else
  load_env_file "$script_dir/.env"
  load_env_file "$flatpak_dir/.env"
fi

repo_clone_dir="${FLATPAK_PUBLISH_CLONE_DIR:-$repo_clone_dir}"
publish_remote="${FLATPAK_PUBLISH_REMOTE:-$publish_remote}"
publish_branch="${FLATPAK_PUBLISH_BRANCH:-$publish_branch}"
force_sync="${FLATPAK_PUBLISH_FORCE_SYNC:-$force_sync}"
repo_url="${FLATPAK_REPO_URL:-$repo_url}"
repo_title="${FLATPAK_REPO_TITLE:-$repo_title}"
repo_name="${FLATPAK_REPO_NAME:-$repo_name}"
default_branch="${FLATPAK_REPO_DEFAULT_BRANCH:-$default_branch}"
flatpakrepo_output_name="${FLATPAK_PUBLISH_REPO_FILE:-$flatpakrepo_output_name}"
flatpakref_output_name="${FLATPAK_PUBLISH_REF_FILE:-$flatpakref_output_name}"

repo_clone_dir=$(strip_trailing_cr "$repo_clone_dir")
publish_remote=$(strip_trailing_cr "$publish_remote")
publish_branch=$(strip_trailing_cr "$publish_branch")
repo_url=$(strip_trailing_cr "$repo_url")
repo_title=$(strip_trailing_cr "$repo_title")
repo_name=$(strip_trailing_cr "$repo_name")
default_branch=$(strip_trailing_cr "$default_branch")
flatpakrepo_output_name=$(strip_trailing_cr "$flatpakrepo_output_name")
flatpakref_output_name=$(strip_trailing_cr "$flatpakref_output_name")
force_sync=$(strip_trailing_cr "$force_sync")
if [[ -n "${FLATPAK_GPG_KEY_ID:-}" ]]; then
  FLATPAK_GPG_KEY_ID=$(strip_trailing_cr "$FLATPAK_GPG_KEY_ID")
fi
if [[ -n "${FLATPAK_GPG_HOMEDIR:-}" ]]; then
  FLATPAK_GPG_HOMEDIR=$(strip_trailing_cr "$FLATPAK_GPG_HOMEDIR")
fi
if [[ -n "${FLATPAK_GPG_IMPORT:-}" ]]; then
  FLATPAK_GPG_IMPORT=$(strip_trailing_cr "$FLATPAK_GPG_IMPORT")
fi
if [[ -n "${FLATPAK_REPO_COMMENT:-}" ]]; then
  FLATPAK_REPO_COMMENT=$(strip_trailing_cr "$FLATPAK_REPO_COMMENT")
fi
if [[ -n "${FLATPAK_REPO_DESCRIPTION:-}" ]]; then
  FLATPAK_REPO_DESCRIPTION=$(strip_trailing_cr "$FLATPAK_REPO_DESCRIPTION")
fi
if [[ -n "${FLATPAK_REPO_HOMEPAGE:-}" ]]; then
  FLATPAK_REPO_HOMEPAGE=$(strip_trailing_cr "$FLATPAK_REPO_HOMEPAGE")
fi
if [[ -n "${FLATPAK_REPO_ICON:-}" ]]; then
  FLATPAK_REPO_ICON=$(strip_trailing_cr "$FLATPAK_REPO_ICON")
fi
if [[ -n "${FLATPAK_RUNTIME_REPO:-}" ]]; then
  FLATPAK_RUNTIME_REPO=$(strip_trailing_cr "$FLATPAK_RUNTIME_REPO")
fi
if [[ -n "${FLATPAK_PUBLISH_COMMIT_MESSAGE:-}" ]]; then
  FLATPAK_PUBLISH_COMMIT_MESSAGE=$(strip_trailing_cr "$FLATPAK_PUBLISH_COMMIT_MESSAGE")
fi

if [[ -z "${FLATPAK_GPG_KEY_ID:-}" ]]; then
  echo "FLATPAK_GPG_KEY_ID is required." >&2
  exit 1
fi

if [[ -z "${FLATPAK_GPG_HOMEDIR:-}" ]]; then
  echo "FLATPAK_GPG_HOMEDIR is required." >&2
  exit 1
fi

if [[ -z "$repo_url" ]]; then
  echo "FLATPAK_REPO_URL is required." >&2
  exit 1
fi

mkdir -p "$flatpak_dir"

if [[ ! -d "$repo_clone_dir/.git" ]]; then
  git clone "$publish_remote" "$repo_clone_dir"
fi

git -C "$repo_clone_dir" remote set-url origin "$publish_remote"
git -C "$repo_clone_dir" fetch origin
git -C "$repo_clone_dir" checkout "$publish_branch"

if [[ "$force_sync" == "1" ]]; then
  git -C "$repo_clone_dir" reset --hard "origin/$publish_branch"
else
  if ! git -C "$repo_clone_dir" pull --ff-only origin "$publish_branch"; then
    echo "Publication clone is diverged from origin/$publish_branch." >&2
    echo "Run with FLATPAK_PUBLISH_FORCE_SYNC=1 to reset the publication clone to the remote branch." >&2
    exit 1
  fi
fi

(
  cd "$flatpak_dir"
  FLATPAK_REPO_URL="$repo_url" \
  FLATPAK_REPO_TITLE="$repo_title" \
  FLATPAK_REPO_NAME="$repo_name" \
  FLATPAK_REPO_DEFAULT_BRANCH="$default_branch" \
  FLATPAK_GPG_KEY_ID="$FLATPAK_GPG_KEY_ID" \
  FLATPAK_GPG_HOMEDIR="$FLATPAK_GPG_HOMEDIR" \
  FLATPAK_GPG_IMPORT="${FLATPAK_GPG_IMPORT:-}" \
  FLATPAK_REPO_COMMENT="${FLATPAK_REPO_COMMENT:-}" \
  FLATPAK_REPO_DESCRIPTION="${FLATPAK_REPO_DESCRIPTION:-}" \
  FLATPAK_REPO_HOMEPAGE="${FLATPAK_REPO_HOMEPAGE:-}" \
  FLATPAK_REPO_ICON="${FLATPAK_REPO_ICON:-}" \
  ./build-flutter-app.sh
)

rsync -av --delete \
  --exclude '.git' \
  "$flatpak_dir/repo/" \
  "$repo_clone_dir/repo/"

cp "$flatpak_dir/$app_id.flatpakrepo" "$repo_clone_dir/$flatpakrepo_output_name"
write_flatpakref_file "$repo_clone_dir/$flatpakref_output_name"

git -C "$repo_clone_dir" add repo "$flatpakrepo_output_name" "$flatpakref_output_name"

if git -C "$repo_clone_dir" diff --cached --quiet; then
  echo "No publication changes detected."
  exit 0
fi

git -C "$repo_clone_dir" commit -m "${FLATPAK_PUBLISH_COMMIT_MESSAGE:-chore: Updated the Flatpak repo.}"
git -C "$repo_clone_dir" push origin "$publish_branch"
