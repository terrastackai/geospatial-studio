#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0




source workspace/$DEPLOYMENT_ENV/env/.env
helm upgrade -f workspace/$DEPLOYMENT_ENV/values/geospatial-studio/values-deploy.yaml studio \
            ./geospatial-studio/ \
            --install \
            --wait \
            --history-max 5 \
            --set "global.imagePullSecret.b64secret=${image_pull_secret_b64}" \
            --set "global.postgres.backend_uri_base=postgresql+pg8000://${pg_username}:${pg_password}@${pg_uri}:${pg_port}" \
            --set "global.postgres.dbs.gateway=${pg_studio_db_name}" \
            --set "global.postgres.dbs.auth=${pg_studio_db_name}_auth" \
            --set "global.gfmStudioGateway.api_key=${studio_api_key}" \
            --set "global.gfmStudioGateway.api_encryption_key=${studio_api_encryption_key}" \
            --set "global.mapbox.token=${mapbox_token}" \
            --set "global.cesium.token=${cesium_token}" \
            --set "global.jira.api_key=${jira_api_key}" \
            --set "global.redis.password=${redis_password}" \
            --set "global.sentinelhub.client_id=${sh_client_id}" \
            --set "global.sentinelhub.client_secret=${sh_client_secret}" \
            --set "global.objectStorage.endpoint=${endpoint}" \
            --set "global.objectStorage.region=${region}" \
            --set "global.oauth.clientSecret=${oauth_client_secret}" \
            --set "global.oauth.tlsCrtB64=${tls_crt_b64}" \
            --set "global.oauth.tlsKeyB64=${tls_key_b64}" \
            --set "global.oauth.cookieSecret=${oauth_cookie_secret}" \
            --set "global.objectStorage.access_key=${access_key_id}" \
            --set "global.objectStorage.secret_key=${secret_access_key}"
            # --dry-run > studio-deploy-dry-run.yaml
