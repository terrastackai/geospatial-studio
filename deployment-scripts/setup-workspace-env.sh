#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0




mkdir -p workspace/$DEPLOYMENT_ENV/env

# Check if .env and env.sh exists
ENV_FILE="workspace/$DEPLOYMENT_ENV/env/.env"
ENV_SH_FILE="workspace/$DEPLOYMENT_ENV/env/env.sh"

if [ -e "$ENV_FILE" ] && [ -s "$ENV_FILE" ]; then
    CURRENT_TIMESTAMP=$(date +%s)
    ENV_BACKUP_DIR=workspace/$DEPLOYMENT_ENV/env_$CURRENT_TIMESTAMP
    mkdir -p $ENV_BACKUP_DIR
    mv $ENV_FILE "$ENV_BACKUP_DIR/.env"
    mv $ENV_SH_FILE "$ENV_BACKUP_DIR/env.sh"
fi
# Perform actions on the file here# if so append current timestamp to old env filename
envsubst < deployment-scripts/template/.env.template > $ENV_FILE
envsubst < deployment-scripts/template/env.template.sh > $ENV_SH_FILE
chmod a+x workspace/$DEPLOYMENT_ENV/env/.env
chmod a+x workspace/$DEPLOYMENT_ENV/env/env.sh

if [[ -n "$ENV_BACKUP_DIR" ]]; then
    python deployment-scripts/merge-env-files.py \
    --old-env-file "$ENV_BACKUP_DIR/.env" \
    --new-env-file workspace/$DEPLOYMENT_ENV/env/.env \
    --old-env-sh-file "$ENV_BACKUP_DIR/env.sh"\
    --new-env-sh-file workspace/$DEPLOYMENT_ENV/env/env.sh
fi

ENV_BACKUP_DIR=""
