# Local Development Setup (Kind Cluster)

## Overview

Whilst not providing full performance and functionality, the studio can be deployed for testing and development purposes.  The instructions below will deploy the main components of the Geospatial Studio in a Kubernetes cluster on a local or remote machine.  This is provisioned through a [Kind Cluster](https://kind.sigs.k8s.io/).

The automated shell script will deploy dependencies (Minio, Keycloak and Postgresql), before generating the deployment configuration for the studio and then deploying the main studio services + pipelines.

---

## Prerequisites

Before you begin, ensure you have the following tools installed on your system:

### Required Tools

| Tool | Version | Purpose | Installation Link |
|------|---------|---------|-------------------|
| **kind** | Latest | Runs Kubernetes clusters in Docker containers | [Install Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| **Helm** | v3.19 | Kubernetes package manager | [Install Helm](https://helm.sh/docs/intro/install/) |
| **OpenShift CLI (oc)** | Latest | Kubernetes command-line tool | [Install oc](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html) |
| **kubectl** | Latest | Bundled with OpenShift CLI | Included with oc |
| **jq** | Latest | JSON command-line processor | [Install jq](https://jqlang.github.io/jq/download/) |
| **yq** | Latest | YAML command-line processor | [Install yq](https://github.com/mikefarah/yq#install) |
| **Python** | 3.8+ | Required for deployment scripts | [Install Python](https://www.python.org/downloads/) |
| **Docker** | Latest | Container runtime (required by Kind) | [Install Docker](https://docs.docker.com/get-docker/) |

!!! warning "Helm Version Compatibility"
    Currently, Helm **v3.19** is required. The deployment is **incompatible with Helm v4**.

---

## Deployment Steps

### Step 1: Create the Kind Cluster

```bash
cat << EOF | kind create cluster --name=studio --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
EOF
```

??? info "What does this do?"
    - Creates a Kubernetes cluster named `studio`
    - Sets up 2 nodes:
        - **Control-plane node**: Manages the cluster (scheduling, API server, etc.)
        - **Worker node**: Runs your application workloads
    - Both nodes run as Docker containers on your machine

---

### Step 2: Configure kubectl Context

Point kubectl to your newly created Kind cluster.
```bash
kubectl cluster-info --context kind-studio
```

??? info "What does this do?"
    - Sets your kubectl context to `kind-studio`
    - Ensures all kubectl commands target the correct cluster
    - Displays cluster information to verify connectivity

---

### Step 3: Install Python Dependencies

Install required Python packages for the deployment scripts.
```bash
pip install -r requirements.txt
```

!!! tip "Using Virtual Environments"
    It's recommended to use a Python virtual environment:
```bash
    python -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
```

---

### Step 4: Deploy Geospatial Studio

Run the automated deployment script.
```bash
./deploy_studio_nvkind.sh
```

??? info "What does this do?"
    The deployment script performs the following steps automatically:

    **Phase 1: Infrastructure Setup**
    
    - Deploys MinIO for object storage
    - Deploys PostgreSQL database
    - Deploys Keycloak for authentication and authorization
    
    **Phase 2: Configuration Generation**
    
    - Generates deployment configurations based on your environment
    - Creates necessary Kubernetes secrets and config maps
    - Sets up networking and ingress rules
    
    **Phase 3: Studio Deployment**
    
    - Deploys the GeoSpatial Studio 

!!! warning "Deployment Time"
    Deployment typically takes **~10 minutes** or longer, depending on:
    
    - Your internet download speed (for container images)
    - System resources (CPU, RAM, disk)
    - Docker image cache status

---

## Monitoring the Deployment

### Using k9s (Recommended)

[k9s](https://k9scli.io) is a terminal-based UI for managing Kubernetes clusters.

---

### Access the Application

After successful deployment, you can access the Geospatial Studio:
```bash
# Get the service URL (example)
kubectl get svc -n geospatial-studio
```

!!! success "Deployment Complete"
    Once all services are running, proceed to [First Steps](first-steps.md) to start using the Geospatial Studio.

---
<!-- 
# First Steps After Deployment

## Overview

Congratulations! 🎉 Your Geospatial Studio is now running locally. This guide will help you access and explore the various components of the platform.

The studio deployment includes several services that work together to provide geospatial processing capabilities. Each service has its own web interface and purpose.

---

## Accessing the Services

### Core Studio Components

| Service | URL | Purpose |
|---------|-----|---------|
| **Studio UI** | [https://localhost:4180](https://localhost:4180) | Main web interface for the Geospatial Studio |
| **Studio API** | [https://localhost:4181](https://localhost:4181) | REST API for programmatic access |
| **GeoServer** | [https://localhost:3000/geoserver](https://localhost:3000/geoserver) | Geospatial data server and map rendering |
| **MLflow** | [https://localhost:5000](https://localhost:5000) | Machine learning experiment tracking |

### Infrastructure Services

| Service | URL | Purpose |
|---------|-----|---------|
| **Keycloak** | [https://localhost:8080](https://localhost:8080) | Authentication and user management |
| **MinIO Console** | [https://localhost:9001](https://localhost:9001) | Object storage web interface |
| **MinIO API** | [https://localhost:9000](https://localhost:9000) | Object storage API endpoint |

---

## Default Credentials

!!! warning "Security Notice"
    These are **default credentials for local development only**. Never use these credentials in production environments.

### Studio Authentication

Access the Studio UI at [https://localhost:4180](https://localhost:4180)
```
Username: testuser
Password: testpass123
```

### GeoServer Authentication

Access GeoServer at [https://localhost:3000/geoserver](https://localhost:3000/geoserver)
```
Username: admin
Password: geoserver
```

### MinIO Authentication

Access MinIO Console at [https://localhost:9001](https://localhost:9001)
```
Username: minioadmin
Password: minioadmin
```

---

## Initial Setup - API Key Configuration

Before you can use the Studio API or SDK, you need to generate an API key. This key authenticates your requests to the Studio backend.

### Step 1: Log In to the Studio UI

1. Navigate to [https://localhost:4180](https://localhost:4180)
2. Log in with default credentials:
   - Username: `testuser`
   - Password: `testpass123`

---

### Step 2: Generate an API Key

1. On the Studio UI homepage, locate and click the **"Manage your API keys"** link
2. A popup window will appear where you can:
   - Generate new API keys
   - View existing keys
   - Delete old keys

![Location of API key link](../images/sdk-auth.png)

3. Click **"Generate New Key"** (or similar button)
4. **Copy the generated API key immediately** - you won't be able to see it again!

!!! warning "Save Your API Key"
    Store your API key securely. Once you close the popup, you won't be able to retrieve the same key again. If you lose it, you'll need to generate a new one.

---

### Step 3: Configure Your Environment

Set up environment variables for easy access to the Studio API:
```bash
# Set your API key
export STUDIO_API_KEY="<your api key from the UI>"

# Set the UI/API URL
export UI_ROUTE_URL="https://localhost:4180"
```

**Example:**
```bash
export STUDIO_API_KEY="sk_1234567890abcdef1234567890abcdef"
export UI_ROUTE_URL="https://localhost:4180"
```

!!! tip "Make It Permanent"
    To avoid setting these variables every time, add them to your shell profile:
```bash
    # For bash
    echo 'export STUDIO_API_KEY="your-key-here"' >> ~/.bashrc
    echo 'export UI_ROUTE_URL="https://localhost:4180"' >> ~/.bashrc
    source ~/.bashrc
    
    # For zsh
    echo 'export STUDIO_API_KEY="your-key-here"' >> ~/.zshrc
    echo 'export UI_ROUTE_URL="https://localhost:4180"' >> ~/.zshrc
    source ~/.zshrc
```

---

### Step 4: Verify Your Setup

Test that your API key works:
```bash
# Using curl
curl -X GET "${UI_ROUTE_URL}/api/v1/health" \
  -H "Authorization: Bearer ${STUDIO_API_KEY}" \
  -H "accept: application/json"
```

**Expected response:**
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

---

## Service Descriptions

### 🖥️ Studio UI

**What it is:** The main web interface for interacting with the Geospatial Studio.

**What you can do:**
- Upload and manage geospatial datasets
- Create and configure processing pipelines
- Monitor job execution
- Visualize results on maps
- Manage projects and workflows
- **Generate and manage API keys**

**Getting started:**
1. Navigate to [https://localhost:4180](https://localhost:4180)
2. Log in with credentials: `testuser` / `testpass123`
3. Generate your API key (see [Initial Setup](#initial-setup-api-key-configuration))
4. Explore the dashboard and available features

---

### 🔌 Studio API

**What it is:** RESTful API for programmatic access to studio functionality.

**What you can do:**
- Automate workflows using scripts
- Integrate with other applications
- Submit jobs programmatically
- Query results and metadata

**Getting started:**
1. Generate an API key (see [Initial Setup](#initial-setup-api-key-configuration))
2. Set environment variables
3. API documentation available at [https://localhost:4181/docs](https://localhost:4181/docs)
4. Test API endpoints using curl, Postman, or Python requests

**Example API call:**
```bash
# Health check (no auth required)
curl -X GET "https://localhost:4181/api/v1/health"

# Authenticated request
curl -X GET "${UI_ROUTE_URL}/api/v1/projects" \
  -H "Authorization: Bearer ${STUDIO_API_KEY}" \
  -H "accept: application/json"
```

---

### 🗺️ GeoServer

**What it is:** Open-source server for sharing and publishing geospatial data.

**What you can do:**
- View and manage geospatial layers
- Configure map styles and symbology
- Serve maps via WMS/WFS protocols
- Preview data on interactive maps

**Getting started:**
1. Navigate to [https://localhost:3000/geoserver](https://localhost:3000/geoserver)
2. Log in with credentials: `admin` / `geoserver`
3. Explore the "Layer Preview" to see available maps

---

### 🤖 MLflow

**What it is:** Platform for managing machine learning lifecycle.

**What you can do:**
- Track ML experiments and parameters
- Compare model performance
- View training metrics and visualizations
- Manage model versions

**Getting started:**
1. Navigate to [https://localhost:5000](https://localhost:5000)
2. No authentication required (local development)
3. Browse experiments and runs from geospatial ML pipelines

---

### 🔐 Keycloak

**What it is:** Identity and access management system.

**What you can do:**
- Manage users and roles
- Configure authentication settings
- View login sessions
- Administer security policies

**Getting started:**
1. Navigate to [https://localhost:8080](https://localhost:8080)
2. Click "Administration Console"
3. Use admin credentials if configured

!!! info "For Advanced Users"
    Keycloak is primarily for administrators. Most users won't need direct access to this service.

---

### 📦 MinIO

**What it is:** High-performance object storage (S3-compatible).

**What you can do:**
- View stored datasets and files
- Manage buckets and access policies
- Monitor storage usage
- Download/upload files manually

**Getting started:**
1. Navigate to [https://localhost:9001](https://localhost:9001)
2. Log in with credentials: `minioadmin` / `minioadmin`
3. Browse buckets created by the studio

---

## Port Forwarding Management

### What is Port Forwarding?

Port forwarding allows you to access services running inside the Kubernetes cluster from your local machine. The deployment script automatically sets up port forwards for all services.

### Checking Active Port Forwards
```bash
# List all kubectl port-forward processes
ps aux | grep "port-forward"

# Check if ports are in use
lsof -i :4180  # Studio UI
lsof -i :4181  # Studio API
lsof -i :3000  # GeoServer
lsof -i :5000  # MLflow
lsof -i :8080  # Keycloak
lsof -i :9001  # MinIO Console
lsof -i :9000  # MinIO API
```

### Restarting Port Forwards

If you need to restart any port forwards (e.g., after disconnection), use these commands:
```bash
# Keycloak (Authentication)
kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &

# PostgreSQL Database
kubectl port-forward -n default svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &

# GeoServer (Map Server)
kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &

# Studio UI (Frontend)
kubectl port-forward -n default deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &

# Studio API Gateway
kubectl port-forward -n default deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &

# MLflow (ML Tracking)
kubectl port-forward -n default deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &

# MinIO Console
kubectl port-forward -n default svc/minio 9001:9001 >> studio-pf.log 2>&1 &

# MinIO API
kubectl port-forward -n default svc/minio 9000:9000 >> studio-pf.log 2>&1 &
```

??? info "Understanding the Port Forward Command"
```bash
    kubectl port-forward -n default svc/minio 9001:9001 >> studio-pf.log 2>&1 &
```
    
    - `kubectl port-forward` - Creates the port forward
    - `-n default` - Uses the 'default' namespace
    - `svc/minio` - Targets the MinIO service
    - `9001:9001` - Maps local port 9001 to service port 9001
    - `>> studio-pf.log` - Appends output to log file
    - `2>&1` - Redirects errors to the log file
    - `&` - Runs the command in the background

### Restart All Port Forwards

To restart all port forwards at once:
```bash
# Create a script to restart all port forwards
cat > restart-portforwards.sh << 'EOF'
#!/bin/bash

echo "Stopping existing port forwards..."
pkill -f "kubectl port-forward"

echo "Starting port forwards..."
kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/minio 9001:9001 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/minio 9000:9000 >> studio-pf.log 2>&1 &

echo "Port forwards restarted. Check studio-pf.log for details."
EOF

chmod +x restart-portforwards.sh
./restart-portforwards.sh
```

### Stop All Port Forwards

When you're done working:
```bash
# Stop all port forwards
pkill -f "kubectl port-forward"
```

---

## Troubleshooting

### Cannot Access Services

??? question "Service not responding at localhost URL"
    **Possible causes:**
    - Port forward not running
    - Service not ready yet
    
    **Solutions:**
```bash
    # Check if pods are running
    kubectl get pods -n default
    
    # Check if port forward is active
    ps aux | grep "port-forward"
    
    # Restart port forward
    # (use commands from section above)
    
    # Check service logs
    kubectl logs -n default deployment/geofm-ui
```

??? question "Connection refused or timeout"
    **Solution:**
```bash
    # Verify the service is running
    kubectl get svc -n default
    
    # Check pod status
    kubectl get pods -n default
    
    # Describe the pod for errors
    kubectl describe pod <pod-name> -n default
```

??? question "Port already in use"
    **Cause:** Another application is using the port
    
    **Solution:**
```bash
    # Find what's using the port (e.g., 4180)
    lsof -i :4180
    
    # Kill the process
    kill -9 <PID>
    
    # Or change the port in the port-forward command
    kubectl port-forward ... 4190:4180 ...  # Use different local port
```

### Authentication Issues

??? question "Login fails with correct credentials"
    **Solutions:**
```bash
    # Check Keycloak is running
    kubectl get pods -n default | grep keycloak
    
    # Check Keycloak logs
    kubectl logs -n default svc/keycloak
    
    # Verify Keycloak port forward
    ps aux | grep "8080"
```

??? question "API key not working"
    **Solutions:**
    
    1. **Verify the key was copied correctly** (no extra spaces)
    2. **Check the Authorization header format:**
```bash
       -H "Authorization: Bearer ${STUDIO_API_KEY}"
```
    3. **Generate a new API key** if the old one was deleted
    4. **Verify environment variable is set:**
```bash
       echo $STUDIO_API_KEY
```

### Performance Issues

??? question "Services are slow or unresponsive"
    **Possible causes:**
    - Insufficient resources
    - Heavy processing jobs
    
    **Solutions:**
```bash
    # Check resource usage
    kubectl top nodes
    kubectl top pods -n default
    
    # Check Docker resources
    docker stats
    
    # Increase Docker resources in Docker Desktop settings
```

---

## Quick Health Check

Run this command to verify all services are running:
```bash
# Check all pods in default namespace
kubectl get pods -n default

# All pods should show STATUS: Running
# READY should show matching numbers (e.g., 1/1, 2/2)
```

**Example healthy output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
geofm-gateway-xxxxxxxxx-xxxxx     1/1     Running   0          10m
geofm-ui-xxxxxxxxx-xxxxx          1/1     Running   0          10m
geofm-geoserver-xxxxxxxxx-xxxxx   1/1     Running   0          10m
keycloak-xxxxxxxxx-xxxxx          1/1     Running   0          12m
minio-xxxxxxxxx-xxxxx             1/1     Running   0          12m
postgresql-xxxxxxxxx-xxxxx        1/1     Running   0          12m
```

---

## Next Steps - Start Using the Studio

Now that you have configured your API access, you're ready to start using the Geospatial Studio! 🚀

### 1. Onboard Initial Artifacts

Before trying out the full functionality, you'll want to onboard some initial data and resources:

- 📁 **Upload sample datasets** - Try uploading GeoTIFF files or shapefiles
- 🔧 **Configure processing pipelines** - Set up your first workflow
- 🎯 **Define models and parameters** - Configure ML models if applicable
- 📦 **Organize in projects** - Create projects to organize your work

### 2. Explore the Studio UI

- 🗺️ **Interactive map viewer** - Visualize your geospatial data
- 📊 **Dashboard** - Monitor jobs and system status
- 📂 **Data browser** - Explore uploaded datasets
- ⚙️ **Pipeline builder** - Create processing workflows

### 3. Try the API/SDK

With your API key configured, you can now:
```python
# Example Python SDK usage
from studio_sdk import StudioClient

client = StudioClient(
    api_key=os.getenv("STUDIO_API_KEY"),
    base_url=os.getenv("UI_ROUTE_URL")
)

# List projects
projects = client.projects.list()

# Upload a dataset
dataset = client.datasets.upload("path/to/data.tif")

# Create and run a pipeline
pipeline = client.pipelines.create(name="My First Pipeline")
job = pipeline.run(dataset_id=dataset.id)
```


--- -->