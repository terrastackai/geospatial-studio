# Deploying Geospatial Studio on CRC (CodeReady Containers)

This guide provides instructions for deploying Geospatial Studio on Red Hat OpenShift Local (formerly CodeReady Containers/CRC) for local development and testing.

## Prerequisites

### System Requirements
- **CPU**: 4+ cores (8+ recommended)
- **Memory**: 16GB RAM minimum (32GB recommended)
- **Disk**: 50GB free space minimum
- **OS**: Linux

### Required Software
- [Red Hat OpenShift Local (CRC)](https://developers.redhat.com/products/openshift-local/overview)
- [oc CLI](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [Python 3.9+](https://www.python.org/downloads/)
- [yq](https://github.com/mikefarah/yq)

## Step 1: Install and Start CRC

### 1.1 Download and Install CRC

```bash
# Download from https://developers.redhat.com/products/openshift-local/overview
# Or use package manager (macOS example):
brew install --cask openshift-local

# Verify installation
crc version
```

### 1.2 Setup CRC

```bash
# Setup CRC (one-time operation)
crc setup

# Configure CRC resources (adjust based on your system)
crc config set cpus 8
crc config set memory 32768  # 32GB
crc config set disk-size 100  # 100GB
```

### 1.3 Start CRC

```bash
# Start CRC cluster
crc start

# This will:
# - Download OpenShift bundle (first time only, ~3GB)
# - Start the VM
# - Configure networking
# - Provide login credentials

# Expected output includes:
# - kubeadmin password
# - Console URL: https://console-openshift-console.apps-crc.testing
# - API URL: https://api.crc.testing:6443
```

### 1.4 Login to CRC

```bash
# Use the credentials from crc start output
eval $(crc oc-env)
oc login -u kubeadmin https://api.crc.testing:6443

# Verify cluster access
oc cluster-info
oc get nodes
```

## Step 2: Prepare for Deployment

### 2.1 Clone Repository

```bash
git clone https://github.com/IBM/geospatial-studio.git
cd geospatial-studio
```

### 2.2 Install Python Dependencies

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2.3 Set Environment Variables

```bash
# Set deployment environment
export DEPLOYMENT_ENV="crc-local"
export OC_PROJECT="geostudio-test"

# Storage configuration
export COS_STORAGE_CLASS="ibmc-s3fs-cos"
export NON_COS_STORAGE_CLASS="crc-csi-hostpath-provisioner"

# Deployment options
export cloud_object_storage_type="Cluster-deployment"
export postgres_type="Cluster-deployment"
export oauth_type="Keycloak"
export geoserver_install_type="Configure-SCC"
export gpu_configuration_type="No-GPU-Available"

# Enable IBM Object Storage Plugin
export INSTALL_CSI_DRIVER="Yes"

# Skip to deployment (no interactive prompts)
export JUMP_TO_DEPLOYMENT="No"

# Image pull secret (empty for public images)
export STUDIO_IMAGE_PULL_SECRET=""
```

## Step 3: Deploy Geospatial Studio

### 3.1 Run Deployment Script

```bash
# Make script executable
chmod +x deploy_studio_ocp.sh

# Run deployment
./deploy_studio_ocp.sh
```

The script will:
1. Create namespace
2. Deploy MinIO (S3-compatible storage)
3. Install IBM Object Storage Plugin
4. Deploy PostgreSQL
5. Deploy Redis
6. Deploy Keycloak (OAuth)
7. Deploy Geoserver
8. Deploy Geospatial Studio services
9. Create routes for external access

### 3.2 Monitor Deployment

```bash
# Watch pod status
oc get pods -n $OC_PROJECT -w

# Check all resources
oc get all -n $OC_PROJECT

# View deployment logs
oc logs -f deployment/geofm-gateway -n $OC_PROJECT
```

### 3.3 Verify PVC Binding

```bash
# Check PVC status (should all be Bound)
oc get pvc -n $OC_PROJECT

# If PVCs are Pending, check events
oc describe pvc <pvc-name> -n $OC_PROJECT

# Check IBM plugin logs
oc logs -n ibm-object-s3fs deployment/ibmcloud-object-storage-plugin
```

## Step 4: Access Services

### 4.1 Get Service URLs

```bash
# Get all routes
oc get routes -n $OC_PROJECT

# Get specific service URLs
echo "Studio UI: https://$(oc get route geofm-gateway -n $OC_PROJECT -o jsonpath='{.spec.host}')"
echo "MinIO Console: https://$(oc get route minio-console -n $OC_PROJECT -o jsonpath='{.spec.host}')"
echo "Keycloak: https://$(oc get route keycloak -n $OC_PROJECT -o jsonpath='{.spec.host}')"
echo "Geoserver: https://$(oc get route geofm-geoserver -n $OC_PROJECT -o jsonpath='{.spec.host}')/geoserver"
```

### 4.2 Login Credentials

**Geospatial Studio:**
- URL: `https://geofm-gateway-geostudio-test.apps-crc.testing`
- Username: `admin`
- Password: `admin` (default, check Keycloak for actual credentials)

**MinIO:**
- URL: `https://minio-console-geostudio-test.apps-crc.testing`
- Username: `minioadmin`
- Password: `minioadmin`

**Keycloak:**
- URL: `https://keycloak-geostudio-test.apps-crc.testing`
- Username: `admin`
- Password: Check deployment logs or secrets

## Step 5: Run End-to-End Tests

### 5.1 Get Studio API Key

```bash
# Get the API key from the deployment
export STUDIO_API_KEY=$(oc get secret geofm-gateway-secrets -n $OC_PROJECT -o jsonpath='{.data.FT_API_KEY}' | base64 -d)

# Save it for future use
echo "export STUDIO_API_KEY='${STUDIO_API_KEY}'" > .studio-api-key
source .studio-api-key

# Verify API key
echo "Studio API Key: ${STUDIO_API_KEY}"
```

### 5.2 Get Studio URL

```bash
# Get the Studio UI URL
export BASE_STUDIO_UI_URL="https://$(oc get route geofm-gateway -n $OC_PROJECT -o jsonpath='{.spec.host}')"

echo "Studio URL: ${BASE_STUDIO_UI_URL}"
```

### 5.3 Run Workshop Labs (E2E Tests)

The `run_labs.py` script executes all 4 Geospatial Studio workshop labs:
- **Lab 1**: Getting Started - Connect to Studio, verify platform status
- **Lab 2**: Onboarding Examples - Submit pre-computed inference example
- **Lab 3**: Upload Model & Run Inference - Upload flood model, run inference
- **Lab 4**: Burn Scars Workflow - Register backbone, onboard dataset, fine-tune, run inference

```bash
# Ensure you're in the project directory
cd geospatial-studio

# Activate virtual environment if not already active
source .venv/bin/activate

# Install SDK dependencies
pip install -r geospatial-studio-toolkit/geospatial-studio-sdk/requirements.txt

# Run all labs (skip training for faster execution)
python populate-studio/run_labs.py \
    --api-key "${STUDIO_API_KEY}" \
    --studio-url "${BASE_STUDIO_UI_URL}" \
    --skip-lab4-training

# For even faster execution, skip dataset onboarding too
python populate-studio/run_labs.py \
    --api-key "${STUDIO_API_KEY}" \
    --studio-url "${BASE_STUDIO_UI_URL}" \
    --skip-lab4-dataset

# Run with full training (takes longer, requires GPU)
python populate-studio/run_labs.py \
    --api-key "${STUDIO_API_KEY}" \
    --studio-url "${BASE_STUDIO_UI_URL}"
```

### 5.4 Monitor Lab Execution

```bash
# Watch pods during lab execution
oc get pods -n $OC_PROJECT -w

# Check inference job status
oc get jobs -n $OC_PROJECT

# View inference logs
oc logs -f job/<inference-job-name> -n $OC_PROJECT

# Check fine-tuning status (if not skipped)
oc get pods -n $OC_PROJECT | grep tune
```

### 5.5 Verify Results

```bash
# Check completed inferences via API
curl -k "${BASE_STUDIO_UI_URL}/api/v1/inferences" \
  -H "Authorization: Bearer ${STUDIO_API_KEY}"

# Check registered models
curl -k "${BASE_STUDIO_UI_URL}/api/v1/models" \
  -H "Authorization: Bearer ${STUDIO_API_KEY}"

# Check datasets
curl -k "${BASE_STUDIO_UI_URL}/api/v1/datasets" \
  -H "Authorization: Bearer ${STUDIO_API_KEY}"
```

### 5.6 Manual API Tests

```bash
# Test 1: Health check
curl -k ${BASE_STUDIO_UI_URL}/health

# Test 2: Platform status
curl -k ${BASE_STUDIO_UI_URL}/api/v1/status \
  -H "Authorization: Bearer ${STUDIO_API_KEY}"

# Test 3: List backbones
curl -k ${BASE_STUDIO_UI_URL}/api/v1/backbones \
  -H "Authorization: Bearer ${STUDIO_API_KEY}"

# Test 4: List inference templates
curl -k ${BASE_STUDIO_UI_URL}/api/v1/templates \
  -H "Authorization: Bearer ${STUDIO_API_KEY}"
```

## Troubleshooting

### CRC Issues

**CRC won't start:**
```bash
# Check CRC status
crc status

# Delete and recreate
crc delete
crc setup
crc start

# Errors with libvirt services and inotify file watch limit:
## Check status
sudo systemctl status libvirtd

## If you see "Too many open files":
## Increase the inotify limit temporarily
sudo sysctl fs.inotify.max_user_instances=512
sudo sysctl fs.inotify.max_user_watches=524288

## Make it permanent
echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

## Then restart libvirtd
sudo systemctl stop libvirtd
sudo systemctl restart libvirtd

# Now do crc cleanup, and start
```


**Network issues:**
```bash
# Check DNS resolution
nslookup api.crc.testing

# On macOS, you may need to add to /etc/hosts:
sudo crc ip | xargs -I {} echo "{} api.crc.testing console-openshift-console.apps-crc.testing" | sudo tee -a /etc/hosts
```

### PVC Binding Issues

**PVCs stuck in Pending:**
```bash
# Check PVC events
oc describe pvc <pvc-name> -n $OC_PROJECT

# Check IBM plugin status
oc get pods -n ibm-object-s3fs
oc logs -n ibm-object-s3fs deployment/ibmcloud-object-storage-plugin

# Verify storage class
oc get sc ibmc-s3fs-cos -o yaml
```

**Certificate errors:**
```bash
# Check MinIO TLS secret
oc get secret minio-tls-secret -n $OC_PROJECT

# Verify CA bundle
oc get configmap trusted-ca-bundle -n ibm-object-s3fs -o yaml
```

### Deployment Issues

**Pods not starting:**
```bash
# Check pod status
oc get pods -n $OC_PROJECT

# View pod logs
oc logs <pod-name> -n $OC_PROJECT

# Describe pod for events
oc describe pod <pod-name> -n $OC_PROJECT

# Check resource limits
oc describe node
```

**Image pull errors:**
```bash
# Check image pull secrets
oc get secrets -n $OC_PROJECT | grep pull

# Verify image exists
oc describe pod <pod-name> -n $OC_PROJECT | grep -A 5 "Failed to pull image"
```

## Cleanup

### Remove Deployment

```bash
# Delete namespace (removes all resources)
oc delete project $OC_PROJECT

# Remove IBM plugin
helm uninstall ibm-object-storage-plugin -n ibm-object-s3fs
oc delete namespace ibm-object-s3fs
```

### Stop CRC

```bash
# Stop CRC (preserves data)
crc stop

# Delete CRC (removes all data)
crc delete
```

## Performance Tips

1. **Increase CRC resources** if you have available RAM/CPU:
   ```bash
   crc config set cpus 12
   crc config set memory 49152  # 48GB
   ```

2. **Use local image registry** to speed up deployments:
   ```bash
   # Push images to CRC internal registry
   oc registry login
   docker tag <image> default-route-openshift-image-registry.apps-crc.testing/<namespace>/<image>
   docker push default-route-openshift-image-registry.apps-crc.testing/<namespace>/<image>
   ```

3. **Persistent CRC** - Keep CRC running between sessions:
   ```bash
   # Don't stop CRC, just suspend your machine
   # CRC will resume when you wake up
   ```

## Next Steps

- [Getting Started with Studio UI](../getting-started/getting-started-UI.md)
- [SDK Usage Guide](../getting-started/getting-started-SDK.md)
- [Architecture Overview](../reference/architecture_and_requirements.md)

## Additional Resources

- [OpenShift Local Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_local/)
- [IBM Object Storage Plugin](https://github.com/IBM/ibmcloud-object-storage-plugin)
- [Geospatial Studio GitHub](https://github.com/IBM/geospatial-studio)