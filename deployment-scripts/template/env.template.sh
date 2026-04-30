#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0



# Initialisation
export DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
export OC_PROJECT=${OC_PROJECT}
export ENVIRONMENT=
export ROUTE_ENABLED=${ROUTE_ENABLED:-true}
export CONTAINER_IMAGE_REPOSITORY=geospatial-studio

# POSTGRESQL version for cluster DB
export PG_VERSION=18.2.0

# CLUSTER
export CLUSTER_URL=

# Storage
export STORAGE_MODE=cloud-object-storage
export SHARE_PIPELINE_PVC=true
export COS_STORAGE_CLASS=
export NON_COS_STORAGE_CLASS=
export PVC_ACCESS_MODE=ReadWriteOnce
export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=

# GEOStudio Storage
export GFM_FT_DATA_STORAGE=15Gi
export GFM_FT_FILES_STORAGE=5Gi
export GFM_FT_MODELS_STORAGE=5Gi
export INFERENCE_SHARED_STORAGE=5Gi
export GFM_MLFLOW_STORAGE=1Gi
export INFERENCE_AUXDATA_STORAGE=1Gi
export GENERIC_PYTHON_PROCESSOR_STORAGE=1Gi
export REDIS_MASTER_STORAGE=1Gi
export REDIS_REPLICAS_STORAGE=1Gi

# Resource Configuration
export RESOURCE_MODE=dev

# MinIO Resources
export MINIO_CPU_REQUEST=2000m
export MINIO_CPU_LIMIT=4000m
export MINIO_MEMORY_REQUEST=2Gi
export MINIO_MEMORY_LIMIT=4Gi
export MINIO_STORAGE=40Gi

# Keycloak Resources
export KEYCLOAK_CPU_REQUEST=250m
export KEYCLOAK_CPU_LIMIT=1000m
export KEYCLOAK_MEMORY_REQUEST=512Mi
export KEYCLOAK_MEMORY_LIMIT=1Gi

# GeoServer Resources
export GEOSERVER_CPU_REQUEST='null'
export GEOSERVER_CPU_LIMIT='null'
export GEOSERVER_MEMORY_REQUEST='null'
export GEOSERVER_MEMORY_LIMIT='null'
export GEOSERVER_STORAGE=2Gi

# PostgreSQL Resources (Bitnami chart defaults)
export POSTGRES_CPU_REQUEST=250m
export POSTGRES_CPU_LIMIT=1000m
export POSTGRES_MEMORY_REQUEST=512Mi
export POSTGRES_MEMORY_LIMIT=1Gi
export POSTGRES_STORAGE=2Gi

# PgBouncer Resources
export PGBOUNCER_CPU_REQUEST=250m
export PGBOUNCER_CPU_LIMIT=1000m
export PGBOUNCER_MEMORY_REQUEST=256Mi
export PGBOUNCER_MEMORY_LIMIT=1Gi

# MLflow Resources
export MLFLOW_CPU_REQUEST='null'
export MLFLOW_CPU_LIMIT='null'
export MLFLOW_MEMORY_REQUEST='null'
export MLFLOW_MEMORY_LIMIT='null'

# Redis Master Resources
export REDIS_MASTER_CPU_REQUEST='null'
export REDIS_MASTER_CPU_LIMIT='null'
export REDIS_MASTER_MEMORY_REQUEST='null'
export REDIS_MASTER_MEMORY_LIMIT='null'

# Redis Replica Resources
export REDIS_REPLICA_CPU_REQUEST='null'
export REDIS_REPLICA_CPU_LIMIT='null'
export REDIS_REPLICA_MEMORY_REQUEST='null'
export REDIS_REPLICA_MEMORY_LIMIT='null'

# Gateway API Resources
export GATEWAY_API_CPU_REQUEST='null'
export GATEWAY_API_CPU_LIMIT='null'
export GATEWAY_API_MEMORY_REQUEST='null'
export GATEWAY_API_MEMORY_LIMIT='null'

# Gateway Celery Worker Resources
export GATEWAY_CELERY_WORKER_CPU_REQUEST='null'
export GATEWAY_CELERY_WORKER_CPU_LIMIT='null'
export GATEWAY_CELERY_WORKER_MEMORY_REQUEST='null'
export GATEWAY_CELERY_WORKER_MEMORY_LIMIT='null'

# Gateway OAuth Resources
export GATEWAY_OAUTH_CPU_REQUEST='null'
export GATEWAY_OAUTH_CPU_LIMIT='null'
export GATEWAY_OAUTH_MEMORY_REQUEST='null'
export GATEWAY_OAUTH_MEMORY_LIMIT='null'

# UI OAuth Resources
export UI_OAUTH_CPU_REQUEST='null'
export UI_OAUTH_CPU_LIMIT='null'
export UI_OAUTH_MEMORY_REQUEST='null'
export UI_OAUTH_MEMORY_LIMIT='null'

# UI Resources
export UI_CPU_REQUEST='null'
export UI_CPU_LIMIT='null'
export UI_MEMORY_REQUEST='null'
export UI_MEMORY_LIMIT='null'

# Populate buckets with data
export LULC_TILE_ROOT=
export LULC_TILE_SHAPEFILE=
export LAND_POLYGON_PATH=https://osmdata.openstreetmap.de/download/land-polygons-complete-4326.zip

# PgBouncer configuration (PostgreSQL connection pooler)
export PGBOUNCER_ENABLED=true
export PGBOUNCER_FULL_NAME_OVERRIDE=geofm-pgbouncer

# Redis configuration
export REDIS_ENABLED=true
export REDIS_FULL_NAME_OVERRIDE=geofm-redis
export REDIS_ARCHITECTURE=replication

# MinIO configuration
export MINIO_IMAGE=quay.io/minio/minio
export MINIO_TAG=latest
export MINIO_PERSISTENCE_ENABLED=true
export MINIO_STORAGE_SIZE=100Gi

# Pipelines configuration
export PIPELINES_ENABLED=true

# AUTH
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
export BUCKET_GENERIC_PYTHON_PROCESSOR=${DEPLOYMENT_ENV}-generic-python-processor


# GPU_CONFIG
export CONFIGURE_GPU_AFFINITY_FLAG=false
export CONFIGURE_GPU_AFFINITY=false
export NODE_SELECTOR_KEY=nvidia.com/gpu.product
export NODE_GPU_SPEC=NVIDIA-A100-SXM4-80GB

# Geoserver config
export GEOSERVER_CM_PROXYBASEURL=
export GEOSERVER_CM_WHITELIST=

# Operator configuration (for operator-based deployments)
export GEOSTUDIO_OPERATOR_IMAGE=${GEOSTUDIO_OPERATOR_IMAGE:-quay.io/geospatial-studio/geostudio-operator:latest}
export INSTALL_IBM_CSI_DRIVER=${INSTALL_IBM_CSI_DRIVER:-true}
export USER_NAMESPACE=${OC_PROJECT}
export OPERATOR_NAMESPACE=${OPERATOR_NAMESPACE:-geostudio-operator-system}
