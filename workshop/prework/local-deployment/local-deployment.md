# Local Deployment Guide

This guide walks you through deploying Geospatial Studio on your local machine using Lima VM.

!!! info "Deployment Time"
    **Estimated time:** 30-45 minutes (depending on network speed)

## Overview

Local deployment uses Lima VM to create a Kubernetes cluster on your machine. This is ideal for:

- Learning and testing
- Development work
- Workshop participation
- Environments without cluster access

!!! warning "Limitations"
    - **No GPU acceleration**: Fine-tuning jobs will run on CPU only, which is slower but functional for learning purposes.
    - **Fixed service configuration**: Local deployment uses only in-cluster services (PostgreSQL, MinIO, Keycloak) with no option to configure external cloud services.

## Service Configuration

Local deployment automatically provisions all required services within the Lima VM:

### In-Cluster Services (Fixed)
- **PostgreSQL**: Database for metadata and application state
- **MinIO**: S3-compatible object storage for datasets and models
- **Keycloak**: OAuth2 authentication provider
- **Redis**: Caching and message queue
- **MLflow**: Experiment tracking
- **GeoServer**: Geospatial data visualization

!!! info "No External Service Options"
    Unlike cluster deployments, local deployment does **not** support configuring external cloud services such as:
    
    - IBM Cloud Databases for PostgreSQL
    - IBM Cloud Object Storage (COS) or AWS S3
    - IBM Security Verify or external OAuth providers
    
    All services run within the Lima VM for simplicity and ease of setup. This makes local deployment perfect for learning and testing, but not suitable for production use.

## Prerequisites

!!! warning "Complete Prerequisites First"
    Before proceeding, ensure you have completed all requirements in the [Prerequisites](prerequisites.md) section, including Lima VM, Python 3.11+, Helm, kubectl, and required disk space.

## Step 1: Clone the Repository

```bash
# Clone the Geospatial Studio repository
git clone https://github.com/terrastackai/geospatial-studio.git
cd geospatial-studio
```

## Step 2: Install Python Dependencies

```bash
# Install required Python packages
pip install -r requirements.txt
```

## Step 3: Start Lima VM

The Lima VM configuration is provided in the repository. Choose the appropriate configuration for your system:

=== "macOS (ARM - M1/M2/M3)"
    ```bash
    limactl start --name=studio deployment-scripts/lima/studio.yaml
    ```

=== "macOS (Intel)"
    ```bash
    limactl start --name=studio deployment-scripts/lima/studio.yaml
    ```

=== "Linux"
    ```bash
    limactl start --name=studio deployment-scripts/lima/studio-linux.yaml
    ```

!!! tip "First-time Setup"
    The first time you start Lima VM, it will download the VM image. This can take 5-10 minutes depending on your internet connection.

### Monitor VM Startup

You can monitor the VM startup progress:

```bash
# Check VM status
limactl list

# View VM logs
limactl shell studio
```

Wait until the VM status shows "Running" before proceeding.

## Step 4: Configure kubectl Context

Set up kubectl to use the Lima VM cluster:

```bash
# Export kubeconfig
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"

# Verify connection
kubectl get nodes
```

You should see output showing the cluster nodes.

## Step 5: (Optional) Pre-pull Container Images

If you have limited network bandwidth, you can pre-pull container images to speed up deployment:

```bash
NAMESPACE=default ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh
```

This step is optional but **highly recommended** if:

- You have slow internet connection
- You want to minimize deployment time
- You're in a workshop setting with many participants

!!! warning "IMPORTANT: Wait for Pre-puller to Complete"
    **If you choose to pre-pull images, you MUST wait for the pre-puller to complete before proceeding to Step 6.**
    
    - Pre-pulling can take 10-20 minutes depending on your network speed
    - Do NOT start the deployment script until you see "Pre-pull complete" message
    - Monitor progress with: `kubectl get pods -w`
    - All pre-puller pods should show "Completed" status before proceeding
    
    **Starting deployment before pre-pulling completes will cause image pull conflicts and deployment failures!**

## Step 6: Deploy Geospatial Studio

Run the automated deployment script:

```bash
./deploy_studio_lima.sh
```

### What Happens During Deployment

The script will automatically deploy all in-cluster services:

1. ✅ Check prerequisites
2. ✅ Create namespace/project
3. ✅ Deploy MinIO (in-cluster object storage)
4. ✅ Deploy Keycloak (in-cluster authentication)
5. ✅ Deploy PostgreSQL (in-cluster database)
6. ✅ Deploy Redis (in-cluster caching)
7. ✅ Generate configuration files
8. ✅ Deploy Studio Gateway API
9. ✅ Deploy Studio UI
10. ✅ Deploy MLflow (experiment tracking)
11. ✅ Deploy GeoServer (visualization)
12. ✅ Set up port forwarding
13. ✅ Create default user

!!! note "Automated Service Deployment"
    All services are automatically deployed within the Lima VM. You cannot configure external cloud services for local deployment. This simplified setup ensures quick deployment and easy management for learning and testing purposes.

### Interactive Prompts

During deployment, you'll be prompted for:

- **Namespace name** (default: `default`)
- **Admin password** (for Keycloak)
- **Database password** (for PostgreSQL)
- **Storage configuration** (use defaults for local)

!!! tip "Use Defaults"
    For workshop purposes, you can accept all default values by pressing Enter.

### Monitor Deployment Progress

You can monitor the deployment in another terminal:

```bash
# Export kubeconfig in the new terminal
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"

# Watch pods starting up
kubectl get pods -w

# Or use k9s for a better view
k9s
```

## Step 7: Verify Deployment

Once deployment completes, verify all services are running:

```bash
# Check all pods are running
kubectl get pods

# Check services
kubectl get svc
```

All pods should show status "Running" or "Completed".

## Step 8: Access the Studio

The deployment script automatically sets up port forwarding. If you need to restart any of the port-forwards you can use the following commands:
```shell
export OC_PROJECT=default
kubectl port-forward -n $OC_PROJECT svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/minio 9001:9001 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/minio 9000:9000 >> studio-pf.log 2>&1 &
``` 
Access the services at:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Studio UI** | [https://localhost:4180](https://localhost:4180) | username: `testuser`<br>password: `testpass123` |
| **Studio API** | [https://localhost:4181](https://localhost:4181) | Use API key from UI |
| **GeoServer** | [http://localhost:3000/geoserver](http://localhost:3000/geoserver) | username: `admin`<br>password: `geoserver` |
| **MLflow** | [http://localhost:5000](http://localhost:5000) | No authentication |
| **Keycloak** | [http://localhost:8080](http://localhost:8080) | username: `admin`<br>password: `admin` |
| **MinIO Console** | [https://localhost:9001](https://localhost:9001) | username: `minioadmin`<br>password: `minioadmin` |
| **MinIO API** | [https://localhost:9000](https://localhost:9000) | - |

!!! warning "SSL Certificates"
    Local deployment uses self-signed certificates. Your browser will show a security warning - this is expected. Click "Advanced" and proceed to the site.

### Test Access

1. Open [https://localhost:4180](https://localhost:4180) in your browser
2. Accept the security warning
3. Log in with username `testuser` and password `testpass123`
4. You should see the Geospatial Studio home page

## Step 9: Initial Setup

### Create API Key

For SDK and API access, create an API key:

1. Click "Manage your API keys" on the home page
2. Click "Generate new key"
3. Copy and save the API key securely
4. Store it in a config file:

```bash
echo "GEOSTUDIO_API_KEY=<your-api-key>" > ~/.geostudio_config_file
echo "BASE_STUDIO_UI_URL=https://localhost:4180" >> ~/.geostudio_config_file
```

## Troubleshooting

!!! info "Comprehensive Troubleshooting Guide"
    For detailed troubleshooting steps including port forwarding issues, pod failures, Lima VM problems, disk space, memory, and network issues, see the [Troubleshooting Guide](../resources/troubleshooting.md).
    
    Common local deployment issues covered:
    - Port forwarding disconnects
    - Pods not starting
    - Lima VM issues
    - Disk space problems
    - Memory constraints
    - Network connectivity

## Managing the Deployment

### Stop the Studio

```bash
# Stop port forwarding
pkill -f "kubectl port-forward"

# Stop Lima VM (preserves data)
limactl stop studio
```

### Start the Studio

```bash
# Start Lima VM
limactl start studio

# Set kubeconfig
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"

# Restart port forwarding (use script from troubleshooting section)
```

### Delete the Studio

```bash
# Delete Lima VM and all data
limactl delete studio

# Remove data directory
rm -rf ~/studio-data
```

## Data Persistence

Local deployment persists data in `~/studio-data/`:

- Database data
- Object storage (MinIO)
- Model artifacts
- Training datasets

This data persists across VM restarts but will be lost if you delete the Lima VM.

## Next Steps

Now that your deployment is complete:

1. [Verify Installation →](verification.md)
2. [Continue to Introduction →](../introduction/welcome.md)
3. [Start Lab 1 →](../notebooks/lab1-getting-started.ipynb)

## Additional Resources

- [Detailed Local Deployment Documentation](https://terrastackai.github.io/geospatial-studio/detailed_deployment_local/)
- [Lima VM Documentation](https://lima-vm.io/docs/)
- [Troubleshooting Guide](../resources/troubleshooting.md)

---

[← Back to Prerequisites](prerequisites.md){ .md-button } [Next: Verification →](verification.md){ .md-button .md-button--primary }