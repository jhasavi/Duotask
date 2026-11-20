#!/usr/bin/env bash
#
# Production stages for moving EvenHalf to Supabase's new API keys.
# See docs/KEY_MIGRATION.md. Every stage that changes production needs
# CONFIRM=yes in the environment, so nothing runs by accident. No secret
# value is ever printed; the generated function secret lives in
# ~/.evenhalf/function_auth_secret (mode 600), outside the repo.
#
# Usage:  CONFIRM=yes scripts/prod_key_migration.sh <stage>
#   preflight  read-only checks (migrations, secret names, functions)
#   secrets    set SB_SECRET_KEY + FUNCTION_AUTH_SECRET as function secrets
#   deploy     deploy the four edge functions
#   vault      copy SQL to update Vault `anon_key` onto the clipboard
#   verify     call the digest with/without the secret (401 vs 200)
#   legacy-check  expects 401 for a request using the OLD service_role key
#                 (pass it via LEGACY_SERVICE_ROLE_KEY; run after disabling)
set -euo pipefail
cd "$(dirname "$0")/.."

REF="${SUPABASE_PROJECT_REF:-xqhlnuvpogiolzkucupt}"
SECRET_FILE="$HOME/.evenhalf/function_auth_secret"
FUNCS=(daily-email-digest send-nudge-push lifecycle-emails stripe-webhook)

if [[ -f .env ]]; then
  while IFS='=' read -r k v; do
    [[ $k =~ ^[A-Z_][A-Z0-9_]*$ ]] && [[ -z "${!k:-}" ]] && export "$k=$v"
  done < <(grep -vE '^\s*(#|$)' .env)
fi

confirm() {
  [[ "${CONFIRM:-}" == "yes" ]] || { echo "refusing: this changes production; rerun with CONFIRM=yes" >&2; exit 1; }
}
need() { [[ -n "${!1:-}" ]] || { echo "error: $1 is not set" >&2; exit 1; }; }

case "${1:-}" in
  preflight)
    supabase migration list --linked | tail -28
    supabase functions list --project-ref "$REF" | awk -F'|' '{print $2, $4}'
    supabase secrets list --project-ref "$REF" | awk '{print $1}'
    ;;
  secrets)
    confirm; need SUPABASE_SECRET_KEY
    mkdir -p "$HOME/.evenhalf"; chmod 700 "$HOME/.evenhalf"
    if [[ ! -s "$SECRET_FILE" ]]; then
      (umask 077; openssl rand -hex 32 > "$SECRET_FILE")
    fi
    supabase secrets set --project-ref "$REF" \
      "SB_SECRET_KEY=$SUPABASE_SECRET_KEY" \
      "FUNCTION_AUTH_SECRET=$(cat "$SECRET_FILE")" >/dev/null
    echo "set SB_SECRET_KEY and FUNCTION_AUTH_SECRET (values not shown)"
    ;;
  deploy)
    confirm
    for f in "${FUNCS[@]}"; do supabase functions deploy "$f" --project-ref "$REF"; done
    ;;
  vault)
    confirm
    [[ -s "$SECRET_FILE" ]] || { echo "run the 'secrets' stage first" >&2; exit 1; }
    sql="select vault.update_secret((select id from vault.secrets where name = 'anon_key'), '$(cat "$SECRET_FILE")');"
    printf '%s\n' "$sql" | pbcopy
    echo "SQL copied to clipboard. Paste it in Supabase > SQL Editor and run it, then clear the clipboard."
    ;;
  verify)
    need SUPABASE_URL
    url="${SUPABASE_URL%/}/functions/v1/daily-email-digest"
    echo "no secret : $(curl -s -o /dev/null -w '%{http_code}' -X POST "$url" -d '{}')  (want 401)"
    if [[ "${SEND_REAL_DIGEST:-}" == "yes" ]]; then
      echo "with secret: $(curl -s -o /dev/null -w '%{http_code}' -X POST "$url" -H "Authorization: Bearer $(cat "$SECRET_FILE")" -d '{}')  (want 200; SENDS the digest to users due this hour)"
    else
      echo "skipped the authorised call (it sends real email); set SEND_REAL_DIGEST=yes to run it"
    fi
    ;;
  legacy-check)
    need SUPABASE_URL; need LEGACY_SERVICE_ROLE_KEY
    code=$(curl -s -o /dev/null -w '%{http_code}' "${SUPABASE_URL%/}/rest/v1/" -H "apikey: $LEGACY_SERVICE_ROLE_KEY" -H "Authorization: Bearer $LEGACY_SERVICE_ROLE_KEY")
    echo "legacy service_role key -> HTTP $code (want 401)"; [[ "$code" == "401" ]]
    ;;
  *) sed -n 2,19p "$0"; exit 1 ;;
esac
