#!/bin/bash
#
# OVH DynDNS updater.
# Keeps the A records of the zone apex (corsair.tf) and wildcard (*.corsair.tf)
# pointed at the current public IPv4 address, via the OVH API.
#
# Usage: dyndns.sh [--dry-run] [--list] [-v|--verbose]
#   --dry-run  show what would change, write nothing
#   --list     print the zone's A records (id, subdomain, target, ttl) and exit
#   -v         also print when nothing needed changing (default: silent unless
#              something changed or failed, so cron stays quiet)
#
# Credentials come from .env next to this script (OVH_ENDPOINT, OVH_APPLICATION_KEY,
# OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY, OVH_ZONE). Exit code is non-zero on any failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
LIST_ONLY=0
VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY_RUN=1 ;;
        --list)       LIST_ONLY=1 ;;
        -v|--verbose) VERBOSE=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

log()  { echo "$(date '+%F %T') $*"; }
vlog() { [ "$VERBOSE" = 1 ] && log "$@"; return 0; }
die()  { log "ERROR: $*" >&2; exit 1; }

# Never run two copies at once (cron every 15 min, slow API)
exec 9>"${TMPDIR:-/tmp}/ovh-dyndns.lock"
flock -n 9 || exit 0

command -v jq >/dev/null      || die "jq is required"
command -v openssl >/dev/null || die "openssl is required"

# Load .env without evaluating it as shell (KEY=value lines only).
# Variables already set in the environment win over the file.
if [ -f "$SCRIPT_DIR/.env" ]; then
    while IFS='=' read -r key value || [ -n "$key" ]; do
        case "$key" in ''|\#*) continue ;; esac
        [ -z "${!key+x}" ] && export "$key=$value"
    done < "$SCRIPT_DIR/.env"
fi

OVH_ENDPOINT="${OVH_ENDPOINT:-https://eu.api.ovh.com/1.0}"
OVH_APP_KEY="${OVH_APPLICATION_KEY:-}"
OVH_APP_SECRET="${OVH_APPLICATION_SECRET:-}"
OVH_CONSUMER_KEY="${OVH_CONSUMER_KEY:-}"
ZONE="${OVH_ZONE:-corsair.tf}"

for v in OVH_APP_KEY OVH_APP_SECRET OVH_CONSUMER_KEY; do
    [ -n "${!v}" ] || die "$v is empty (check .env)"
done

# --- public IP ----------------------------------------------------------------

is_public_ipv4() {
    local ip=$1 o
    [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
    for o in "${BASH_REMATCH[@]:1}"; do
        [ "$((10#$o))" -le 255 ] || return 1
    done
    # reject addresses that can't be our public IP (a captive portal or proxy answered)
    case "$ip" in
        0.*|10.*|127.*|169.254.*|192.168.*|100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*) return 1 ;;
        172.1[6-9].*|172.2[0-9].*|172.3[01].*) return 1 ;;
    esac
    return 0
}

fetch_ip() {
    local ip
    ip=$(curl -4 -fsS -m 8 "$1" 2>/dev/null | tr -d '[:space:]') || return 1
    is_public_ipv4 "$ip" && echo "$ip"
}

TARGET_IP=""
OTHER_IP=""
for url in https://api.ipify.org https://ifconfig.me/ip https://icanhazip.com; do
    ip=$(fetch_ip "$url") || continue
    if [ -z "$TARGET_IP" ]; then
        TARGET_IP=$ip
    else
        OTHER_IP=$ip
        break
    fi
done
[ -n "$TARGET_IP" ] || die "could not determine the public IPv4 (all lookup services failed)"
# Two services disagreeing means one of them is wrong: do not touch DNS
if [ -n "$OTHER_IP" ] && [ "$OTHER_IP" != "$TARGET_IP" ]; then
    die "IP lookup services disagree ($TARGET_IP vs $OTHER_IP), not updating DNS"
fi

# --- OVH API ------------------------------------------------------------------

API_CODE=""
API_BODY=""

# api METHOD PATH [BODY]  -> sets API_CODE / API_BODY, returns 0 on HTTP 2xx
# (call it directly, not inside $(...), or the globals are lost)
api() {
    local method=$1 path=$2 body=${3:-} url ts sig out
    url="$OVH_ENDPOINT$path"
    ts=$(curl -fsS -m 10 "$OVH_ENDPOINT/auth/time") || { API_CODE=000; API_BODY="auth/time failed"; return 1; }
    [[ $ts =~ ^[0-9]+$ ]] || { API_CODE=000; API_BODY="bad auth/time answer"; return 1; }
    sig='$1$'$(printf '%s' "$OVH_APP_SECRET+$OVH_CONSUMER_KEY+$method+$url+$body+$ts" | openssl dgst -sha1 | sed 's/^.* //')

    local args=(-sS -m 15 -X "$method" -w '\n%{http_code}'
        -H "Content-Type: application/json;charset=utf-8"
        -H "X-Ovh-Application: $OVH_APP_KEY"
        -H "X-Ovh-Timestamp: $ts"
        -H "X-Ovh-Signature: $sig"
        -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY")
    [ -n "$body" ] && args+=(--data "$body")

    out=$(curl "${args[@]}" "$url") || { API_CODE=000; API_BODY="curl failed"; return 1; }
    API_CODE=${out##*$'\n'}
    API_BODY=${out%$'\n'*}
    [[ $API_CODE =~ ^2 ]]
}

if [ "$LIST_ONLY" = 1 ]; then
    api GET "/domain/zone/$ZONE/record?fieldType=A" || die "list failed (HTTP $API_CODE): $API_BODY"
    for id in $(jq -r '.[]' <<<"$API_BODY"); do
        api GET "/domain/zone/$ZONE/record/$id" || die "get record $id failed (HTTP $API_CODE)"
        jq -r '"id=\(.id) subDomain=\"\(.subDomain // "")\" target=\(.target) ttl=\(.ttl)"' <<<"$API_BODY"
    done
    exit 0
fi

CHANGED=0
FAILED=0

# sync_record SUBDOMAIN LABEL
# SUBDOMAIN is "" for the apex or "*" for the wildcard. Every matching A record
# is checked (not just the first one) and the subdomain is verified on each.
sync_record() {
    local sub=$1 label=$2 ids id found=0 current

    api GET "/domain/zone/$ZONE/record?fieldType=A&subDomain=$sub" \
        || { log "ERROR: $label: listing records failed (HTTP $API_CODE): $API_BODY" >&2; FAILED=1; return; }
    ids=$(jq -r '.[]' <<<"$API_BODY") || { log "ERROR: $label: bad API answer" >&2; FAILED=1; return; }

    for id in $ids; do
        api GET "/domain/zone/$ZONE/record/$id" \
            || { log "ERROR: $label: reading record $id failed (HTTP $API_CODE)" >&2; FAILED=1; continue; }
        # the API filter is loose for the apex: only touch records whose subDomain really matches
        [ "$(jq -r '.subDomain // ""' <<<"$API_BODY")" = "$sub" ] || continue
        [ "$(jq -r '.fieldType' <<<"$API_BODY")" = "A" ] || continue
        found=1
        current=$(jq -r '.target' <<<"$API_BODY")

        if [ "$current" = "$TARGET_IP" ]; then
            vlog "$label (record $id): already $TARGET_IP"
            continue
        fi

        if [ "$DRY_RUN" = 1 ]; then
            log "DRY-RUN: would update $label (record $id): $current -> $TARGET_IP"
            continue
        fi

        if api PUT "/domain/zone/$ZONE/record/$id" "{\"target\":\"$TARGET_IP\"}"; then
            log "updated $label (record $id): $current -> $TARGET_IP"
            CHANGED=1
        else
            log "ERROR: $label: update of record $id failed (HTTP $API_CODE): $API_BODY" >&2
            FAILED=1
        fi
    done

    if [ "$found" = 0 ]; then
        log "ERROR: $label: no A record found in zone $ZONE" >&2
        FAILED=1
    fi
}

vlog "public IP: $TARGET_IP, zone: $ZONE"
sync_record ""  "apex ($ZONE)"
sync_record "*" "wildcard (*.$ZONE)"

if [ "$CHANGED" = 1 ]; then
    if api POST "/domain/zone/$ZONE/refresh"; then
        log "zone refreshed"
    else
        log "ERROR: zone refresh failed (HTTP $API_CODE): $API_BODY" >&2
        FAILED=1
    fi
fi

[ "$FAILED" = 0 ] || exit 1
vlog "done"
exit 0
