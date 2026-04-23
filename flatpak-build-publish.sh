#!/bin/bash
set -euo pipefail
set -x

script_dir=$(cd "$(dirname "$0")" && pwd)
flatpak_dir="$script_dir/flatpak"

app_id="app.openauthenticator.OpenAuthenticator"
repo_clone_dir="${FLATPAK_PUBLISH_CLONE_DIR:-$flatpak_dir/OpenAuthenticatorFlatpak}"
publish_remote="${FLATPAK_PUBLISH_REMOTE:-git@github.com:Skyost/OpenAuthenticatorFlatpak.git}"
publish_branch="${FLATPAK_PUBLISH_BRANCH:-main}"
repo_url="${FLATPAK_REPO_URL:-https://skyost.github.io/OpenAuthenticatorFlatpak/repo}"
repo_title="${FLATPAK_REPO_TITLE:-OpenAuthenticator Flatpak}"
repo_name="${FLATPAK_REPO_NAME:-app.openauthenticator.OpenAuthenticator}"
default_branch="${FLATPAK_REPO_DEFAULT_BRANCH:-master}"
flatpakrepo_output_name="${FLATPAK_PUBLISH_REPO_FILE:-openauthenticator.flatpakrepo}"
flatpakref_output_name="${FLATPAK_PUBLISH_REF_FILE:-openauthenticator.flatpakref}"

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

git -C "$repo_clone_dir" fetch origin
git -C "$repo_clone_dir" checkout "$publish_branch"
git -C "$repo_clone_dir" pull --ff-only origin "$publish_branch"

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

git -C "$repo_clone_dir" commit -m "${FLATPAK_PUBLISH_COMMIT_MESSAGE:-chore: update Flatpak repo}"
git -C "$repo_clone_dir" push origin "$publish_branch"
