#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0



UPDATE_STORAGE="$1"
ENABLE_PV="$2"
DO_NOT_SET_SCC="$3"

set -a
source workspace/$DEPLOYMENT_ENV/env/.env
set +a

source workspace/$DEPLOYMENT_ENV/env/env.sh

oc project $OC_PROJECT

if [[ -n "$UPDATE_STORAGE" ]] && [[ -n "$ENABLE_PV" ]] && [[ "$ENABLE_PV" == "ENABLE_PV" ]]; then
    python ./deployment-scripts/update-deployment-template.py --filename deployment-scripts/create_postgres_local_pvc.yaml --storageclass ${NON_COS_STORAGE_CLASS} > workspace/$DEPLOYMENT_ENV/initialisation/create_postgres_local_pvc.yaml
    kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/create_postgres_local_pvc.yaml -n ${OC_PROJECT}
elif [[ -n "$UPDATE_STORAGE" ]]; then
    python ./deployment-scripts/update-deployment-template.py --disable-pvc --filename deployment-scripts/create_postgres_local_pvc.yaml --storageclass ${NON_COS_STORAGE_CLASS} > workspace/$DEPLOYMENT_ENV/initialisation/create_postgres_local_pvc.yaml
    kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/create_postgres_local_pvc.yaml -n ${OC_PROJECT}
else
    cp deployment-scripts/create_postgres_local_pvc.yaml workspace/$DEPLOYMENT_ENV/initialisation/create_postgres_local_pvc.yaml
    kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/create_postgres_local_pvc.yaml -n ${OC_PROJECT}
fi

if [[ -n "$DO_NOT_SET_SCC" ]] && [[ "$DO_NOT_SET_SCC" == "DO_NOT_SET_SCC" ]]; then
    helm install postgresql --version $PG_VERSION bitnami/postgresql --set postgresql.serviceAccount.name="default" --set image.repository="bitnamilegacy/postgresql" --set primary.persistence.existingClaim="postgresql-pvc" --set global.postgresql.auth.postgresPassword=$POSTGRES_PASSWORD --set volumePermissions.enabled=false --set shmVolume.enabled=false --set volumePermissions.image.repository="bitnamilegacy/os-shell" --set primary.podSecurityContext.fsGroup=null --set primary.securityContext.enabled=false --set primary.containerSecurityContext.enabled=false
else
    oc adm policy add-scc-to-user anyuid -n $OC_PROJECT -z default
    helm install postgresql --version $PG_VERSION bitnami/postgresql --set postgresql.serviceAccount.name="default" --set image.repository="bitnamilegacy/postgresql" --set primary.persistence.existingClaim="postgresql-pvc" --set global.postgresql.auth.postgresPassword=$POSTGRES_PASSWORD --set volumePermissions.enabled=true --set shmVolume.enabled=false --set volumePermissions.image.repository="bitnamilegacy/os-shell"
fi

