#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0




mkdir -p workspace/$DEPLOYMENT_ENV/namespaces

sed "s/\OC_PROJECT/$OC_PROJECT/" deployment-scripts/template/create_namespace.yaml > workspace/$DEPLOYMENT_ENV/namespaces/create_namespace.yaml
kubectl apply -f workspace/$DEPLOYMENT_ENV/namespaces/create_namespace.yaml