#!/bin/bash
#
# build-release.sh — builds CopyStack, signs it with a self-signed certificate,
# and packages a distributable DMG on the Desktop.
#
# CopyStack uses keyboard simulation, so macOS requires the app to have a stable
# code-signing identity for its Accessibility permission to survive updates.
# Signing every build with the SAME self-signed certificate keeps that identity
# stable across rebuilds and machines.
#
# One-time setup:
#   1. Create a self-signed code-signing certificate in Keychain Access
#      (Keychain Access ▸ Certificate Assistant ▸ Create a Certificate…,
#       type "Code Signing"). Name it whatever you like.
#   2. Set SIGN_IDENTITY below (or export it) to that certificate's name.
#
# Then run:  ./build-release.sh
#
# (First launch of a self-signed app still needs a one-time right-click ▸ Open;
#  only Apple notarization removes that, which requires a paid Developer account.)

set -euo pipefail

# Name of the self-signed code-signing certificate in your Keychain.
# Override at runtime with:  SIGN_IDENTITY="My Cert" ./build-release.sh
SIGN_IDENTITY="${SIGN_IDENTITY:-CopyStack Self-Signed}"
PROJECT="Copy Stack.xcodeproj"
SCHEME="Copy Stack"
APP_NAME="Copy Stack.app"
DMG_OUT="${DMG_OUT:-$HOME/Desktop/CopyStack.dmg}"
DERIVED="./build"

cd "$(dirname "$0")"

# 0. Confirm the signing certificate exists in the Keychain.
if ! security find-identity -p codesigning | grep -qi "$SIGN_IDENTITY"; then
  echo "ERROR: code-signing certificate '$SIGN_IDENTITY' was not found in your Keychain."
  echo "Create a self-signed 'Code Signing' certificate in Keychain Access, then set"
  echo "SIGN_IDENTITY to its name (edit this script or export SIGN_IDENTITY)."
  exit 1
fi

# 1. Build a Release .app (ad-hoc here; we re-sign with our certificate in step 2).
echo "==> Building Release..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" clean build >/dev/null

APP="$DERIVED/Build/Products/Release/$APP_NAME"

# 2. Re-sign with the self-signed certificate (stable identity for Accessibility).
echo "==> Signing with '$SIGN_IDENTITY'..."
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --verbose "$APP"

# 3. Package the DMG (drag-to-Applications layout).
echo "==> Packaging DMG..."
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG_OUT"
hdiutil create -volname "CopyStack" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT" >/dev/null
rm -rf "$STAGE"

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
echo "==> Done. CopyStack $VERSION -> $DMG_OUT"
