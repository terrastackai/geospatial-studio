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
[Optional] If you have limited network bandwidth, you can pre-pull the container images using the script below,
```bash
NAMESPACE=default ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh
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
./deploy_studio_k8s.sh
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

!!! success "Deployment Complete"
    Once all services are running, proceed to [First Steps](first-steps.md) to start using the Geospatial Studio.

---
