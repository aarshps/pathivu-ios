#!/usr/bin/env bash
#
# check_apple_secrets.sh
#
# Confirms every GitHub Secret the ios-release workflow expects is set on
# this repo. Doesn't reveal the values (gh CLI can't, by design) but tells
# you which ones are missing, so you don't trigger a release run only to
# have it fail 14 minutes in on a missing secret.
#
# Usage:
#   ./scripts/check_apple_secrets.sh

set -euo pipefail

EXPECTED=(
  APPLE_TEAM_ID
  APPLE_API_ISSUER_ID
  APPLE_API_KEY_ID
  APPLE_API_KEY_BASE64
  BUILD_CERTIFICATE_BASE64
  P12_PASSWORD
  PROVISIONING_PROFILE_BASE64
  KEYCHAIN_PASSWORD
  GOOGLE_SERVICE_INFO_BASE64
)

if ! command -v gh >/dev/null 2>&1; then
  echo "::error::gh CLI not installed. Install from https://cli.github.com"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "::error::gh CLI not authenticated. Run: gh auth login"
  exit 1
fi

echo "Checking repo secrets..."
SET_SECRETS=$(gh secret list --json name --jq '.[].name')
missing=()
for s in "${EXPECTED[@]}"; do
  if echo "$SET_SECRETS" | grep -qx "$s"; then
    echo "  [SET]     $s"
  else
    echo "  [MISSING] $s"
    missing+=("$s")
  fi
done

echo ""
if [ "${#missing[@]}" -eq 0 ]; then
  echo "All ${#EXPECTED[@]} secrets are set. You can trigger ios-release."
else
  echo "${#missing[@]} secret(s) missing. Add them before running ios-release:"
  for s in "${missing[@]}"; do
    case "$s" in
      APPLE_TEAM_ID)
        echo "  $s              ← 10-char team ID from developer.apple.com/account#MembershipDetailsCard"
        ;;
      APPLE_API_ISSUER_ID)
        echo "  $s         ← UUID from App Store Connect → Users & Access → Integrations → API"
        ;;
      APPLE_API_KEY_ID)
        echo "  $s            ← 10-char key ID from the same page"
        ;;
      APPLE_API_KEY_BASE64)
        echo "  $s         ← base64 of AuthKey_*.p8: gh secret set $s < AuthKey_XXXX.p8.b64"
        ;;
      BUILD_CERTIFICATE_BASE64)
        echo "  $s     ← base64 of Distribution .p12; run scripts/pack_p12.sh"
        ;;
      P12_PASSWORD)
        echo "  $s                ← password you chose in scripts/pack_p12.sh"
        ;;
      PROVISIONING_PROFILE_BASE64)
        echo "  $s  ← base64 of Pathivu_AppStore.mobileprovision (downloaded from developer.apple.com)"
        ;;
      KEYCHAIN_PASSWORD)
        echo "  $s           ← any strong random string; CI uses it only inside the temp keychain"
        ;;
      GOOGLE_SERVICE_INFO_BASE64)
        echo "  $s   ← base64 of Pathivu/Resources/GoogleService-Info.plist"
        ;;
    esac
  done
  exit 1
fi
