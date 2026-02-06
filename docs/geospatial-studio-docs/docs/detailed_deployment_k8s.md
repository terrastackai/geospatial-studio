# Geospatial Studio - Kubernetes Deployment Guide

This guide provides detailed step-by-step instructions for deploying Geospatial Studio on a Kubernetes cluster. These instructions are derived from the automated deployment script and provide a manual approach for better understanding and control of the deployment process.

> **Note:** All commands should be run from the root directory of the [geospatial-studio repository](https://github.com/terrastackai/geospatial-studio).

## Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl CLI configured to access your cluster
- [Helm](https://helm.sh/docs/v3/) v3.19 (currently incompatible with v4)
- [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html) (includes kubectl)
- [jq](https://github.com/jqlang/jq) - JSON command-line processor
- [yq](https://github.com/mikefarah/yq) - YAML command-line processor
- Python 3.8+ with pip
- OpenSSL
- Minimum cluster resources: 8GB RAM, 4 CPUs

## Deployment Overview

The deployment process consists of the following major steps:

1. [Environment Setup](#1-environment-setup)
2. [Node Configuration](#2-node-configuration)
3. [MinIO Deployment (Object Storage)](#3-minio-deployment)
4. [PostgreSQL Deployment (Database)](#4-postgresql-deployment)
5. [Keycloak Deployment (Authentication)](#5-keycloak-deployment)
6. [TLS Configuration](#6-tls-configuration)
7. [Geoserver Deployment](#7-geoserver-deployment)
8. [Studio Configuration](#8-studio-configuration)
9. [Deploy Geospatial Studio Services](#9-deploy-geospatial-studio-services)
10. [Port Forwarding Setup](#10-port-forwarding-setup)
11. [Testing](#11-testing)

---

## 1. Environment Setup

### 1.1 Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 1.2 Set Environment Variables

Define your deployment environment name and namespace:

```bash
export DEPLOYMENT_ENV=k8s
export OC_PROJECT=default
export IMAGE_REGISTRY=geospatial-studio
```

> **Note:** Replace `default` with your actual namespace name.

### 1.3 Initialize Workspace Environment

Run the setup script to create the workspace directory structure and environment files:

```bash
./deployment-scripts/setup-workspace-env.sh
```

This creates:
- `workspace/${DEPLOYMENT_ENV}/env/env.sh` - General configuration variables
- `workspace/${DEPLOYMENT_ENV}/env/.env` - Secret values and credentials

### 1.4 Update Cluster Configuration

Edit `workspace/${DEPLOYMENT_ENV}/env/env.sh` to set your cluster URL:

```bash
sed -i -e "s/export CLUSTER_URL=.*/export CLUSTER_URL=localhost/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export DEPLOYMENT_ENV=.*/export DEPLOYMENT_ENV=k8s/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OC_PROJECT=.*/export OC_PROJECT=$OC_PROJECT/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
```

### 1.5 Source Environment Variables

```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

---

## 2. Node Configuration

### 2.1 Label Kubernetes Nodes

Label your worker node with topology information required by storage drivers:

```bash
kubectl label nodes studio-worker topology.kubernetes.io/region=us-east-1 topology.kubernetes.io/zone=us-east-1a
```

> **Note:** Replace `studio-worker` with your actual worker node name. You can list nodes with `kubectl get nodes`.

---

## 3. MinIO Deployment

MinIO provides S3-compatible object storage for the Geospatial Studio.

### 3.1 Generate TLS Certificates for MinIO

```bash
# Generate private key
openssl genrsa -out minio-private.key 2048

# Generate self-signed certificate
sed -e "s/default/$OC_PROJECT/g" deployment-scripts/minio-openssl.conf > workspace/$DEPLOYMENT_ENV/initialisation/minio-user-openssl.conf
openssl req -new -x509 -nodes -days 730 -keyout minio-private.key -out minio-public.crt --config workspace/$DEPLOYMENT_ENV/initialisation/minio-user-openssl.conf
```

### 3.2 Create Kubernetes Secrets and ConfigMaps

```bash
# Create TLS secret for MinIO
kubectl create secret tls minio-tls-secret --cert=minio-public.crt --key=minio-private.key -n ${OC_PROJECT} --dry-run=client -o yaml > workspace/$DEPLOYMENT_ENV/initialisation/minio-tls-secret.yaml
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-tls-secret.yaml -n ${OC_PROJECT}

# Create ConfigMap for CSI driver (required by IBM Object CSI Driver)
kubectl create configmap minio-public-config --from-file=minio-public.crt -n kube-system --dry-run=client -o yaml > workspace/$DEPLOYMENT_ENV/initialisation/minio-public-config.yaml
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-public-config.yaml -n kube-system
```

### 3.3 Deploy MinIO

```bash
# Deploy MinIO with storage class configuration
python ./deployment-scripts/update-deployment-template.py --disable-route --filename deployment-scripts/minio-deployment.yaml --storageclass standard > workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml -n ${OC_PROJECT}

# Wait for MinIO to be ready
kubectl wait --for=condition=ready pod -l app=minio -n ${OC_PROJECT} --timeout=300s
```

### 3.4 Set Up Port Forwarding for MinIO Console

```bash
# Port forward MinIO console (runs in background)
kubectl port-forward -n ${OC_PROJECT} svc/minio 9001:9001 >> studio-pf.log 2>&1 &
sleep 5
```

### 3.5 Install IBM Object CSI Driver

The IBM Object CSI Driver enables dynamic provisioning of S3-compatible storage:

```bash
# Apply the CSI driver manifests
cp -R deployment-scripts/ibm-object-csi-driver workspace/$DEPLOYMENT_ENV/initialisation
sed -e "s/default/$OC_PROJECT/g" deployment-scripts/template/cos-s3-csi-s3fs-sc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-s3fs-sc.yaml
sed -e "s/default/$OC_PROJECT/g" deployment-scripts/template/cos-s3-csi-sc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-sc.yaml
kubectl apply -k workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/

# Wait for CSI controller to be ready
kubectl wait --for=condition=ready pod -l app=cos-s3-csi-controller -n kube-system --timeout=300s

# Wait for CSI driver to be ready
kubectl wait --for=condition=ready pod -l app=cos-s3-csi-driver -n kube-system --timeout=300s
```

### 3.6 Update Environment Configuration for MinIO

Update the `.env` file with MinIO connection details for local access:

```bash
sed -i -e "s/access_key_id=.*/access_key_id=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/secret_access_key=.*/secret_access_key=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s|endpoint=.*|endpoint=https://localhost:9000|g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/region=.*/region=us-east-1/g" workspace/${DEPLOYMENT_ENV}/env/.env
```

### 3.7 Configure Storage Classes

Set the storage class environment variables:

```bash
sed -i -e "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=cos-s3-csi-s3fs-sc/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=standard/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
```

### 3.8 Set Up Port Forwarding for MinIO API

```bash
# Port forward MinIO API
kubectl port-forward -n $OC_PROJECT svc/minio 9000:9000 >> studio-pf.log 2>&1 &
sleep 5
```

### 3.9 Create S3 Buckets

```bash
# Create required buckets using Python script
python deployment-scripts/create_buckets.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env
```

### 3.10 Update MinIO Endpoint for In-Cluster Access

After creating buckets, update the endpoint to use the internal cluster DNS:

```bash
sed -i -e "s|endpoint=.*|endpoint=https://minio.$OC_PROJECT.svc.cluster.local:9000|g" workspace/${DEPLOYMENT_ENV}/env/.env
```

### 3.11 Reload Environment Variables

```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

---

## 4. PostgreSQL Deployment

PostgreSQL is used for storing metadata and operational data.

### 4.1 Add Bitnami Helm Repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 4.2 Set PostgreSQL Password

```bash
export POSTGRES_PASSWORD=devPostgresql123
```

> **Important:** For production deployments, use a strong, randomly generated password.

### 4.3 Install PostgreSQL

```bash
# Install PostgreSQL with storage configuration
./deployment-scripts/install-postgres.sh UPDATE_STORAGE ENABLE_PV

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod/postgresql-0 -n ${OC_PROJECT} --timeout=300s
```

### 4.4 Set Up Port Forwarding for PostgreSQL

```bash
# Port forward PostgreSQL for local access
kubectl port-forward --namespace ${OC_PROJECT} svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
sleep 5
```

### 4.5 Update Environment Configuration for PostgreSQL

Update the `.env` file with PostgreSQL connection details for local access:

```bash
sed -i -e "s/pg_username=.*/pg_username=postgres/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/pg_password=.*/pg_password=${POSTGRES_PASSWORD}/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/pg_uri=.*/pg_uri=127.0.0.1/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/pg_port=.*/pg_port=5432/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/pg_original_db_name=.*/pg_original_db_name='postgres'/g" workspace/${DEPLOYMENT_ENV}/env/.env
```

### 4.6 Create Studio Databases

```bash
# Create required databases and users
python deployment-scripts/create_studio_dbs.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env
```

### 4.7 Update PostgreSQL URI for In-Cluster Access

After creating databases, update the URI to use the internal cluster DNS:

```bash
sed -i -e "s/pg_uri=.*/pg_uri=postgresql.$OC_PROJECT.svc.cluster.local/g" workspace/${DEPLOYMENT_ENV}/env/.env
```

### 4.8 Reload Environment Variables

```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

---

## 5. Keycloak Deployment

Keycloak provides OAuth2 authentication for the Geospatial Studio.

### 5.1 Deploy Keycloak

```bash
# Deploy Keycloak with environment-specific configuration
python ./deployment-scripts/update-keycloak-deployment.py --disable-route --filename deployment-scripts/keycloak-deployment.yaml --env-path workspace/${DEPLOYMENT_ENV}/env/.env > workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml -n ${OC_PROJECT}

# Wait for Keycloak to be ready
kubectl wait --for=condition=ready pod -l app=keycloak -n ${OC_PROJECT} --timeout=300s
```

### 5.2 Set Up Port Forwarding for Keycloak

```bash
# Port forward Keycloak for local access
kubectl port-forward -n ${OC_PROJECT} svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
sleep 5
```

### 5.3 Generate OAuth Secrets

```bash
# Generate client secret (32 characters)
export client_secret=$(cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32)

# Generate cookie secret (32 characters)
export cookie_secret=$(cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32)
```

### 5.4 Configure Keycloak Realm and Client

Run the automated setup script:

```bash
./deployment-scripts/setup-keycloak.sh
```

This script will:
- Create the `geostudio` realm
- Create the `geostudio-client` OAuth client
- Configure redirect URIs
- Create a test user (`testuser` / `testpass123`)

### 5.5 Update Environment Configuration for Keycloak

```bash
# Update cookie secret in .env
sed -i -e "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env

# Update OAuth configuration in env.sh
sed -i -e "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export OAUTH_URL=.*|export OAUTH_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio/protocol/openid-connect/auth|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
```

---

## 6. TLS Configuration

### 6.1 Generate TLS Certificate and Key

```bash
# Generate self-signed certificate for Kubernetes services
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=$OC_PROJECT.svc.cluster.local"
```

### 6.2 Encode Certificates to Base64

```bash
# Extract and encode certificate
export TLS_CRT_B64=$(openssl base64 -in tls.crt -A)

# Extract and encode key
export TLS_KEY_B64=$(openssl base64 -in tls.key -A)
```

### 6.3 Update Environment Configuration

```bash
# Update .env with base64-encoded TLS credentials
sed -i -e "s/tls_crt_b64=.*/tls_crt_b64=$TLS_CRT_B64/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/tls_key_b64=.*/tls_key_b64=$TLS_KEY_B64/g" workspace/${DEPLOYMENT_ENV}/env/.env

# Enable TLS secret creation
sed -i -e "s/export CREATE_TLS_SECRET=.*/export CREATE_TLS_SECRET=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
```

---

## 7. Geoserver Deployment

Geoserver provides geospatial data visualization and serving capabilities.

### 7.1 Set Geoserver Credentials

```bash
export GEOSERVER_USERNAME="admin"
export GEOSERVER_PASSWORD="geoserver"
export GEOSERVER_URL=http://localhost:3000/geoserver
```

### 7.2 Update Environment Configuration

```bash
sed -i -e "s/geoserver_username=.*/geoserver_username=$GEOSERVER_USERNAME/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/geoserver_password=.*/geoserver_password=$GEOSERVER_PASSWORD/g" workspace/${DEPLOYMENT_ENV}/env/.env
```

### 7.3 Deploy Geoserver

```bash
# Deploy Geoserver with storage configuration
python ./deployment-scripts/update-deployment-template.py --filename deployment-scripts/geoserver-deployment.yaml --storageclass standard --proxy-base-url $(printf "http://geofm-geoserver-%s.svc.cluster.local:3000/geoserver" "$OC_PROJECT") --disable-route > workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n ${OC_PROJECT}

# Wait for Geoserver to be ready (may take up to 15 minutes)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gfm-geoserver -n ${OC_PROJECT} --timeout=900s
```

### 7.4 Set Up Port Forwarding for Geoserver

```bash
# Port forward Geoserver
kubectl port-forward -n ${OC_PROJECT} svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
sleep 5
```

### 7.5 Configure Geoserver

```bash
# Run Geoserver setup script
./deployment-scripts/setup_geoserver.sh
```

This script configures:
- Workspaces
- Data stores
- Layers
- Styles

---

## 8. Studio Configuration

### 8.1 Generate or Load API Keys

The following script will generate new API keys or load existing ones from `.studio-api-key`:

```bash
file=./.studio-api-key
if [ -e "$file" ]; then
    echo "File exists - loading existing keys"
    source $file
else 
    echo "Generating new API keys"
    export STUDIO_API_KEY=$(echo "pak-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)")
    export API_ENCRYPTION_KEY=$(echo "$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')")
    echo "export STUDIO_API_KEY=$STUDIO_API_KEY" > ./.studio-api-key
    echo "export API_ENCRYPTION_KEY=$API_ENCRYPTION_KEY" >> ./.studio-api-key
fi
```

> **Important:** Keep the `.studio-api-key` file secure and backed up. It's required for redeployments.

### 8.2 Update Studio Configuration

```bash
# Update API keys
sed -i -e "s/studio_api_key=.*/studio_api_key=$STUDIO_API_KEY/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/studio_api_encryption_key=.*/studio_api_encryption_key=$API_ENCRYPTION_KEY/g" workspace/${DEPLOYMENT_ENV}/env/.env

# Update Redis password
sed -i -e "s/redis_password=.*/redis_password=devPassword/g" workspace/${DEPLOYMENT_ENV}/env/.env

# Update image pull secret (if required)
# Replace with your actual base64-encoded image pull secret
sed -i -e "s/image_pull_secret_b64=.*/image_pull_secret_b64=\"${STUDIO_IMAGE_PULL_SECRET}\"/g" workspace/${DEPLOYMENT_ENV}/env/.env
```

### 8.3 Configure Environment Settings

```bash
# Set environment type
sed -i -e "s/export ENVIRONMENT=.*/export ENVIRONMENT=local/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

# Disable OpenShift routes (using port-forwarding instead)
sed -i -e "s/export ROUTE_ENABLED=.*/export ROUTE_ENABLED=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

# Configure storage settings
sed -i -e "s/export SHARE_PIPELINE_PVC=.*/export SHARE_PIPELINE_PVC=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export STORAGE_PVC_ENABLED=.*/export STORAGE_PVC_ENABLED=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export STORAGE_FILESYSTEM_ENABLED=.*/export STORAGE_FILESYSTEM_ENABLED=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export CREATE_TUNING_FOLDERS_FLAG=.*/export CREATE_TUNING_FOLDERS_FLAG=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=.*|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=/data|g" workspace/${DEPLOYMENT_ENV}/env/env.sh

# Enable OAuth proxy
sed -i -e "s/export OAUTH_PROXY_ENABLED=.*/export OAUTH_PROXY_ENABLED=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

# Set container image repository
sed -i -e "s/export CONTAINER_IMAGE_REPOSITORY=.*/export CONTAINER_IMAGE_REPOSITORY=${IMAGE_REGISTRY}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
```

### 8.4 Reload Environment Variables

```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

---

## 9. Deploy Geospatial Studio Services

### 9.1 Generate Deployment Values Files

```bash
# Generate values.yaml files for both charts
./deployment-scripts/values-file-generate.sh
```

This creates:
- `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`

### 9.2 Create Deployment Copies

```bash
# Create deployment-specific copies
cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
```

### 9.3 Configure GPU Settings (Optional)

Check if NVIDIA GPUs are available and configure accordingly:

```bash
# Check for NVIDIA GPUs
NVIDIA_GPUS_AVAILABLE=$(kubectl describe node studio-worker | grep -c "nvidia.com")

if [ "$NVIDIA_GPUS_AVAILABLE" -gt 0 ]; then
    echo "Cluster Type: GPU-enabled"
    # Remove only GPU affinity, keep GPU resources
    python ./deployment-scripts/remove-pipeline-gpu.py --remove-affinity-only workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
else
    echo "Cluster Type: standard (no GPU)"
    # Remove all GPU configurations
    python ./deployment-scripts/remove-pipeline-gpu.py workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
fi
```

### 9.4 Review Deployment Values

**IMPORTANT:** Review and customize the deployment values before proceeding:

```bash
# Review studio values
cat workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
```

Make any necessary adjustments to:
- Resource limits and requests
- Storage configurations
- Service-specific settings
- Feature flags

**Pause here to review the values files. Press Enter when ready to continue.**

```bash
printf "%s " "Press enter to continue"
read ans
```

### 9.5 Build Helm Dependencies

```bash
# Update and build dependencies
helm dep update ./geospatial-studio/
helm dependency build ./geospatial-studio/
```

### 9.6 Deploy Geospatial Studio Core

```bash
# Deploy the main studio services
./deployment-scripts/deploy_studio.sh
```

This deploys:
- UI service
- Gateway API
- MLflow
- Redis
- Inference pipelines
- Data processing pipelines
- Model training pipelines
- Other core services

---

## 10. Port Forwarding Setup

### 10.1 Wait for Services to be Ready

```bash
# Wait for gateway to be ready
kubectl wait --for=condition=ready pod -l app=geofm-gateway -n ${OC_PROJECT} --timeout=300s
```

### 10.2 Set Up Port Forwarding

```bash
# UI (OAuth-protected)
kubectl port-forward deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &

# Gateway API (OAuth-protected)
kubectl port-forward deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &

# MLflow
kubectl port-forward deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
```

### 10.3 Configure /etc/hosts (Important)

Add internal cluster URLs to your `/etc/hosts` file for seamless connectivity:

```bash
echo -e "127.0.0.1 keycloak.$OC_PROJECT.svc.cluster.local postgresql.$OC_PROJECT.svc.cluster.local minio.$OC_PROJECT.svc.cluster.local geofm-ui.$OC_PROJECT.svc.cluster.local geofm-gateway.$OC_PROJECT.svc.cluster.local geofm-geoserver.$OC_PROJECT.svc.cluster.local" | sudo tee -a /etc/hosts
```

> **Note:** This is required because some services may call internal cluster URLs from the host machine.

---

## 11. Testing

### 11.1 Access the Services

After deployment, you can access the following services:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Studio UI** | https://localhost:4180 | username: `testuser`<br>password: `testpass123` |
| **Studio API** | https//localhost:4181 | Use API key (see below) |
| **Geoserver** | http://localhost:3000 | username: `admin`<br>password: `geoserver` |
| **Keycloak** | http://localhost:8080 | username: `admin`<br>password: `admin` |
| **MinIO Console** | https://localhost:9001 | username: `minioadmin`<br>password: `minioadmin` |
| **MinIO API** | https://localhost:9000 | username: `minioadmin`<br>password: `minioadmin` |
| **MLflow** | http://localhost:5000 | No authentication |

### 11.2 Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n ${OC_PROJECT}

# Check services
kubectl get svc -n ${OC_PROJECT}

# Check persistent volume claims
kubectl get pvc -n ${OC_PROJECT}
```

### 11.3 View Deployment Summary

```bash
echo "----------------------------------------------------------------------"
echo "-----------------------  Deployment Summary  -------------------------"
echo "----------------------------------------------------------------------"
echo ""
echo "🌍🌎🌏   Geospatial Studio deployed to Kubernetes!"
echo "🗺️   Access the Geospatial Studio UI at: https://localhost:4180"
echo "💻   Access the Geospatial Studio API at: https://localhost:4181"
echo ""
echo "Dev Studio API Key: $STUDIO_API_KEY"
echo "Dev Postgres Password: $POSTGRES_PASSWORD"
echo ""
echo "----------------------------------------------------------------------"
```

### 11.4 Test API Endpoints

Use the Studio API key for programmatic access:

```bash
# Set your API key
export MY_GEOSTUDIO_KEY=$STUDIO_API_KEY

# Test: Add a model
curl -X POST "https://localhost:4181/studio-gateway/v2/models" \
  --header 'Content-Type: application/json' \
  --header "X-API-Key: $MY_GEOSTUDIO_KEY" \
  --data @tests/api-data/00-models.json

# Test: Submit an inference
curl -X POST "https://localhost:4181/studio-gateway/v2/inference" \
  --header 'Content-Type: application/json' \
  --header "X-API-Key: $MY_GEOSTUDIO_KEY" \
  --data @tests/api-data/01-inferences.json
```

---

## Troubleshooting

### Common Issues

#### 1. Port Forwarding Stopped

If port forwarding stops, restart it:

```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Restart all port forwards
kubectl port-forward -n ${OC_PROJECT} svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} svc/minio 9000:9000 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} svc/minio 9001:9001 >> studio-pf.log 2>&1 &
```

#### 2. Pod Not Starting

Check pod logs:

```bash
# List pods
kubectl get pods -n ${OC_PROJECT}

# View logs for a specific pod
kubectl logs <pod-name> -n ${OC_PROJECT}

# Describe pod for events
kubectl describe pod <pod-name> -n ${OC_PROJECT}
```

#### 3. Storage Issues

Check PVC status:

```bash
# List PVCs
kubectl get pvc -n ${OC_PROJECT}

# Describe PVC
kubectl describe pvc <pvc-name> -n ${OC_PROJECT}
```

#### 4. Authentication Issues

Verify Keycloak configuration:

```bash
# Check Keycloak logs
kubectl logs -l app=keycloak -n ${OC_PROJECT}

# Verify realm and client exist
# Access Keycloak at http://localhost:8080
```

#### 5. Database Connection Issues

Test PostgreSQL connection:

```bash
# Connect to PostgreSQL
kubectl port-forward --namespace ${OC_PROJECT} svc/postgresql 54320:5432 &
PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 54320
```

### Viewing Logs

```bash
# View all logs in namespace
kubectl logs -n ${OC_PROJECT} --all-containers=true --tail=100

# Follow logs for a specific deployment
kubectl logs -f deployment/geofm-gateway -n ${OC_PROJECT}

# View port-forward logs
tail -f studio-pf.log
```

### Restarting Services

```bash
# Restart all studio pods
./deployment-scripts/restart-all-studio-pods.sh

# Restart specific deployment
kubectl rollout restart deployment/geofm-gateway -n ${OC_PROJECT}
```

---

## Uninstalling

To remove the Geospatial Studio deployment:

```bash
# Uninstall Helm releases
helm uninstall studio -n ${OC_PROJECT}

# Delete PostgreSQL
helm uninstall postgresql -n ${OC_PROJECT}

# Delete other resources
kubectl delete -f deployment-scripts/keycloak-deployment.yaml -n ${OC_PROJECT}
kubectl delete -f deployment-scripts/minio-deployment.yaml -n ${OC_PROJECT}
kubectl delete -f deployment-scripts/geoserver-deployment.yaml -n ${OC_PROJECT}

# Delete CSI driver
kubectl delete -k deployment-scripts/ibm-object-csi-driver/

# Delete secrets and configmaps
kubectl delete secret minio-tls-secret -n ${OC_PROJECT}
kubectl delete configmap minio-public-config -n kube-system

# Delete PVCs (if you want to remove data)
kubectl delete pvc --all -n ${OC_PROJECT}
```

---

## Additional Resources

- [Geospatial Studio Documentation](https://github.com/terrastackai/geospatial-studio)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [MinIO Documentation](https://min.io/docs/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Geoserver Documentation](https://docs.geoserver.org/)

---

## Next Steps

After successful deployment:

1. **Configure External Services** (Optional):
   - Mapbox token for enhanced mapping
   - Cesium token for 3D visualization
   - Sentinel Hub credentials for satellite data
   - NASA Earth Data credentials

2. **Set Up Monitoring**:
   - Configure observability endpoints
   - Set up log aggregation
   - Enable metrics collection

3. **Production Hardening**:
   - Replace self-signed certificates with proper TLS certificates
   - Configure proper ingress/load balancer
   - Set up backup and disaster recovery
   - Implement proper secret management (e.g., Vault)
   - Configure resource limits and autoscaling
   - Set up network policies

4. **User Management**:
   - Create additional users in Keycloak
   - Configure role-based access control
   - Set up user groups and permissions

5. **Data Onboarding**:
   - Upload datasets to MinIO buckets
   - Configure data sources in Geoserver
   - Create model catalogs
   - Set up inference pipelines

---

## Support

For issues and questions:
- GitHub Issues: [geospatial-studio/issues](https://github.com/terrastackai/geospatial-studio/issues)
- Documentation: [geospatial-studio/docs](https://github.com/terrastackai/geospatial-studio/tree/main/docs)