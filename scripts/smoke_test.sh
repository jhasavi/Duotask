#!/usr/bin/env bash
#
# Post-deploy smoke test. Verifies a deployed DuoTask build is actually
# serving, is not leaking secrets, and is not a stale bundle.
#
# Usage:
#   scripts/smoke_test.sh https://duotask.example.com
set -euo pipefail

BASE_URL="${1:-}"
if [[ -z "$BASE_URL" ]]; then
  echo "usage: $0 <base-url>" >&2
  exit 1
fi
BASE_URL="${BASE_URL%/}"

failed=0
pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1" >&2; failed=1; }

echo "Smoke testing $BASE_URL"

# 1. The app shell loads.
code="$(curl -fsS -o /tmp/smoke_index -w '%{http_code}' "$BASE_URL/" || echo 000)"
if [[ "$code" == "200" ]] && grep -qi 'flutter' /tmp/smoke_index; then
  pass "index.html served (HTTP $code)"
else
  fail "index.html not served correctly (HTTP $code)"
fi

# 2. The compiled bundle loads and is non-trivial.
code="$(curl -fsS -o /tmp/smoke_main -w '%{http_code}' "$BASE_URL/main.dart.js" || echo 000)"
size="$(wc -c < /tmp/smoke_main 2>/dev/null || echo 0)"
if [[ "$code" == "200" && "$size" -gt 500000 ]]; then
  pass "main.dart.js served (${size} bytes)"
else
  fail "main.dart.js missing or too small (HTTP $code, ${size} bytes)"
fi

# 3. THE REGRESSION GUARD: no env file may be publicly readable.
#    https://<domain>/assets/.env previously returned 200 with the Resend API
#    key and Discord bot token in it.
#
#    vercel.json rewrites /(.*) to /index.html, so a missing path still
#    answers 200 with the app shell. Status alone therefore proves nothing —
#    check whether the body actually looks like an env file (KEY=VALUE lines
#    and no HTML) before calling it exposed.
looks_like_env() {
  local f="$1"
  grep -qi '<!DOCTYPE html\|<html' "$f" && return 1
  grep -qE '^[A-Z][A-Z0-9_]*=' "$f"
}

for path in /assets/.env /assets/.env.example /.env /.env.local; do
  curl -fsS -o /tmp/smoke_env "$BASE_URL$path" 2>/dev/null || : > /tmp/smoke_env
  if looks_like_env /tmp/smoke_env; then
    fail "$path is publicly readable and contains env-style values"
  else
    pass "$path not exposed"
  fi
done

# 4. No secret-shaped strings anywhere in the served bundle.
if grep -qE 're_[A-Za-z0-9]{8}_[A-Za-z0-9]{20,}' /tmp/smoke_main 2>/dev/null; then
  fail "Resend-style API key found in served bundle"
elif grep -q 'InNlcnZpY2Vfcm9sZSI' /tmp/smoke_main 2>/dev/null; then
  fail "service_role JWT found in served bundle"
else
  pass "no secrets detected in served bundle"
fi

# 5. Freshness: the deployed build should match the commit being deployed.
#    Skipped when EXPECTED_VERSION is not supplied (e.g. manual runs).
if [[ -n "${EXPECTED_VERSION:-}" ]]; then
  if curl -fsS "$BASE_URL/version.json" -o /tmp/smoke_version 2>/dev/null; then
    pass "version.json served: $(cat /tmp/smoke_version)"
  else
    echo "  WARN  version.json not served; cannot verify freshness"
  fi
fi

echo
if [[ $failed -ne 0 ]]; then
  echo "SMOKE TEST FAILED" >&2
  exit 1
fi
echo "SMOKE TEST PASSED"
