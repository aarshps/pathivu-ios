#!/usr/bin/env bash
#
# generate_csr.sh
#
# Generates a Certificate Signing Request (.certSigningRequest) suitable for
# Apple's distribution certificate flow. Runs on macOS, Linux, or Windows-WSL —
# you do NOT need a Mac for this step (despite Apple's docs).
#
# Usage:
#   ./scripts/generate_csr.sh "you@example.com" "Common Name"
#
# Outputs (to the current directory):
#   Pathivu-key.pem    — the private key (KEEP SECRET; will be packed into .p12)
#   Pathivu.csr        — the CSR to upload at developer.apple.com/account/resources/certificates/add
#
# Next steps (in the Apple Developer portal):
#   1. Visit https://developer.apple.com/account/resources/certificates/add
#   2. Choose: Apple Distribution
#   3. Click Continue
#   4. Upload Pathivu.csr
#   5. Download the resulting `distribution.cer`
#   6. Run scripts/pack_p12.sh to combine Pathivu-key.pem + distribution.cer into a .p12
#      (which is what GitHub Secrets need)

set -euo pipefail

EMAIL="${1:-}"
COMMON_NAME="${2:-Pathivu Distribution}"
COUNTRY="${3:-IN}"
ORG="${4:-Adarsh P S}"

if [ -z "$EMAIL" ]; then
  echo "Usage: $0 <email> [common-name] [country-code] [organization-name]"
  echo ""
  echo "Example:"
  echo "  $0 aarshps@gmail.com 'Pathivu Distribution' IN 'Adarsh P S'"
  exit 2
fi

KEY_FILE="Pathivu-key.pem"
CSR_FILE="Pathivu.csr"

if ! command -v openssl >/dev/null 2>&1; then
  echo "::error::openssl not found. Install it (brew install openssl on Mac, apt install openssl on Linux)."
  exit 1
fi

if [ -e "$KEY_FILE" ] || [ -e "$CSR_FILE" ]; then
  echo "::warning::$KEY_FILE or $CSR_FILE already exists. Refusing to overwrite."
  echo "Delete them first if you really want to regenerate."
  exit 1
fi

echo "Generating 2048-bit RSA private key → $KEY_FILE"
openssl genrsa -out "$KEY_FILE" 2048

echo "Generating CSR → $CSR_FILE"
openssl req -new \
  -key "$KEY_FILE" \
  -out "$CSR_FILE" \
  -subj "/emailAddress=$EMAIL/CN=$COMMON_NAME/O=$ORG/C=$COUNTRY"

echo ""
echo "Done."
echo "  Private key : $KEY_FILE (keep secret — back up to a password manager)"
echo "  CSR         : $CSR_FILE (upload to Apple)"
echo ""
echo "Next: upload $CSR_FILE at"
echo "  https://developer.apple.com/account/resources/certificates/add"
echo "Pick 'Apple Distribution', click Continue, upload, then download the .cer."
echo "Then run scripts/pack_p12.sh"
