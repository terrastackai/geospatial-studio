# Cluster Deployment Guide

This guide walks you through deploying Geospatial Studio on a Red Hat OpenShift or Kubernetes cluster using the interactive deployment script.

!!! info "Deployment Time"
    **Estimated time:** 45-60 minutes (depending on cluster and network speed)

## Overview

Cluster deployment provides full production capabilities including:

- ✅ GPU acceleration for model training
- ✅ Scalable inference pipelines
- ✅ High availability
- ✅ Production-grade security
- ✅ Resource isolation
- ✅ Flexible service configuration (in-cluster or external cloud services)

## Deployment Approach

This guide uses an **interactive deployment script** ([`deploy_studio_ocp.sh`](https://github.com/terrastackai/geospatial-studio/blob/main/deploy_studio_ocp.sh) for OpenShift or [`deploy_studio_k8s.sh`](https://github.com/terrastackai/geospatial-studio/blob/main/deploy_studio_k8s.sh) for Kubernetes) that:

1. **Creates a workspace** with environment configuration files
2. **Prompts for settings** (storage, database, authentication)
3. **Pauses for manual configuration** when needed
4. **Validates configuration** before proceeding
5. **Deploys all services** to your cluster

!!! info "Alternative: Manual Deployment"
    If you prefer step-by-step manual deployment or need more control over the process, detailed manual deployment guides are available:
    
    - [Manual OpenShift Deployment Guide](https://terrastackai.github.io/geospatial-studio/detailed_deployment_cluster/)
    - [Manual Kubernetes Deployment Guide](https://terrastackai.github.io/geospatial-studio/detailed_deployment_k8s/)
    
    These guides provide the same deployment steps but without automation, allowing you to understand each component and customize as needed.

### Configuration Files

The script creates a workspace directory: `workspace/${DEPLOYMENT_ENV}/env/` containing:

- **`.env`** - Secrets and credentials (database passwords, API keys, OAuth secrets)
- **`env.sh`** - General configuration (storage classes, bucket names, cluster settings)

!!! note "Workspace Regeneration"
    The deployment script regenerates workspace files each time it runs. If you have an existing workspace:
    
    - Your current files are backed up with a timestamp
    - Fresh templates are created from the latest deployment scripts
    - Your previous values are merged into the new templates
    - You're prompted to update any new or missing configuration

## Service Configuration Options

### In-Cluster Services (Default)
The deployment automatically provisions services within your cluster:

- **PostgreSQL** - Database (Bitnami Helm chart)
- **MinIO** - S3-compatible object storage
- **Keycloak** - OAuth2 authentication provider
- **Redis** - Caching and message queue
- **GeoServer** - Geospatial data visualization
- **MLflow** - Experiment tracking

### External Cloud Services (Production)
For production deployments, configure external cloud-managed services:

| Service Type | Supported Providers |
|--------------|-------------------|
| **Database** | IBM Cloud Databases, AWS RDS, Azure PostgreSQL, GCP Cloud SQL |
| **Object Storage** | IBM COS, AWS S3, Azure Blob Storage, GCP Cloud Storage |
| **Authentication** | IBM Security Verify, External Keycloak, Azure AD, Okta |

Configuration is done through workspace environment files during the interactive deployment.

## Prerequisites

!!! warning "Complete Prerequisites First"
    Before proceeding, ensure you have completed all requirements in the [Prerequisites](prerequisites.md) section:
    
    - ✅ Cluster access (OpenShift or Kubernetes)
    - ✅ kubectl/oc CLI tools installed
    - ✅ Helm v3.19+ installed
    - ✅ Python 3.11+ installed
    - ✅ Git installed
    - ✅ (Optional) External cloud services provisioned

## Deployment Options

Choose your target cluster type:

=== "OpenShift Cluster"
    **Recommended for enterprise deployments**
    
    - Full IBM support
    - Built-in Routes for ingress
    - Security Context Constraints (SCC)
    - Integrated monitoring and logging
    
    **Use script:** `deploy_studio_ocp.sh`

=== "Kubernetes Cluster"
    **Works with any Kubernetes distribution**
    
    - EKS, GKE, AKS, or self-managed
    - Requires Ingress controller
    - Standard Kubernetes RBAC
    
    **Use script:** `deploy_studio_k8s.sh`

=== "Kind Cluster (CPU Only)"
    **For local/remote testing without GPU**
    
    **Quick Setup:**
    ```bash
    # Create Kind cluster
    cat << EOF | kind create cluster --name=studio --config=-
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
    - role: worker
    EOF
    ```
    
    **What gets deployed:**
    - 2-node Kubernetes cluster (control-plane + worker)
    - CPU-only processing (no GPU acceleration)
    - Ideal for testing and development
    
    [Full Kind Deployment Guide →](https://terrastackai.github.io/geospatial-studio/kind_cluster_deployment/)

=== "NVKind Cluster (GPU Enabled)"
    **For local/remote testing with NVIDIA GPU**
    
    **Prerequisites:**
    - NVIDIA GPU with drivers installed
    - Docker with NVIDIA runtime
    - nvkind installed
    
    **Quick Setup:**
    ```bash
    # Verify GPU detection
    nvidia-smi -L
    
    # Create nvkind cluster
    cat << EOF | nvkind cluster create --name=studio --config-template= -
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
    - role: worker
      extraMounts:
        - hostPath: /dev/null
          containerPath: /var/run/nvidia-container-devices/all
    EOF
    
    # Configure kubectl
    kubectl cluster-info --context kind-studio
    
    # Install NVIDIA GPU Operator
    helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
    helm repo update
    helm install --wait --generate-name \
      -n gpu-operator --create-namespace \
      nvidia/gpu-operator --version=v25.10.0
    ```
    
    **What gets deployed:**
    - 2-node Kubernetes cluster with GPU access
    - NVIDIA GPU Operator for GPU management
    - GPU-accelerated processing
    
    [Full NVKind Deployment Guide →](https://terrastackai.github.io/geospatial-studio/nvkind_cluster_deployment/)

## Step-by-Step Deployment

### Step 1: Clone the Repository

```bash
git clone https://github.com/terrastackai/geospatial-studio.git
cd geospatial-studio
```

### Step 2: Install Python Dependencies

```bash
pip install -r requirements.txt
```

### Step 3: Configure Cluster Access

=== "OpenShift"
    ```bash
    # Login to OpenShift cluster
    oc login --token=<your-token> --server=<cluster-server>
    
    # Verify connection
    oc whoami
    oc get nodes
    ```

=== "Kubernetes"
    ```bash
    # Set kubectl context
    kubectl config use-context <your-context>

    # For Kind and NVKind clusters
    kubectl cluster-info --context kind-studio
    
    # Verify connection
    kubectl get nodes
    ```

### Step 4: (Optional) Pre-pull Container Images

For faster deployment, especially in bandwidth-constrained environments:

```bash
# Set your namespace
NAMESPACE=<your-namespace> ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh
```

!!! warning "CRITICAL: Wait for Pre-puller to Complete"
    **If you choose to pre-pull images, you MUST wait for completion before proceeding.**
    
    - Pre-pulling can take 10-20 minutes depending on network speed
    - Monitor progress: `kubectl get pods -n <your-namespace> -w`
    - Wait for message: "✅ Pre-pull complete"
    
    **Starting deployment before completion will cause:**
    - Image pull conflicts and deployment failures
    - Pods stuck in ImagePullBackOff state
    - Need to restart the entire deployment

### Step 5: Run the Interactive Deployment Script

=== "OpenShift"
    ```bash
    ./deploy_studio_ocp.sh
    ```

=== "Kubernetes"
    ```bash
    ./deploy_studio_k8s.sh
    ```

The script will guide you through the deployment process with interactive prompts.

## Interactive Configuration Workflow

The deployment script will prompt you for configuration in the following order:

### 1. Basic Setup

**Deployment Environment Name:**
```
Provide a name for the deployment environment (e.g., my-cluster-prod, dev-cluster)
```
This creates a workspace directory: `workspace/<your-name>/`

**Namespace/Project Name:**
```
Provide the namespace/project name (e.g., geospatial-studio)
```

**Cluster URL:**
- Auto-detected for OpenShift
- Manually entered for Kubernetes
- Example: `apps.mycluster.example.com`

**Image Pull Secret:**
- Choose default or provide custom secret
- Default is sufficient for public images

### 2. Storage Classes Configuration

The script will pause and display:

```
***********************************************************************************
-----------------------  Configure s3 storage classes -----------------------------
-----------------------------------------------------------------------------------
---------------- Verify the available storage classes in your cluster -------------
-----------------------------------------------------------------------------------
***********************************************************************************
******************  Update workspace/${DEPLOYMENT_ENV}/env/env.sh *****************
------------------------  export COS_STORAGE_CLASS= -------------------------------
------------------------  export NON_COS_STORAGE_CLASS= ---------------------------
***********************************************************************************
```

**Action Required:**

1. Check available storage classes:
   ```bash
   kubectl get storageclass
   ```

2. Edit the workspace file:
   ```bash
   vi workspace/${DEPLOYMENT_ENV}/env/env.sh
   ```

3. Set the storage classes:
   ```bash
   # For S3-compatible storage (used by MinIO or external S3)
   export COS_STORAGE_CLASS=<your-s3-compatible-storage-class>
   
   # For block storage (used by databases, Redis, etc.)
   export NON_COS_STORAGE_CLASS=<your-block-storage-class>
   ```

4. Press Enter in the script terminal to continue

**Common Storage Class Examples:**

| Cloud Provider | COS Storage Class | Non-COS Storage Class |
|----------------|-------------------|----------------------|
| **IBM Cloud** | `ibmc-s3fs-standard-regional` | `ibmc-block-gold` |
| **AWS EKS** | `efs-sc` (with EFS CSI) | `gp3` |
| **Azure AKS** | `azurefile-csi` | `managed-premium` |
| **GCP GKE** | `standard-rwo` | `pd-ssd` |
| **OpenShift** | `ocs-storagecluster-cephfs` | `ocs-storagecluster-ceph-rbd` |

!!! tip "Storage Class Requirements"
    - **COS_STORAGE_CLASS**: Must support S3-compatible storage or file storage
    - **NON_COS_STORAGE_CLASS**: Must support ReadWriteOnce (RWO) block storage

### 3. Object Storage Configuration

The script will prompt:

```
Select whether to deploy a cloud object storage in cluster or use a cloud managed instance:
  1) Cluster-deployment (Default)
  2) Cloud-managed-instance
```

=== "Option 1: Cluster-deployment (MinIO)"
    **Automatic configuration** - The script will:
    
    - Deploy MinIO in your cluster
    - Auto-configure credentials (minioadmin/minioadmin)
    - Create required buckets
    - Update workspace `.env` file automatically
    
    **Best for:** Development, testing, small deployments

=== "Option 2: Cloud-managed-instance"
    **Manual configuration required** - The script will pause:
    
    ```
    **********************************************************************
    -----------  Configure s3 storage and update the values --------------
    **********************************************************************
    ***********  Update workspace/${DEPLOYMENT_ENV}/env/.env *************
    -----------  access_key_id= ------------------------------------------
    -----------  secret_access_key= --------------------------------------
    -----------  endpoint= -----------------------------------------------
    -----------  region= -------------------------------------------------
    **********************************************************************
    ```
    
    **Action Required:**
    
    1. Edit the workspace file:
       ```bash
       vi workspace/${DEPLOYMENT_ENV}/env/.env
       ```
    
    2. Configure your cloud storage credentials:
       
       **For IBM Cloud Object Storage:**
       ```bash
       access_key_id=1234567890abcdef1234567890abcdef
       secret_access_key=abcdef1234567890abcdef1234567890abcdef12
       endpoint=https://s3.us-south.cloud-object-storage.appdomain.cloud
       region=us-south
       ```
       
       **For AWS S3:**
       ```bash
       access_key_id=AKIAIOSFODNN7EXAMPLE
       secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
       endpoint=https://s3.us-east-1.amazonaws.com
       region=us-east-1
       ```
       
       **For Azure Blob Storage (via S3 gateway):**
       ```bash
       access_key_id=<azure-storage-account-name>
       secret_access_key=<azure-storage-account-key>
       endpoint=https://<account>.blob.core.windows.net
       region=eastus
       ```
    
    3. Press Enter in the script terminal to continue
    
    **Best for:** Production deployments, enterprise requirements

The script will then create the required buckets automatically.

### 4. Database Configuration

The script will prompt:

```
Select whether to deploy a PostgreSQL database in cluster or use a cloud managed instance:
  1) Cluster-deployment (Default)
  2) Cloud-managed-instance
```

=== "Option 1: Cluster-deployment (PostgreSQL)"
    **Automatic configuration** - The script will:
    
    - Deploy PostgreSQL using Bitnami Helm chart
    - Auto-configure credentials
    - Create required databases
    - Update workspace `.env` file automatically
    
    **Best for:** Development, testing, small deployments

=== "Option 2: Cloud-managed-instance"
    **Manual configuration required** - The script will pause:
    
    ```
    **********************************************************************
    -----------  Configure PostgreSQL and update the values --------------
    **********************************************************************
    ***********  Update workspace/${DEPLOYMENT_ENV}/env/.env *************
    -----------  pg_username= --------------------------------------------
    -----------  pg_password= --------------------------------------------
    -----------  pg_uri= -------------------------------------------------
    -----------  pg_port= ------------------------------------------------
    -----------  pg_original_db_name= ------------------------------------
    **********************************************************************
    ```
    
    **Action Required:**
    
    1. Edit the workspace file:
       ```bash
       vi workspace/${DEPLOYMENT_ENV}/env/.env
       ```
    
    2. Configure your database credentials:
       
       **For IBM Cloud Databases for PostgreSQL:**
       ```bash
       pg_username=ibm_cloud_user
       pg_password=your-secure-password
       pg_uri=1234abcd-5678-90ef-ghij-klmnopqrstuv.databases.appdomain.cloud
       pg_port=30123
       pg_original_db_name=ibmclouddb
       ```
       
       **For AWS RDS for PostgreSQL:**
       ```bash
       pg_username=postgres
       pg_password=your-secure-password
       pg_uri=mydb-instance.abc123.us-east-1.rds.amazonaws.com
       pg_port=5432
       pg_original_db_name=postgres
       ```
       
       **For Azure Database for PostgreSQL:**
       ```bash
       pg_username=azureuser@myserver
       pg_password=your-secure-password
       pg_uri=myserver.postgres.database.azure.com
       pg_port=5432
       pg_original_db_name=postgres
       ```
    
    3. Press Enter in the script terminal to continue
    
    **Best for:** Production deployments, enterprise requirements

The script will then create the required databases and tables automatically.

### 5. Authentication Configuration

The script will prompt:

```
Select OAuth provider type:
  1) Keycloak (Default)
  2) IBM Security Verify (ISV)
  3) External OAuth Provider
```

=== "Option 1: Keycloak (In-Cluster)"
    **Automatic configuration** - The script will:
    
    - Deploy Keycloak in your cluster
    - Auto-configure realm and clients
    - Update workspace files automatically
    
    **Best for:** Development, testing, self-contained deployments

=== "Option 2: IBM Security Verify"
    **Manual configuration required** - The script will pause:
    
    ```
    **********************************************************************
    -----------  Configure IBM Security Verify ---------------------------
    **********************************************************************
    ***********  Update workspace/${DEPLOYMENT_ENV}/env/env.sh ***********
    -----------  export OAUTH_CLIENT_ID= ---------------------------------
    -----------  export OAUTH_ISSUER_URL= --------------------------------
    ***********  Update workspace/${DEPLOYMENT_ENV}/env/.env *************
    -----------  oauth_client_secret= ------------------------------------
    -----------  oauth_cookie_secret= ------------------------------------
    **********************************************************************
    ```
    
    **Action Required:**
    
    1. Edit the configuration file:
       ```bash
       vi workspace/${DEPLOYMENT_ENV}/env/env.sh
       ```
       
       Add:
       ```bash
       export OAUTH_TYPE=isv
       export OAUTH_CLIENT_ID=your-isv-client-id
       export OAUTH_ISSUER_URL=https://geostudio.verify.ibm.com/v1.0/endpoint/default
       export OAUTH_URL=https://geostudio.verify.ibm.com/v1.0/endpoint/default/authorize
       ```
    
    2. Edit the secrets file:
       ```bash
       vi workspace/${DEPLOYMENT_ENV}/env/.env
       ```
       
       Add:
       ```bash
       oauth_client_secret=your-isv-client-secret
       oauth_cookie_secret=$(openssl rand -base64 32)
       ```
    
    3. Press Enter in the script terminal to continue
    
    **Best for:** Enterprise deployments with IBM Security Verify

=== "Option 3: External OAuth Provider"
    **Manual configuration required** - Similar to ISV, but configure for your provider:
    
    ```bash
    # In env.sh
    export OAUTH_TYPE=keycloak  # or your provider type
    export OAUTH_CLIENT_ID=your-client-id
    export OAUTH_ISSUER_URL=https://your-auth-provider.com/realms/your-realm
    export OAUTH_URL=https://your-auth-provider.com/realms/your-realm/protocol/openid-connect/auth
    
    # In .env
    oauth_client_secret=your-client-secret
    oauth_cookie_secret=$(openssl rand -base64 32)
    ```
    
    **Best for:** Integration with existing OAuth infrastructure

### 6. GeoServer Configuration

The script will automatically:

- Deploy GeoServer
- Configure data directories
- Set up authentication
- Create required workspaces

No manual configuration required.

### 7. Deploy Geospatial Studio Services

After all configuration is complete, the script will:

1. Deploy all Geospatial Studio services
2. Wait for pods to become ready
3. Configure routes/ingress
4. Display access URLs

## Monitoring Deployment Progress

Watch the deployment in real-time:

=== "OpenShift"
    ```bash
    # Watch pods
    oc get pods -n <your-namespace> -w
    
    # Check deployment status
    oc get deployments -n <your-namespace>
    
    # Or use k9s for a better experience
    k9s -n <your-namespace>
    ```

=== "Kubernetes"
    ```bash
    # Watch pods
    kubectl get pods -n <your-namespace> -w
    
    # Check deployment status
    kubectl get deployments -n <your-namespace>
    
    # Or use k9s for a better experience
    k9s -n <your-namespace>
    ```

Wait for all pods to reach "Running" status. This typically takes 10-15 minutes.

## Post-Deployment Steps

### Access the Studio

After deployment completes, the script displays access URLs:

```
✅ Deployment Complete!

Access URLs:
- Studio UI: https://studio-<namespace>.<cluster-url>
- Studio API: https://api-<namespace>.<cluster-url>
- GeoServer: https://geoserver-<namespace>.<cluster-url>
- MLflow: https://mlflow-<namespace>.<cluster-url>

Default Credentials:
- Username: testuser
- Password: testpass123
```

### Create API Key

1. Navigate to the Studio UI
2. Login with default credentials
3. Click "Manage your API keys"
4. Generate a new API key
5. Save it securely:

```bash
echo "GEOSTUDIO_API_KEY=<your-api-key>" > ~/.geostudio_config_file
echo "BASE_STUDIO_UI_URL=https://studio-<namespace>.<cluster-url>" >> ~/.geostudio_config_file
```

### Onboard Sandbox Models

```bash
export STUDIO_API_KEY="<your-api-key>"
export UI_ROUTE_URL="https://studio-<namespace>.<cluster-url>"

./deployment-scripts/add-sandbox-models.sh
```

## Verify Configuration

After deployment, verify your configuration:

```bash
# Load environment variables
source workspace/${DEPLOYMENT_ENV}/env/env.sh

# Check key settings
echo "Deployment: $DEPLOYMENT_ENV"
echo "Namespace: $OC_PROJECT"
echo "Cluster: $CLUSTER_URL"
echo "Storage Classes: COS=$COS_STORAGE_CLASS, Non-COS=$NON_COS_STORAGE_CLASS"

# Check secrets (without displaying values)
grep -E "pg_uri|endpoint|oauth_client_id" workspace/${DEPLOYMENT_ENV}/env/.env | sed 's/=.*/=***/'
```

**Verify pods are running:**

=== "OpenShift"
    ```bash
    oc get pods -n <your-namespace>
    oc get routes -n <your-namespace>
    ```

=== "Kubernetes"
    ```bash
    kubectl get pods -n <your-namespace>
    kubectl get ingress -n <your-namespace>
    ```

## Re-running the Deployment

If you need to re-run the deployment script:

### Jump to Deployment

If you've already configured everything and just want to redeploy:

=== "OpenShift"
    ```bash
    ./deploy_studio_ocp.sh
    ```

=== "Kubernetes"
    ```bash
    ./deploy_studio_k8s.sh
    ```

When prompted "Jump to Deployment?", select **Yes** to skip configuration and go straight to deployment.

### Update Configuration

If you need to update configuration:

=== "OpenShift"
    ```bash
    ./deploy_studio_ocp.sh
    ```

=== "Kubernetes"
    ```bash
    ./deploy_studio_k8s.sh
    ```

When prompted "Jump to Deployment?", select **No** to:

- Regenerate workspace files (with backup)
- Update configuration values
- Redeploy services

## GPU Configuration

If your cluster has NVIDIA GPUs, you can configure GPU affinity for fine-tuning jobs.

### Verify GPU Availability

```bash
kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
```

### Configure GPU in Workspace

1. Edit `workspace/${DEPLOYMENT_ENV}/env/env.sh`:

   ```bash
   # GPU Configuration
   export CONFIGURE_GPU_AFFINITY_FLAG=true
   export CONFIGURE_GPU_AFFINITY=true
   export NODE_SELECTOR_KEY=nvidia.com/gpu.product
   export NODE_GPU_SPEC=NVIDIA-A100-SXM4-80GB  # Adjust to your GPU model
   ```

2. Regenerate values.yaml to apply GPU settings:

   ```bash
   ./deployment-scripts/values-file-generate.sh
   ```

3. Redeploy or update the deployment:

   === "OpenShift"
       ```bash
       ./deploy_studio_ocp.sh
       # Select "Yes" when prompted "Jump to Deployment?"
       ```

   === "Kubernetes"
       ```bash
       ./deploy_studio_k8s.sh
       # Select "Yes" when prompted "Jump to Deployment?"
       ```
## Advanced Configuration Options

Beyond the basic configuration covered in the interactive deployment, you can customize additional settings. Configuration is split between:

1. **Workspace environment files** (`workspace/${DEPLOYMENT_ENV}/env/`) - Infrastructure and deployment settings
2. **Helm values files** (`workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`) - Application runtime settings

!!! tip "Configuration Workflow"
    1. Edit workspace files (`env.sh` or `.env`) for infrastructure settings
    2. Run `./deployment-scripts/values-file-generate.sh` to generate values.yaml from env.sh
    3. Edit `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml` for application settings
    4. Deploy or update using `./deploy_studio_ocp.sh`

### Rate Limiting

Control API request rates to prevent abuse and ensure fair resource usage.

Edit `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`:

```yaml
# In gfm-studio-gateway.extraEnvironment.api section
extraEnvironment:
  api:
    RATELIMIT_ENABLED: true
    RATELIMIT_LIMIT: 200                      # Max requests per window
    RATELIMIT_WINDOW: 60                      # Time window in seconds
    RATELIMIT_SENSITIVE_RESOURCE_LIMIT: 6     # For training/inference
    RATELIMIT_SENSITIVE_RESOURCE_WINDOW: 300  # 5 minutes
```

**Default values:**
- General: 200 requests per 60 seconds
- Sensitive resources: 6 requests per 300 seconds (5 minutes)

### Data Advisor

Enable automatic data quality assessment and recommendations for satellite imagery.

Edit `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`:

```yaml
# In gfm-studio-gateway.extraEnvironment.api section
extraEnvironment:
  api:
    DATA_ADVISOR_ENABLED: true
    DATA_ADVISOR_PRE_DAYS: 1       # Days before target date
    DATA_ADVISOR_POST_DAYS: 1      # Days after target date
    DATA_ADVISOR_MAX_CLOUD_COVER: 80
```

**Use case:** Automatically find the best available satellite imagery for a given location and time period.

### GPU Node Affinity

Control which GPU nodes are used for model training and inference.

Edit `workspace/${DEPLOYMENT_ENV}/env/env.sh`:

```bash
# Enable GPU node affinity
export CONFIGURE_GPU_AFFINITY=true

# Node selector key (Kubernetes label)
export NODE_SELECTOR_KEY=nvidia.com/gpu.product

# Comma-separated list of acceptable GPU types
export NODE_GPU_SPEC=NVIDIA-A100-SXM4-80GB,NVIDIA-V100-SXM2-32GB
```

Then regenerate values.yaml:
```bash
./deployment-scripts/values-file-generate.sh
```

**When to use:**
- **Enable** (true): When you have specific GPU requirements or want to reserve certain GPUs
- **Disable** (false): When any available GPU is acceptable for training

### Fine-Tuning Resource Limits

Configure CPU, memory, and GPU resources for model training jobs. These settings control the resources allocated to fine-tuning jobs created by the API.

Edit `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`:

```yaml
# In gfm-studio-gateway.extraEnvironment.api section
extraEnvironment:
  api:
    # Resource limits (maximum allowed for fine-tuning jobs)
    RESOURCE_LIMIT_CPU: 10        # CPU cores
    RESOURCE_LIMIT_Memory: 32     # GB
    RESOURCE_LIMIT_GPU: 1         # Number of GPUs
    
    # Resource requests (guaranteed minimum for fine-tuning jobs)
    RESOURCE_REQUEST_CPU: 6       # CPU cores
    RESOURCE_REQUEST_Memory: 24   # GB
    RESOURCE_REQUEST_GPU: 1       # Number of GPUs
```

**Recommendations:**
- **Development**: Lower limits (4 CPU, 16GB RAM, 1 GPU)
- **Production**: Higher limits (10+ CPU, 32+ GB RAM, 1-2 GPUs)

**Note:** These settings control resources for fine-tuning jobs, not the API gateway pod itself. To configure API gateway pod resources, edit the `resources.api` section in values.yaml.

### Job Retry and Timeout Settings

Configure how long to wait for training jobs and how many times to retry.

Edit `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`:

```yaml
# In gfm-studio-gateway.extraEnvironment.api section
extraEnvironment:
  api:
    JOB_MAX_RETRY_COUNT: 30
    KJOB_MAX_WAIT_SECONDS: 7200  # 2 hours
```

### Observability and Monitoring

Enable OpenTelemetry tracing and metrics collection.

Edit `workspace/${DEPLOYMENT_ENV}/env/env.sh`:

```bash
# Enable observability
export OBSERVABILITY_ENABLED=true

# OpenTelemetry endpoints
export OBSERVABILITY_OTLP_ENDPOINT=http://otel-collector:4317
export OBSERVABILITY_OTLP_TRACES_ENDPOINT=http://otel-collector:4318
```

Then regenerate values.yaml:
```bash
./deployment-scripts/values-file-generate.sh
```

**Integration options:**
- Jaeger for distributed tracing
- Prometheus for metrics
- Grafana for visualization

### External Service Credentials

Configure credentials for external data sources and services.

Edit `workspace/${DEPLOYMENT_ENV}/env/.env`:

```bash
# SentinelHub (satellite imagery provider)
sh_client_id=<your-sentinelhub-client-id>
sh_client_secret=<your-sentinelhub-client-secret>

# NASA EarthData
nasa_earth_data_bearer_token=<your-nasa-token>

# Mapbox (for UI basemaps)
mapbox_token=<your-mapbox-token>

# Cesium (for 3D visualization)
cesium_token=<your-cesium-token>
```

### Celery Task Configuration

Configure background task processing for asynchronous operations.

Edit `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`:

```yaml
# In gfm-studio-gateway.extraEnvironment.api section
extraEnvironment:
  api:
    CELERY_TASKS_ENABLED: true

# In gfm-studio-gateway.celery section
celery:
  worker:
    enabled: true
    replicaCount: 1
    command: 'celery -A gfmstudio.celery_worker.celery_app worker -c 4 --queues=inference_gateway,geoft --loglevel=info'
```

**Task types:**
- Model fine-tuning jobs
- Dataset processing
- Inference requests
- Automated model onboarding

### Pipeline Configuration

Configure inference and data processing pipelines.

Edit `workspace/${DEPLOYMENT_ENV}/env/env.sh`:

```bash
# Enable pipelines
export PIPELINES_ENABLED=true

# Inference pipeline root folder
export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=/inference-data

# Create tuning folders automatically
export CREATE_TUNING_FOLDERS_FLAG=true
```

Then regenerate values.yaml:
```bash
./deployment-scripts/values-file-generate.sh
```

### Debug and Development Settings

Enable debug mode and additional logging for troubleshooting.

Edit `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`:

```yaml
# In gfm-studio-gateway.extraEnvironment.api section
extraEnvironment:
  api:
    DEBUG: "false"              # Set to "true" for debug mode
    ENVIRONMENT: prod           # Options: dev, staging, prod
```

And in `workspace/${DEPLOYMENT_ENV}/env/env.sh`:

```bash
# Environment type (used in values generation)
export ENVIRONMENT=dev  # Options: dev, staging, prod
```

!!! warning "Debug Mode in Production"
    Never enable `DEBUG=true` in production environments as it:
    - Exposes sensitive information in logs
    - Increases log volume significantly
    - May impact performance

### Custom Docker Images

Override default container images for specific components.

Edit `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`:

```yaml
# In gfm-studio-gateway.images section
images:
  api:
    name: quay.io/geospatial-studio/geostudio-gateway
    tag: custom-tag
  tt_caikit:
    name: quay.io/geospatial-studio/geospatial-model-inference-service
    tag: custom-tag
```

### Storage Configuration

Configure storage classes and PVC settings.

Edit `workspace/${DEPLOYMENT_ENV}/env/env.sh`:

```bash
# Storage classes (already configured during deployment)
export COS_STORAGE_CLASS=<your-s3-compatible-storage-class>
export NON_COS_STORAGE_CLASS=<your-block-storage-class>

# Enable/disable PVC storage
export STORAGE_PVC_ENABLED=true

# Enable/disable filesystem storage
export STORAGE_FILESYSTEM_ENABLED=false

# Share pipeline PVC across pods
export SHARE_PIPELINE_PVC=false
```

### Redis Configuration

Configure Redis for caching and message queuing.

Edit `workspace/${DEPLOYMENT_ENV}/env/env.sh`:

```bash
# Enable Redis
export REDIS_ENABLED=true

# Redis architecture
export REDIS_ARCHITECTURE=replication  # Options: standalone, replication

# Redis name override
export REDIS_FULL_NAME_OVERRIDE=geofm-redis
```

And in `workspace/${DEPLOYMENT_ENV}/env/.env`:

```bash
# Redis password
redis_password=<your-secure-redis-password>
```

### Applying Advanced Configuration

The configuration workflow depends on which files you edited:

#### For Workspace Environment Files (env.sh)

1. **Regenerate values.yaml:**
   ```bash
   # This substitutes env.sh variables into values.yaml template
   ./deployment-scripts/values-file-generate.sh
   ```

2. **Verify configuration:**
   ```bash
   # Check syntax
   source workspace/${DEPLOYMENT_ENV}/env/env.sh
   
   # Review generated values
   cat workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml
   ```

3. **Deploy or update:**

   === "OpenShift"
       ```bash
       ./deploy_studio_ocp.sh
       # Select "Yes" when prompted "Jump to Deployment?"
       ```

   === "Kubernetes"
       ```bash
       ./deploy_studio_k8s.sh
       # Select "Yes" when prompted "Jump to Deployment?"
       ```

#### For Helm Values Files (values.yaml)

1. **Edit values directly:**
   ```bash
   # Edit the generated values file
   vi workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml
   ```

2. **Deploy or update:**

   === "OpenShift"
       ```bash
       ./deploy_studio_ocp.sh
       # Select "Yes" when prompted "Jump to Deployment?"
       ```

   === "Kubernetes"
       ```bash
       ./deploy_studio_k8s.sh
       # Select "Yes" when prompted "Jump to Deployment?"
       ```

#### Verification

After deployment, verify changes:

=== "OpenShift"
    ```bash
    # Check pod environment variables
    oc get pod <pod-name> -n <namespace> -o yaml | grep -A 20 env:
    
    # Check configmaps
    oc get configmap -n <namespace>
    oc describe configmap <configmap-name> -n <namespace>
    
    # View pod logs
    oc logs <pod-name> -n <namespace>
    ```

=== "Kubernetes"
    ```bash
    # Check pod environment variables
    kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 20 env:
    
    # Check configmaps
    kubectl get configmap -n <namespace>
    kubectl describe configmap <configmap-name> -n <namespace>
    
    # View pod logs
    kubectl logs <pod-name> -n <namespace>
    ```

!!! tip "Configuration Best Practices"
    - **Understand the two-tier system**: env.sh → values.yaml → Helm deployment
    - **Infrastructure settings** (storage, GPU, observability) go in env.sh
    - **Application settings** (rate limits, debug mode, celery) go in values.yaml
    - **Always regenerate** values.yaml after editing env.sh
    - **Document changes**: Keep notes on why you changed specific values
    - **Test in dev first**: Validate configuration changes in a development environment
    - **Version control**: Store workspace files in git (excluding secrets in `.env`)
    - **Use secrets management**: For production, use external secrets management tools

!!! warning "Configuration File Precedence"
    When you run `values-file-generate.sh`, it overwrites `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`. If you've made manual edits to values.yaml, they will be lost. To preserve manual changes:
    
    1. Make infrastructure changes in env.sh
    2. Run `values-file-generate.sh`
    3. Make application-specific changes in the generated values.yaml
    4. Deploy


## Production Considerations

### High Availability

For production deployments, consider:

- **Multiple replicas** for UI and API services
- **Pod disruption budgets** to maintain availability during updates
- **Resource requests and limits** for predictable performance
- **Horizontal pod autoscaling** for dynamic scaling

### Backup and Disaster Recovery

- **Database backups**: Configure automated backups for PostgreSQL
- **Object storage replication**: Enable cross-region replication
- **Configuration backups**: Keep workspace files in version control

### Security

- **TLS certificates**: Use cert-manager for automatic certificate management
- **Network policies**: Restrict pod-to-pod communication
- **RBAC**: Configure role-based access control
- **Secrets management**: Use external secrets management (e.g., HashiCorp Vault)

### Monitoring and Observability

Enable monitoring in `workspace/${DEPLOYMENT_ENV}/env/env.sh`:

```bash
export OBSERVABILITY_ENABLED=true
export OBSERVABILITY_OTLP_ENDPOINT=<your-otlp-endpoint>
export OBSERVABILITY_OTLP_TRACES_ENDPOINT=<your-traces-endpoint>
```

## Troubleshooting

!!! info "Comprehensive Troubleshooting Guide"
    For detailed troubleshooting steps, see the [Troubleshooting Guide](../resources/troubleshooting.md).
    
    Common cluster deployment issues covered:
    - Pods not starting or crashing
    - Storage and PVC issues
    - Network and ingress problems
    - GPU not available or not detected
    - Permission and RBAC errors
    - Resource constraints and OOM errors
    - Configuration validation failures

### Quick Troubleshooting Tips

**Pods not starting:**

=== "OpenShift"
    ```bash
    oc describe pod <pod-name> -n <namespace>
    oc logs <pod-name> -n <namespace>
    ```

=== "Kubernetes"
    ```bash
    kubectl describe pod <pod-name> -n <namespace>
    kubectl logs <pod-name> -n <namespace>
    ```

**Storage issues:**

=== "OpenShift"
    ```bash
    oc get pvc -n <namespace>
    oc describe pvc <pvc-name> -n <namespace>
    ```

=== "Kubernetes"
    ```bash
    kubectl get pvc -n <namespace>
    kubectl describe pvc <pvc-name> -n <namespace>
    ```

**Configuration issues:**
```bash
# Verify environment files
cat workspace/${DEPLOYMENT_ENV}/env/env.sh
cat workspace/${DEPLOYMENT_ENV}/env/.env

# Re-run validation
python deployment-scripts/validate-env-files.py \
  --env-file workspace/${DEPLOYMENT_ENV}/env/.env \
  --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh
```

## Upgrading

To upgrade an existing deployment:

=== "OpenShift"
    ```bash
    # Pull latest changes
    git pull origin main
    
    # Re-run deployment script
    ./deploy_studio_ocp.sh
    
    # Select "Yes" when prompted "Jump to Deployment?"
    ```

=== "Kubernetes"
    ```bash
    # Pull latest changes
    git pull origin main
    
    # Re-run deployment script
    ./deploy_studio_k8s.sh
    
    # Select "Yes" when prompted "Jump to Deployment?"
    ```

The script will:
- Backup your current workspace
- Merge your configuration into new templates
- Upgrade services to latest versions

## Uninstalling

To remove the deployment:

=== "OpenShift"
    ```bash
    # Delete all resources in namespace
    oc delete all --all -n <namespace>
    
    # Delete persistent volumes (if needed)
    oc delete pvc --all -n <namespace>
    
    # Delete project
    oc delete project <namespace>
    
    # Clean up workspace
    rm -rf workspace/${DEPLOYMENT_ENV}
    ```

=== "Kubernetes"
    ```bash
    # Delete all resources in namespace
    kubectl delete all --all -n <namespace>
    
    # Delete persistent volumes (if needed)
    kubectl delete pvc --all -n <namespace>
    
    # Delete namespace
    kubectl delete namespace <namespace>
    
    # Clean up workspace
    rm -rf workspace/${DEPLOYMENT_ENV}
    ```

## Next Steps

1. ✅ [Verify Installation →](verification.md)
2. 📚 [Continue to Introduction →](../introduction/welcome.md)
3. 🚀 [Start Lab 1 →](../notebooks/lab1-getting-started.ipynb)

## Additional Resources

- [Detailed OpenShift Deployment Guide](https://terrastackai.github.io/geospatial-studio/detailed_deployment_cluster/)
- [Detailed Kubernetes Deployment Guide](https://terrastackai.github.io/geospatial-studio/detailed_deployment_k8s/)
- [Kind Cluster Guide](https://terrastackai.github.io/geospatial-studio/kind_cluster_deployment/)
- [NVKind Cluster Guide](https://terrastackai.github.io/geospatial-studio/nvkind_cluster_deployment/)
- [Geospatial Studio Documentation](https://terrastackai.github.io/geospatial-studio/)

---

[← Back to Prerequisites](prerequisites.md){ .md-button } [Next: Verification →](verification.md){ .md-button .md-button--primary }