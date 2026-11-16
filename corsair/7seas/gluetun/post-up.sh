#!/bin/sh
# Gluetun runs this on every VPN connection, once the forwarded port is known:
#   VPN_PORT_FORWARDING_UP_COMMAND=/bin/sh -c '/gluetun/post-up.sh {{PORT}}'
#
# 1. MyAnonamouse: re-authorise the current VPN IP with the dynamic seedbox API.
#    Needs MAM_SECRET_ID (an ASN-locked API session). MAM rate-limits this to
#    once per hour, so a 429 on repeat connects is expected.
# 2. Transmission: persist the forwarded port to gluetun/port/ (read by Transmission's
#    init script at start) and set it live over the RPC API.

set -u

PORT="${1:-}"
MAM_URL="https://t.myanonamouse.net/json/dynamicSeedbox.php"
MAM_COOKIE_JAR="/gluetun/mam.cookies"
RPC_URL="http://127.0.0.1:9091/transmission/rpc"
PORT_FILE="/gluetun/port/forwarded_port"

mam_dynamic_seedbox() {
  if [ -z "${MAM_SECRET_ID:-}" ]; then
    echo "[post-up] MAM_SECRET_ID not set, skipping MyAnonamouse"
    return 0
  fi

  {
    echo "# Netscape HTTP Cookie File"
    printf '.myanonamouse.net\tTRUE\t/\tTRUE\t2147483647\tmam_id\t%s\n' "$MAM_SECRET_ID"
  } > "$MAM_COOKIE_JAR"
  chmod 600 "$MAM_COOKIE_JAR"

  RES=$(wget -q -O - --content-on-error --load-cookies "$MAM_COOKIE_JAR" "$MAM_URL" 2>&1)
  echo "[post-up] MyAnonamouse dynamic seedbox: ${RES}"
}

transmission_peer_port() {
  SESSION_ID=$(
    wget --quiet --server-response "$RPC_URL" 2>&1 |
      grep 'X-Transmission-Session-Id:' |
      awk '{print $2}'
  )

  if [ -z "$SESSION_ID" ]; then
    echo "[post-up] transmission RPC not reachable, peer-port will be applied from the port file at its next start"
    return 0
  fi

  PAYLOAD=$(printf '{"method":"session-set","arguments":{"peer-port":%s}}' "$PORT")

  RES=$(
    wget --quiet \
      --header="Content-Type: application/json" \
      --header="X-Transmission-Session-Id: ${SESSION_ID}" \
      --post-data="${PAYLOAD}" \
      "$RPC_URL" \
      -O -
  )

  if [ "$RES" != '{"arguments":{},"result":"success"}' ]; then
    echo "[post-up] could not set transmission peer-port: ${RES}" >&2
    return 1
  fi

  echo "[post-up] transmission peer-port set to ${PORT}"
}

if [ -z "$PORT" ]; then
  echo "[post-up] no forwarded port given, aborting" >&2
  exit 1
fi

echo "[post-up] forwarded port is ${PORT}"
echo "$PORT" > "$PORT_FILE"

mam_dynamic_seedbox
transmission_peer_port
