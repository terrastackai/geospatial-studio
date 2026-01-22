#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0



# Initialisation
export DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
export OC_PROJECT=${OC_PROJECT}
export ENVIRONMENT=
export ROUTE_ENABLED=true
export CONTAINER_IMAGE_REPOSITORY=geospatial-studio

# POSTGRESQL version for cluster DB
export PG_VERSION=12.4.2

# CLUSTER
export CLUSTER_URL=

# Storage
export SHARE_PIPELINE_PVC=false
export COS_STORAGE_CLASS=
export NON_COS_STORAGE_CLASS=
export STORAGE_PVC_ENABLED=true
export STORAGE_FILESYSTEM_ENABLED=false
export CREATE_TUNING_FOLDERS_FLAG=true
export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=

# Populate buckets with data
export LULC_TILE_ROOT=
export LULC_TILE_SHAPEFILE=
export LAND_POLYGON_PATH=https://osmdata.openstreetmap.de/download/land-polygons-complete-4326.zip

# Redis configuration
export REDIS_ENABLED=true
export REDIS_FULL_NAME_OVERRIDE=geofm-redis
export REDIS_ARCHITECTURE=replication

# AUTH
export OAUTH_PROXY_ENABLED=true
export OAUTH_PROXY_PORT=8443
export OAUTH_TYPE=isv
export OAUTH_CLIENT_ID=
export OAUTH_ISSUER_URL=
export OAUTH_URL=https://geostudio.verify.ibm.com/v1.0/endpoint/default/authorize
export OAUTH_EXTRA_PROXY_ARGS=[--upstream-timeout=900s]
export CREATE_TLS_SECRET=false

# OBSERVABILITY
export OBSERVABILITY_ENABLED=false
export OBSERVABILITY_OTLP_ENDPOINT=
export OBSERVABILITY_OTLP_TRACES_ENDPOINT=

# Buckets
export BUCKET_FINE_TUNING=${DEPLOYMENT_ENV}-fine-tuning
export BUCKET_FINE_TUNING_MODELS=${DEPLOYMENT_ENV}-fine-tuning-models
export BUCKET_INFERENCE=${DEPLOYMENT_ENV}-inference
export BUCKET_DATASET_FACTORY=${DEPLOYMENT_ENV}-dataset-factory
export BUCKET_AMO_INPUT_BUCKET=${DEPLOYMENT_ENV}-amo-input-bucket
export BUCKET_GFM_MLFLOW=${DEPLOYMENT_ENV}-gfm-mlflow
export BUCKET_GEOSERVER=${DEPLOYMENT_ENV}-geoserver
export BUCKET_TEMP_UPLOAD=${DEPLOYMENT_ENV}-temp-upload
export BUCKET_INFERENCE_AUXDATA=${DEPLOYMENT_ENV}-inference-auxdata

# GPU_CONFIG
export CONFIGURE_GPU_AFFINITY_FLAG=false
export NODE_SELECTOR_KEY=nvidia.com/gpu.product
export NODE_GPU_SPEC=NVIDIA-A100-SXM4-80GB

# Geoserver config
export GEOSERVER_CM_PROXYBASEURL=
export GEOSERVER_CM_WHITELIST=