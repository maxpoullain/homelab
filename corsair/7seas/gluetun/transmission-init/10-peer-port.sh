#!/bin/bash
# Applies the port forwarded by Gluetun to Transmission once the daemon is up.
# Runs in the background so the container's init chain is not blocked.
PORT_FILE="${PORT_FILE:-/port/forwarded_port}"
RPC_URL="${RPC_URL:-http://127.0.0.1:9091/transmission/rpc}"

apply_peer_port() {
  local port sid resp
  [[ -f "$PORT_FILE" ]] || return 1
  port=$(tr -d '[:space:]' < "$PORT_FILE")
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  sid=$(curl -s -i "$RPC_URL" | awk -F': ' 'tolower($1)=="x-transmission-session-id" {gsub(/\r/,"",$2); print $2}')
  [[ -n "$sid" ]] || return 1
  resp=$(curl -s -H "X-Transmission-Session-Id: $sid" -H 'Content-Type: application/json' \
    -d "{\"method\":\"session-set\",\"arguments\":{\"peer-port\":$port}}" "$RPC_URL")
  [[ "$resp" == '{"arguments":{},"result":"success"}' ]] || return 1
  echo "[peer-port] set to ${port} from ${PORT_FILE}"
}

(
  for _ in $(seq 1 360); do
    apply_peer_port && exit 0
    sleep 10
  done
  echo "[peer-port] gave up waiting for transmission or ${PORT_FILE}" >&2
) </dev/null &
