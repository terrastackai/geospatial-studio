#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0




mkdir -p workspace/$DEPLOYMENT_ENV/roles

sed "s/\OC_PROJECT/$OC_PROJECT/" deployment-scripts/template/admin-role-for-namespace.yaml > workspace/$DEPLOYMENT_ENV/roles/admin-role-for-namespace.yaml
oc apply -f workspace/$DEPLOYMENT_ENV/roles/admin-role-for-namespace.yaml
