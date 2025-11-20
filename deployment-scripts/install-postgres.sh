#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0



UPDATE_STORAGE="$1"

set -a
source workspace/$DEPLOYMENT_ENV/env/.env
set +a

source workspace/$DEPLOYMENT_ENV/env/env.sh

oc project $OC_PROJECT

oc adm policy add-scc-to-user anyuid -n $OC_PROJECT -z default

if [[ -n "$UPDATE_STORAGE" ]]; then
    python ./deployment-scripts/update-postgres-geoserver-deployment.py --disable-pvc --filename deployment-scripts/create_postgres_local_pvc.yaml --storageclass ${NON_COS_STORAGE_CLASS} | kubectl apply -f - -n ${OC_PROJECT}
else
    kubectl apply -f deployment-scripts/create_postgres_local_pvc.yaml
fi

helm install postgresql --version $PG_VERSION bitnami/postgresql --set image.repository="bitnamilegacy/postgresql" --set primary.persistence.existingClaim="postgresql-pvc" --set global.postgresql.auth.postgresPassword=$POSTGRES_PASSWORD

