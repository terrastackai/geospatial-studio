#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0




mkdir -p workspace/$DEPLOYMENT_ENV/initialisation

echo "Populate auxiliary data for post-processing..."

set -a
source workspace/$DEPLOYMENT_ENV/env/.env
set +a

source workspace/$DEPLOYMENT_ENV/env/env.sh

if [[ "$ENVIRONMENT" == "local" ]]; then
    envsubst < deployment-scripts/template/populate-buckets-minio-pvc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-minio-pvc.yaml
    kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-minio-pvc.yaml -n $OC_PROJECT
else
    envsubst < deployment-scripts/template/populate-buckets-default-pvc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-default-pvc.yaml
    kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-default-pvc.yaml -n $OC_PROJECT
fi

envsubst < deployment-scripts/template/populate-buckets-with-initial-data.yaml > workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-with-initial-data.yaml

kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-with-initial-data.yaml -n $OC_PROJECT