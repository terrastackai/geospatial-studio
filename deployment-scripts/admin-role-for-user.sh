#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0




oc get group $OC_PROJECT-admin -o yaml | yq e '.users += [ env(USER_TO_ADD) ]' | oc apply -f -
