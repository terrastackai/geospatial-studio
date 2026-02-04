# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0



echo "Client Secret: $client_secret"

export KC_TOKEN=`curl --request POST --url http://localhost:8080/realms/master/protocol/openid-connect/token \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data client_id=admin-cli \
  --data grant_type=password \
  --data username=admin \
  --data password=admin | jq -r '.access_token'`

curl --silent --show-error -L -X POST "http://localhost:8080/admin/realms" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ""$KC_TOKEN" \
--data '{"realm": "geostudio", "enabled": true}'

curl --silent --show-error -L -X POST "http://localhost:8080/admin/realms/geostudio/clients" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ""$KC_TOKEN" \
--data '{"clientId": "geostudio-client", "enabled": true, "clientAuthenticatorType": "client-secret", "secret": "'${client_secret}'", "redirectUris": ["https://geofm-ui.'${OC_PROJECT}'.svc.cluster.local:4180/oauth2/callback", "https://geofm-gateway.'${OC_PROJECT}'.svc.cluster.local:4180/oauth2/callback", "https://localhost:4180/oauth2/callback", "https://localhost:4181/oauth2/callback", "https://geofm-ui-'${OC_PROJECT}'.'${CLUSTER_URL}'/oauth2/callback", "https://geofm-gateway-'${OC_PROJECT}'.'${CLUSTER_URL}'/oauth2/callback"], "webOrigins": ["*"], "notBefore": 0, "bearerOnly": false, "consentRequired": false, "standardFlowEnabled": true, "implicitFlowEnabled": true, "directAccessGrantsEnabled": true, "serviceAccountsEnabled": true, "publicClient": false, "frontchannelLogout": true, "protocol": "openid-connect","attributes":{"oidc.ciba.grant.enabled": "false", "oauth2.device.authorization.grant.enabled": "false", "backchannel.logout.session.required": "true", "backchannel.logout.revoke.offline.tokens": "false"}}'

client_uuid=`curl -X GET "http://localhost:8080/admin/realms/geostudio/clients?clientId=geostudio-client" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ""$KC_TOKEN" | jq -r '.[0].id' | tr -d '"'`

echo "Client UUID: $client_uuid"

export client_secret=`curl -X GET "http://localhost:8080/admin/realms/geostudio/clients/$client_uuid/client-secret" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ""$KC_TOKEN" | jq -r '.value' | tr -d '"'`

echo "Client Secret: $client_secret"
sed -i -e "s/oauth_client_secret=.*/oauth_client_secret=$client_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env

curl --show-error -L -X POST "http://localhost:8080/admin/realms/geostudio/users" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ""$KC_TOKEN" \
--data '{"username": "testuser", "email": "test@example.com", "enabled": true, "firstName": "Test", "lastName": "User", "emailVerified": true}'

user_id=`curl -X GET "http://localhost:8080/admin/realms/geostudio/users?username=testuser" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ""$KC_TOKEN" | jq '.[0].id' | tr -d '"'`

echo "User ID: $user_id"

curl --silent --show-error -L -X PUT "http://localhost:8080/admin/realms/geostudio/users/$user_id/reset-password" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ""$KC_TOKEN" \
--data '{"type": "password","value": "testpass123","temporary": false}'




