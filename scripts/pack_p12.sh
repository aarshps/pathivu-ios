#!/usr/bin/env bash
#
# pack_p12.sh
#
# Combines the private key from generate_csr.sh with Apple's signed .cer
# into a .p12 keystore. Outputs a base64-encoded string that goes straight
# into the BUILD_CERTIFICATE_BASE64 GitHub Secret.
#
# Usage:
#   ./scripts/pack_p12.sh distribution.cer
#
# Reads:
#   Pathivu-key.pem         (the private key from generate_csr.sh)
#   distribution.cer        (the signed cert from Apple, DER or PEM)
#
# Outputs:
#   Pathivu-Distribution.p12         (the keystore)
#   Pathivu-Distribution.p12.base64  (ready to paste into GitHub Secret)

set -euo pipefail

CER_FILE="${1:-distribution.cer}"
KEY_FILE="Pathivu-key.pem"
P12_FILE="Pathivu-Distribution.p12"
B64_FILE="$P12_FILE.base64"

if [ ! -f "$KEY_FILE" ]; then
  echo "::error::Missing $KEY_FILE. Run scripts/generate_csr.sh first."
  exit 1
fi

if [ ! -f "$CER_FILE" ]; then
  echo "::error::Missing $CER_FILE. Download the signed cert from developer.apple.com first."
  exit 1
fi

# Apple ships .cer as DER. openssl needs PEM for the pkcs12 pack. Convert if needed.
CER_PEM="/tmp/distribution.pem"
if openssl x509 -inform DER -in "$CER_FILE" -out "$CER_PEM" 2>/dev/null; then
  echo "Converted DER cert to PEM"
else
  cp "$CER_FILE" "$CER_PEM"
  echo "Cert was already PEM"
fi

echo "Choose a strong .p12 passphrase (you'll save this as the P12_PASSWORD GitHub Secret):"
# Read into env var so OpenSSL can pull it via -passout env:NAME — keeps the
# value out of the command line (where `ps` could see it) and out of any
# `pass:`-literal pattern that secret scanners flag.
read -rsp "Passphrase: " P12_PASS
export P12_PASS
echo ""

openssl pkcs12 -export \
  -inkey "$KEY_FILE" \
  -in "$CER_PEM" \
  -out "$P12_FILE" \
  -passout env:P12_PASS

unset P12_PASS

# base64-encode for GitHub Secrets. -w0 avoids line wrapping (Linux);
# falls back to plain base64 on macOS where -w0 isn't supported.
if base64 --help 2>&1 | grep -q -- "-w"; then
  base64 -w0 < "$P12_FILE" > "$B64_FILE"
else
  base64 < "$P12_FILE" | tr -d '\n' > "$B64_FILE"
fi

rm -f "$CER_PEM"

echo ""
echo "Done."
echo "  Keystore       : $P12_FILE ($(wc -c < "$P12_FILE") bytes)"
echo "  Base64 export  : $B64_FILE ($(wc -c < "$B64_FILE") chars)"
echo ""
echo "Set the GitHub Secrets:"
echo "  gh secret set BUILD_CERTIFICATE_BASE64 < $B64_FILE"
echo "  gh secret set P12_PASSWORD             # paste the password you just chose"
echo ""
echo "Then back up $P12_FILE + the password to a password manager. The .p12"
echo "is valid for one year; you'll regenerate it then."
