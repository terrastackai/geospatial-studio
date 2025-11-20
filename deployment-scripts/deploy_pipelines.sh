#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0




source workspace/$DEPLOYMENT_ENV/env/.env
helm upgrade -f workspace/$DEPLOYMENT_ENV/values/geospatial-studio-pipelines/values-deploy.yaml studio-pipelines \
            ./geospatial-studio-pipelines/ \
            --install \
            --history-max 5 \
            --set "imagePullSecret.b64secret=${image_pull_secret_b64}" \
            --set "orchestrate_db.pg_username=${pg_username}" \
            --set "orchestrate_db.pg_password=${pg_password}" \
            --set "orchestrate_db.pg_uri=${pg_uri}" \
            --set "orchestrate_db.pg_port=${pg_port}" \
            --set "orchestrate_db.pg_studio_db_name=${pg_studio_db_name}" \
            --set "gateway.api_key=${studio_api_key}" \
            --set "geoserver.username=${geoserver_username}" \
            --set "geoserver.password=${geoserver_password}" \
            --set "sentinelhub.client_id=${sh_client_id}" \
            --set "sentinelhub.client_secret=${sh_client_secret}" \
            --set "nasaEarthBearerToken=${nasa_earth_data_bearer_token}" \
            --set "objectStorage.endpoint=${endpoint}" \
            --set "objectStorage.region=${region}" \
            --set "objectStorage.access_key=${access_key_id}" \
            --set "objectStorage.secret_key=${secret_access_key}" 
            # --dry-run > pipelines-deploy-dry-run.yaml
