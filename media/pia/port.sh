#!/bin/bash

TRANSMISSION_RPC_ENDPOINT=localhost:9091/transmission/rpc
port=$(cat "$1")

echo "Setting transmission port settings in vars..."
echo "PEERPORT=$port" > '/secrets.env'

echo "Checking if tranmission is running..."
while ! curl --silent --retry 10 --retry-delay 15 --max-time 10 \
  "$TRANSMISSION_RPC_ENDPOINT" > /dev/null
  do
    echo "Transmission is not running trying again in 10 seconds..."
    sleep 10
  done

echo "Resolving session id: $session_id..."
session_id=`curl --silent --retry 10 --retry-delay 15 --max-time 10 $TRANSMISSION_RPC_ENDPOINT | sed 's/.*<code>X-Transmission-Session-Id: \(.*\)<\/code>.*/\1/g'`

echo "Setting transmission port settings ($port) using session id: $session_id..."
curl --silent --retry 10 --retry-delay 15 --max-time 10 \
  -H "X-Transmission-Session-Id: $session_id" \
  -H 'Content-Type: text/plain;charset=UTF-8' \
  --data-raw "{\"arguments\":{\"peer-port\":$port},\"method\":\"session-set\"}" \
  "$TRANSMISSION_RPC_ENDPOINT"