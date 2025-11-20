# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


curl -X POST "$UI_ROUTE_URL/studio-gateway/v2/models" \
  --header 'Content-Type: application/json' \
  --header "X-API-Key: $STUDIO_API_KEY" \
  --insecure \
  --data @populate-studio/payloads/sandbox-models/model-try-in-lab.json

curl -X POST "$UI_ROUTE_URL/studio-gateway/v2/models" \
  --header 'Content-Type: application/json' \
  --header "X-API-Key: $STUDIO_API_KEY" \
  --insecure \
  --data @populate-studio/payloads/sandbox-models/model-add-layer.json