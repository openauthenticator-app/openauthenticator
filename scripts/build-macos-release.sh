#!/usr/bin/env bash
set -euo pipefail

: "${MACOS_FIREBASE_PLIST_BASE64:?Configure the macOS Firebase plist}"
: "${MACOS_CERTIFICATE_BASE64:?Configure the Developer ID Application certificate}"
: "${MACOS_CERTIFICATE_PASSWORD:?Configure the certificate password}"
: "${MACOS_PROVISIONING_PROFILE_BASE64:?Configure the Developer ID provisioning profile}"
: "${MACOS_NOTARY_KEY_BASE64:?Configure the App Store Connect API key}"
: "${MACOS_NOTARY_KEY_ID:?Configure the notarization key ID}"
: "${MACOS_NOTARY_ISSUER_ID:?Configure the notarization issuer ID}"

work_dir=$(mktemp -d "$RUNNER_TEMP/macos-release.XXXXXXXX")
keychain="$work_dir/signing.keychain-db"
firebase_plist=macos/Runner/GoogleService-Info.plist

# Remove the temporary signing files and the CI Firebase configuration.
cleanup() {
  security delete-keychain "$keychain" 2>/dev/null || true
  rm -rf "$work_dir"
  rm -f "$firebase_plist"
}
trap cleanup EXIT

printf '%s' "$MACOS_FIREBASE_PLIST_BASE64" | base64 -D > "$firebase_plist"
printf '%s' "$MACOS_CERTIFICATE_BASE64" | base64 -D > "$work_dir/certificate.p12"
printf '%s' "$MACOS_PROVISIONING_PROFILE_BASE64" | base64 -D > "$work_dir/profile.provisionprofile"
printf '%s' "$MACOS_NOTARY_KEY_BASE64" | base64 -D > "$work_dir/notary-key.p8"

keychain_password=$(openssl rand -hex 32)
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 7200 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$work_dir/certificate.p12" -k "$keychain" -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain"
identity=$(security find-identity -v -p codesigning "$keychain" | awk '/Developer ID Application:/ { print $2; exit }')
: "${identity:?No valid Developer ID Application identity was imported}"

cat > "$work_dir/unsigned.xcconfig" <<'EOF'
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO
EOF
XCODE_XCCONFIG_FILE="$work_dir/unsigned.xcconfig" flutter build macos --release --dart-define="GITHUB_RELEASE_ASSET=$RELEASE_ASSET"

app='build/macos/Build/Products/Release/Open Authenticator.app'
lipo "$app/Contents/MacOS/Open Authenticator" -verify_arch arm64 x86_64
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
security cms -D -i "$work_dir/profile.provisionprofile" -o "$work_dir/profile.plist"
app_id=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$work_dir/profile.plist")
team_id=$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$work_dir/profile.plist")
if [[ "$app_id" != "$team_id.$bundle_id" ]]; then
  echo "The Developer ID profile must match $team_id.$bundle_id." >&2
  exit 1
fi
cp "$work_dir/profile.provisionprofile" "$app/Contents/embedded.provisionprofile"

entitlements="$work_dir/DirectDownload.entitlements"
cp macos/Runner/Release.entitlements "$entitlements"
/usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.applesignin' -c 'Delete :keychain-access-groups' \
  -c "Add :com.apple.application-identifier string $app_id" -c "Add :com.apple.developer.team-identifier string $team_id" "$entitlements"

sign=(codesign --force --sign "$identity" --keychain "$keychain" --timestamp)
while IFS= read -r -d '' component; do
  "${sign[@]}" --options runtime "$component"
done < <(find "$app/Contents/Frameworks" -depth \( -type d -name '*.framework' -o -type f -name '*.dylib' \) -print0)
"${sign[@]}" --options runtime --entitlements "$entitlements" "$app"
codesign --verify --deep --strict "$app"

mkdir "$work_dir/dmg"
ditto "$app" "$work_dir/dmg/Open Authenticator.app"
ln -s /Applications "$work_dir/dmg/Applications"
dmg="dist/$RELEASE_ASSET"
hdiutil create -volname 'Open Authenticator' -srcfolder "$work_dir/dmg" -format UDZO "$dmg"
"${sign[@]}" "$dmg"

notary_args=(--key "$work_dir/notary-key.p8" --key-id "$MACOS_NOTARY_KEY_ID" --issuer "$MACOS_NOTARY_ISSUER_ID")
xcrun notarytool submit "$dmg" "${notary_args[@]}" --wait --timeout 25m --output-format json > "$work_dir/notary.json"
if ! jq -e '.status == "Accepted"' "$work_dir/notary.json" > /dev/null; then
  xcrun notarytool log "$(jq -r '.id' "$work_dir/notary.json")" "${notary_args[@]}"
  exit 1
fi
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
