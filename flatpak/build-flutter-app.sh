#!/bin/bash
set -euo pipefail
set -x

project_name=OpenAuthenticator
app_id=app.openauthenticator.OpenAuthenticator
archive_name="$project_name-Linux-Portable.tar.gz"
base_dir=$(pwd)
repo_dir="$base_dir/repo"
bundle_dir="build/linux/x64/release/bundle"
flatpak_bundle="$base_dir/$app_id.flatpak"
flatpak_repo_file="$base_dir/$app_id.flatpakrepo"

copy_host_library() {
  local pattern="$1"
  local destination_dir="$2"
  local matches=()
  local lib_dir

  for lib_dir in /usr/lib64 /usr/lib/x86_64-linux-gnu; do
    if compgen -G "$lib_dir/$pattern" > /dev/null; then
      matches=("$lib_dir"/$pattern)
      cp -av "${matches[@]}" "$destination_dir/"
      return 0
    fi
  done

  echo "Missing required host library pattern: $pattern" >&2
  return 1
}

write_flatpakrepo_file() {
  local repo_url="$1"
  local repo_title="${FLATPAK_REPO_TITLE:-$project_name}"
  local repo_name="${FLATPAK_REPO_NAME:-$app_id}"
  local default_branch="${FLATPAK_REPO_DEFAULT_BRANCH:-master}"
  local gpg_key_base64=""

  if [[ -n "${FLATPAK_GPG_IMPORT:-}" ]]; then
    gpg_key_base64=$(base64 --wrap=0 < "$FLATPAK_GPG_IMPORT")
  fi

  cat > "$flatpak_repo_file" <<EOF
[Flatpak Repo]
Title=$repo_title
Name=$repo_name
Url=$repo_url
DefaultBranch=$default_branch
EOF

  if [[ -n "${FLATPAK_REPO_COMMENT:-}" ]]; then
    printf 'Comment=%s\n' "$FLATPAK_REPO_COMMENT" >> "$flatpak_repo_file"
  fi

  if [[ -n "${FLATPAK_REPO_DESCRIPTION:-}" ]]; then
    printf 'Description=%s\n' "$FLATPAK_REPO_DESCRIPTION" >> "$flatpak_repo_file"
  fi

  if [[ -n "${FLATPAK_REPO_HOMEPAGE:-}" ]]; then
    printf 'Homepage=%s\n' "$FLATPAK_REPO_HOMEPAGE" >> "$flatpak_repo_file"
  fi

  if [[ -n "${FLATPAK_REPO_ICON:-}" ]]; then
    printf 'Icon=%s\n' "$FLATPAK_REPO_ICON" >> "$flatpak_repo_file"
  fi

  if [[ -n "$gpg_key_base64" ]]; then
    printf 'GPGKey=%s\n' "$gpg_key_base64" >> "$flatpak_repo_file"
  fi
}

pushd . > /dev/null
cd ..

# Build Flutter app.
flutter clean
export APPLICATION_ID="$app_id"
flutter build linux --release

mkdir -p "$bundle_dir/lib"
copy_host_library "libpolkit-gobject-1.so*" "$bundle_dir/lib"
copy_host_library "libsecret-1.so*" "$bundle_dir/lib"

cd "$bundle_dir"
tar -czaf "$archive_name" ./*
mv "$archive_name" "$base_dir/"
popd > /dev/null

rm -rf "$repo_dir" "$base_dir/appdir"

builder_args=(
  --force-clean
  "$base_dir/appdir"
  "$base_dir/app.yaml"
  --repo="$repo_dir"
)

if [[ -n "${FLATPAK_REPO_DEFAULT_BRANCH:-}" ]]; then
  builder_args+=(--default-branch="$FLATPAK_REPO_DEFAULT_BRANCH")
fi

if [[ -n "${FLATPAK_GPG_KEY_ID:-}" ]]; then
  builder_args+=(--gpg-sign="$FLATPAK_GPG_KEY_ID")

  if [[ -n "${FLATPAK_GPG_HOMEDIR:-}" ]]; then
    builder_args+=(--gpg-homedir="$FLATPAK_GPG_HOMEDIR")
  fi
fi

flatpak-builder "${builder_args[@]}"

update_repo_args=(
  --generate-static-deltas
  --prune
)

if [[ -n "${FLATPAK_REPO_TITLE:-}" ]]; then
  update_repo_args+=(--title="$FLATPAK_REPO_TITLE")
fi

if [[ -n "${FLATPAK_REPO_DEFAULT_BRANCH:-}" ]]; then
  update_repo_args+=(--default-branch="$FLATPAK_REPO_DEFAULT_BRANCH")
fi

if [[ -n "${FLATPAK_GPG_KEY_ID:-}" ]]; then
  update_repo_args+=(--gpg-sign="$FLATPAK_GPG_KEY_ID")

  if [[ -n "${FLATPAK_GPG_HOMEDIR:-}" ]]; then
    update_repo_args+=(--gpg-homedir="$FLATPAK_GPG_HOMEDIR")
  fi

  if [[ -n "${FLATPAK_GPG_IMPORT:-}" ]]; then
    update_repo_args+=(--gpg-import="$FLATPAK_GPG_IMPORT")
  fi
fi

flatpak build-update-repo "$repo_dir" "${update_repo_args[@]}"
flatpak build-bundle "$repo_dir" "$flatpak_bundle" "$app_id"

if [[ -n "${FLATPAK_REPO_URL:-}" ]]; then
  write_flatpakrepo_file "$FLATPAK_REPO_URL"
fi
