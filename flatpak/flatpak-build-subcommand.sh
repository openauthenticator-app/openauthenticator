#!/bin/bash
set -e
set -x

projectName=OpenAuthenticator
domain=app.openauthenticator
projectId=$domain.$projectName
executableName=open_authenticator

# Build Flatpak
echo "$(pwd)"

mkdir -p $projectName
tar -xf $projectName-Linux-Portable.tar.gz -C $projectName

# Copy the portable app to the Flatpak-based location.
cp -r $projectName /app/
chmod +x /app/$projectName/$executableName
mkdir -p /app/bin
ln -s /app/$projectName/$executableName /app/bin/$executableName

# Install the icon.
iconDir=/app/share/icons/hicolor/scalable/apps
mkdir -p $iconDir
install -Dm644 "$projectId.svg" "$iconDir/$projectId.svg"

# Install the desktop file.
desktopFileDir=/app/share/applications
mkdir -p $desktopFileDir
install -Dm644 "$projectId.desktop" "$desktopFileDir/$projectId.desktop"
# install -Dm644 "$projectId.desktop" "$desktopFileDir/$domain.desktop"

# Install the AppStream metadata file.
metadataDir=/app/share/metainfo
mkdir -p $metadataDir
install -Dm644 "$projectId.metainfo.xml" "$metadataDir/$projectId.metainfo.xml"
