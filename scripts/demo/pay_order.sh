#!/usr/bin/env bash
# Plays Stripe's part in the demo profile: sends a signed webhook for an order.
#
#   scripts/demo/pay_order.sh <orderId> <amount> [event]
#
#   event defaults to payment_intent.succeeded; also try payment_intent.processing
#   (keeps the drop hold alive like a real in-flight payment).
#
# Env: API_BASE_URL (default http://localhost:8080), STRIPE_WEBHOOK_SECRET (must match the backend).
set -euo pipefail

ORDER_ID="${1:?usage: pay_order.sh <orderId> <amount> [event]}"
AMOUNT="${2:?usage: pay_order.sh <orderId> <amount> [event]}"
EVENT="${3:-payment_intent.succeeded}"
BASE="${API_BASE_URL:-http://localhost:8080}"
SECRET="${STRIPE_WEBHOOK_SECRET:-whsec_demo}"

CENTS=$(awk -v a="$AMOUNT" 'BEGIN { printf "%d", (a * 100) + 0.5 }')
TS=$(date +%s)
PAYLOAD=$(printf '{"id":"evt_demo_%s_%s_%s","type":"%s","data":{"object":{"id":"pi_demo_%s","object":"payment_intent","amount":%s,"currency":"inr","status":"succeeded","metadata":{"orderId":"%s"}}}}' \
  "$ORDER_ID" "$EVENT" "$TS" "$EVENT" "$ORDER_ID" "$CENTS" "$ORDER_ID")
SIG=$(printf '%s' "$TS.$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/^.* //')

curl -sS -w '\nHTTP %{http_code}\n' -X POST "$BASE/payment/webhook" \
  -H "Stripe-Signature: t=$TS,v1=$SIG" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD"
