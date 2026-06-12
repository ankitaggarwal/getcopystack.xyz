#!/bin/bash
#
# build-release.sh - builds CopyStack, signs it, and packages a distributable
# DMG on the Desktop.
#
# Signing is auto-detected:
#   - If a "Developer ID Application" identity is in the Keychain, the app is
#     signed with it (hardened runtime + timestamp) and the DMG is notarized
#     and stapled via a notarytool keychain profile (override the profile name
#     with NOTARY_PROFILE; set it up once with
#     `xcrun notarytool store-credentials <profile> --apple-id ... --team-id ...`).
#     Result: users get a normal Gatekeeper-verified first launch.
#   - Otherwise it falls back to a self-signed certificate (create one in
#     Keychain Access > Certificate Assistant, type "Code Signing", and set
#     SIGN_IDENTITY to its name). Self-signed builds need a one-time
#     right-click > Open on other Macs.
#
# Either way, sign every release with the SAME identity: CopyStack uses
# keyboard simulation, and macOS ties its Accessibility permission to the
# signing identity - changing it makes users re-grant the permission.
#
# Run:  ./build-release.sh

set -euo pipefail

# Signing identity: explicit SIGN_IDENTITY wins; else the first Developer ID
# Application identity in the Keychain; else the self-signed certificate name.
DEV_ID="$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
SIGN_IDENTITY="${SIGN_IDENTITY:-${DEV_ID:-CopyStack Self-Signed}}"
NOTARY_PROFILE="${NOTARY_PROFILE:-lilcleo}"
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

# 2. Re-sign with the release certificate (stable identity for Accessibility).
echo "==> Signing with '$SIGN_IDENTITY'..."
case "$SIGN_IDENTITY" in
  "Developer ID Application"*)
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP" ;;
  *)
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP" ;;
esac
codesign --verify --verbose "$APP"

# 3. Package the DMG (drag-to-Applications layout).
echo "==> Packaging DMG..."
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG_OUT"
hdiutil create -volname "CopyStack" -srcfolder "$STAGE" -ov -format UDZO "$DMG_OUT" >/dev/null
rm -rf "$STAGE"

# 4. Notarize + staple when signed with a Developer ID identity.
case "$SIGN_IDENTITY" in
  "Developer ID Application"*)
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_OUT"
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
      echo "==> Notarizing (takes a few minutes)..."
      xcrun notarytool submit "$DMG_OUT" --keychain-profile "$NOTARY_PROFILE" --wait
      xcrun stapler staple "$DMG_OUT"
    else
      echo "WARNING: notarytool profile '$NOTARY_PROFILE' not found - DMG is signed but NOT notarized."
      echo "  Set it up once: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <email> --team-id <team>"
    fi
    ;;
esac

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
echo "==> Done. CopyStack $VERSION -> $DMG_OUT"
