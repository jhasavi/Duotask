#!/usr/bin/env bash
#
# Fail the build if the web bundle contains anything that must never be public.
#
# This exists because build/web/assets/.env was committed and served at
# https://<domain>/assets/.env, exposing the Resend API key and Discord bot
# token. This check is the guard that stops that class of mistake recurring.
#
# The Supabase anon key is deliberately NOT flagged: it is a client-side
# credential by design, protected by row-level security rather than secrecy.
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE="${1:-build/web}"
failed=0

if [[ ! -d "$BUNDLE" ]]; then
  echo "error: bundle directory '$BUNDLE' not found" >&2
  exit 1
fi

fail() {
  echo "FAIL: $1" >&2
  failed=1
}

# 1. No env files of any kind.
while IFS= read -r f; do
  fail "env file present in bundle: $f"
done < <(find "$BUNDLE" -name '.env' -o -name '.env.*' -o -name '*.env')

# 2. No Vercel project metadata.
[[ -d "$BUNDLE/.vercel" ]] && fail "$BUNDLE/.vercel present in bundle"

# 3. No secret-shaped credentials anywhere in the bundle.
#    - Resend keys:        re_XXXXXXXX_XXXXXXXXXXXX...
#    - Discord bot tokens: <base64 id>.<6 chars>.<27+ chars>
#    - Supabase service_role JWTs (payload contains "role":"service_role")
# Kept as parallel name|pattern lines so this runs on bash 3.2 (macOS default),
# which has no associative arrays.
scan() {
  local name="$1" pattern="$2" hits
  hits="$(grep -rlEI "$pattern" "$BUNDLE" 2>/dev/null | head -5 || true)"
  if [[ -n "$hits" ]]; then
    fail "$name found in bundle:"
    echo "$hits" >&2
  fi
}

scan "Resend API key"    're_[A-Za-z0-9]{8}_[A-Za-z0-9]{20,}'
scan "Discord bot token" 'M[A-Za-z0-9]{23,}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27,}'
scan "Vercel OIDC token" 'VERCEL_OIDC_TOKEN'

# 4. service_role JWTs are base64 inside the token, so decode-scan separately.
while IFS= read -r token_file; do
  fail "possible service_role key in: $token_file"
done < <(grep -rlI 'InNlcnZpY2Vfcm9sZSI' "$BUNDLE" 2>/dev/null)

if [[ $failed -ne 0 ]]; then
  echo "" >&2
  echo "Bundle verification FAILED — refusing to publish." >&2
  exit 1
fi

echo "OK: no secrets detected in $BUNDLE"
