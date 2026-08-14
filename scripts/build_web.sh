#!/usr/bin/env bash
#
# Build the DuoTask web bundle for deployment.
#
# Configuration is injected with --dart-define rather than by bundling a .env
# asset. A previous build shipped .env inside the bundle, which served the
# Resend and Discord secrets publicly at https://<domain>/assets/.env.
#
# Values are read from the environment, falling back to a local .env for
# developer convenience. In CI they come from repository secrets.
#
# Usage:
#   scripts/build_web.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# Load local .env only when the variables are not already in the environment.
if [[ -f .env ]]; then
  while IFS='=' read -r key value; do
    [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
    if [[ -z "${!key:-}" ]]; then
      export "$key=$value"
    fi
  done < <(grep -vE '^\s*(#|$)' .env)
fi

require() {
  if [[ -z "${!1:-}" ]]; then
    echo "error: $1 is not set (put it in .env or the environment)" >&2
    exit 1
  fi
}

require SUPABASE_URL
require SUPABASE_ANON_KEY

APP_VERSION="${APP_VERSION:-$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)}"

echo "==> Building DuoTask web v${APP_VERSION}"

flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=WEB_REDIRECT_URL="${WEB_REDIRECT_URL:-}" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}" \
  --dart-define=GOOGLE_IOS_CLIENT_ID="${GOOGLE_IOS_CLIENT_ID:-}" \
  --dart-define=GOOGLE_ANDROID_CLIENT_ID="${GOOGLE_ANDROID_CLIENT_ID:-}" \
  --dart-define=APP_NAME="${APP_NAME:-DuoTask}" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=DEBUG_MODE=false

# Belt and braces: never ship an env file, whatever the asset config says.
rm -f build/web/assets/.env build/web/assets/.env.example \
      build/web/.env build/web/.env.local
rm -rf build/web/.vercel

echo "==> Verifying no secrets in bundle"
scripts/verify_bundle.sh

echo "==> Build complete: build/web"
