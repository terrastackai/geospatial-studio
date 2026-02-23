# GeoStudio Kubernetes Operator

## Overview

The GeoStudio Operator is a Kubernetes operator built using the [Operator Framework](https://operatorframework.io/) with Helm. It automates the deployment, configuration, and lifecycle management of GeoStudio on Kubernetes and OpenShift clusters.

---

## Quick Start - Local Development

This guide shows how to deploy GeoStudio Operator on a local Lima Kubernetes cluster for development and testing.

**Deployment Process:** The GeoStudio operator uses a **two-step deployment process**:
1. **Install Operator** (one-time) - Installs CRDs and operator controller
2. **Deploy Application** (repeatable) - Loads secrets from `.env` and deploys GEOStudio instance

### Prerequisites

- **Lima** instance running with Kubernetes (k3s)
- **Docker** installed and running on host
- **kubectl** configured with Lima kubeconfig
- **make** and **kustomize** installed

### Installation Demo

![Demo GIF showing the deployment process](assets/operator-install.gif)

### Step 1: Set up Kubeconfig

```bash
# Point kubectl to your Lima cluster
export KUBECONFIG="/Users/brianglar/.lima/studio/copied-from-guest/kubeconfig.yaml"

# Verify connection
kubectl cluster-info
```

### Step 2: Build Operator Image

Build the operator image and import it into Lima's containerd:

```bash
./build-studio-operators.sh
```

### Step 3: Install Operator

Install the operator using the local image:

```bash
cd operators
./install-geostudio-operator.sh --local
```

**Expected Output:**

```bash
==========================================
Operator installation complete!
==========================================

The GEOStudio operator is now installed and ready.

To deploy a GEOStudio application instance:
  ./deploy-geostudio-lima.sh
```

### Step 4: Deploy Application

Deploy a GEOStudio application instance:

```bash
./deploy-geostudio-lima.sh
```

This will:
- Load secrets from `workspace/lima/env/.env`
- Generate a GEOStudio CR from template
- Apply to your cluster

**Expected Output:**

```bash
==========================================
✅ GEOStudio Deployment Submitted
==========================================

Monitor deployment status:
  kubectl get geostudios -n default
  kubectl get pods -n default
```

### Step 5: Verify Deployment

Monitor the deployment progress:

```bash
# Check operator status
kubectl get pods -n geostudio-operators-system

# Check GeoStudio custom resource
kubectl get geostudio studio -n default

# Watch application pods
kubectl get pods -n default -w

# View operator logs
kubectl logs -n geostudio-operators-system deployment/operators-controller-manager -f
```

### Step 6: Access the Application

Once deployed, port-forward to access services:

```bash
# UI
kubectl port-forward svc/geofm-ui 8080:80 -n default

# API Gateway
kubectl port-forward svc/geofm-gateway 8081:4180 -n default

# MLflow
kubectl port-forward svc/geofm-mlflow 5000:5000 -n default
```

Access in your browser:
- **UI:** http://localhost:8080
- **API:** http://localhost:8081
- **MLflow:** http://localhost:5000

---

## Architecture

### High-Level Architecture

```mermaid
graph TB
    A[GeoStudio Operator<br/>Helm-based] -->|watches| B[GEOStudio CR<br/>Custom Resource]
    A -->|reconciles via| C[Helm Chart<br/>geospatial-studio]
    C -->|creates| D[Kubernetes Resources<br/>• Deployments<br/>• Services<br/>• PVCs<br/>• Jobs<br/>• ConfigMaps<br/>• Secrets]
    
    style A fill:#e3f2fd,stroke:#1e88e5
    style B fill:#e8f5e9,stroke:#43a047
    style C fill:#fff3e0,stroke:#f57c00
    style D fill:#f3e5f5,stroke:#8e24aa
```

**Component Description:**

1. **GeoStudio Operator**: Watches for `GEOStudio` custom resources and reconciles the desired state
2. **GEOStudio CR**: User-defined configuration declaring the desired GeoStudio deployment
3. **Helm Chart**: Contains all Kubernetes manifests and templates for GeoStudio components
4. **Kubernetes Resources**: The actual deployed resources (pods, services, volumes, etc.)

### Installation Flow

```mermaid
graph LR
    A[1. Install CRDs] --> B[2. Deploy Operator]
    B --> C[3. Apply GEOStudio CR]
    C --> D[4. Operator Reconciles]
    D --> E[5. Infrastructure Setup]
    E --> F[6. GeoStudio Apps Deployed]
    
    style A fill:#e3f2fd,stroke:#1e88e5
    style B fill:#e3f2fd,stroke:#1e88e5
    style C fill:#e3f2fd,stroke:#1e88e5
    style D fill:#e8f5e9,stroke:#43a047
    style E fill:#e8f5e9,stroke:#43a047
    style F fill:#fff3e0,stroke:#f57c00
```

### Helm Hook Execution Order

The GeoStudio Helm chart uses hooks to ensure components are deployed in the correct order:

```
Hook Weight    Component                 Purpose
═══════════    ════════════════════════  ══════════════════════════════════
   -100        PostgreSQL Installer      Deploy PostgreSQL database
    -90        PostgreSQL DB Creator     Create required databases
    -80        Keycloak/MinIO Installer  Deploy auth and object storage
    -75        CSI Driver Installer      Install S3 CSI driver (if enabled)
    -70        Keycloak Configurator     Configure realms, clients, users
    -70        MinIO Bucket Creator      Create S3 buckets
    -60        GeoServer PVC             Create GeoServer storage
    -55        GeoServer Installer       Deploy GeoServer
    -50        GeoServer Configurator    Configure workspaces, WMS
     0         Main Application          Deploy Gateway, UI, MLflow, Pipelines
```

## Operator Configuration

### Watches Configuration

The operator's behavior is defined in `operators/watches.yaml`:

```yaml
- group: geostudio.geostudio.ibm.com
  version: v1alpha1
  kind: GEOStudio
  chart: helm-charts/geospatial-studio
  watchDependentResources: false
  overrideValues:
    maxHistory: 3
```

**Key Settings:**
- **group/version/kind**: Defines the custom resource the operator watches
- **chart**: Path to the Helm chart bundled in the operator image
- **watchDependentResources**: Set to `false` to prevent infinite reconciliation loops
- **overrideValues**: Default values that override chart defaults

### Custom Resource Spec

Example `GEOStudio` custom resource:

```yaml
apiVersion: geostudio.geostudio.ibm.com/v1alpha1
kind: GEOStudio
metadata:
  name: studio
  namespace: default
spec:
  # Infrastructure flags - enable/disable components
  infrastructure:
    postgresql:
      enabled: true
    minio:
      enabled: true
    keycloak:
      enabled: true
    geoserver:
      enabled: false
    csiDriver:
      enabled: true

  # Global configuration
  global:
    namespace: default
    cluster_url: localhost
    environment: dev
    imagePullPolicy: Always
    
    # Object storage settings
    objectStorage:
      endpoint: https://minio.default.svc.cluster.local
      access_key: minioadmin
      secret_key: minioadmin
      region: us-east-1
      cos_storage_class: cos-s3-csi-s3fs-sc
    
    # Database settings
    postgres:
      in_cluster_db: true
      backend_uri_base: postgresql://postgres:devPostgresql123@postgresql:5432
      dbs:
        mlflow: mlflow
        gateway: geostudio
        auth: geostudio_auth
    
    # OAuth/Authentication
    oauth:
      oauthProxyEnabled: true
      type: keycloak
      clientId: geostudio-client
      issuerUrl: http://keycloak.default.svc.cluster.local:8080/realms/geostudio

  # Component-specific configuration
  gfm-studio-gateway:
    enabled: true
    image:
      name: quay.io/geospatial-studio/geostudio-gateway
      tag: latest

  geofm-ui:
    enabled: true
    image:
      name: quay.io/geospatial-studio/geostudio-ui
      tag: latest

  gfm-mlflow:
    enabled: true

  geospatial-studio-pipelines:
    enabled: true
```

---

## Development Workflow

### Making Changes

When you make changes to the operator or Helm chart:

#### 1. Update the Helm Chart

```bash
cd geospatial-studio/

# Make your changes to templates or values.yaml
vim templates/my-template.yaml

# Test the chart locally
helm template test-release . -f values.yaml
```

#### 2. Rebuild and Deploy

```bash
# Rebuild the operator image
./build-operator-lima.sh

# Restart the operator to pick up changes
kubectl rollout restart deployment/operators-controller-manager -n geostudio-operators-system

# Wait for rollout to complete
kubectl rollout status deployment/operators-controller-manager -n geostudio-operators-system

# Monitor operator logs
kubectl logs -n geostudio-operators-system deployment/operators-controller-manager -f
```

#### 3. Trigger Reconciliation

The operator automatically reconciles every 60 seconds, but you can trigger it manually:

```bash
# Add an annotation to force reconciliation
kubectl annotate geostudio studio -n default reconcile="$(date +%s)" --overwrite
```

### Debugging

#### View Operator Logs

```bash
# Real-time logs
kubectl logs -n geostudio-operators-system deployment/operators-controller-manager -f

# Last 100 lines
kubectl logs -n geostudio-operators-system deployment/operators-controller-manager --tail=100

# Filter for errors
kubectl logs -n geostudio-operators-system deployment/operators-controller-manager | grep -i error
```

#### Check Helm Release Status

```bash
# The operator creates a Helm release internally
kubectl get secrets -n default | grep "sh.helm.release"

# View release details
helm list -n default
```

#### Common Issues

**Issue: Image Pull Errors**
```bash
# Verify local image exists
limactl shell studio sudo ctr -n k8s.io images ls | grep geostudio-operator

# Check imagePullPolicy is set to Never
kubectl get deployment operators-controller-manager -n geostudio-operators-system \
  -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'
```

**Issue: RBAC Permission Denied**
```bash
# Check operator's ClusterRole
kubectl describe clusterrole operators-manager-role

# Verify events permissions include patch and update
kubectl describe clusterrole operators-manager-role | grep -A 5 events
```

**Issue: Reconciliation Loop**

If the operator continuously reconciles without settling:
1. Check for Helm hook issues (PVCs with `before-hook-creation` policy)
2. Verify `watchDependentResources: false` in watches.yaml
3. Review operator logs for specific errors

---

## Production Deployment

For production deployments (non-Lima environments), the same **two-step process** applies:
1. **Install Operator** - One-time setup of CRDs and operator controller
2. **Deploy Application** - Repeatable deployment with environment-specific configuration

This approach allows you to:
- Install the operator once per cluster
- Deploy multiple GEOStudio instances with different configurations
- Update applications without touching the operator
- Manage secrets securely via workspace `.env` files

### Step 1: Build and Push to Registry

```bash
# Build for production
./build-studio-operators.sh --prod

# Or build manually:
cd operators
docker build --load \
  --build-arg CHART_VERSION=0.1.4 \
  -t quay.io/geospatial-studio/geostudio-operator:v0.1.0 \
  -f ../Dockerfile.operator .

# Push to registry
docker push quay.io/geospatial-studio/geostudio-operator:v0.1.0
```

### Step 2: Install Operator (One-Time)

```bash
# Set kubeconfig for your cluster
export KUBECONFIG="/path/to/your/kubeconfig"

# Install using production script
cd operators
./install-geostudio-operator.sh --prod
```

**What this does:**
- Installs GEOStudio CRDs cluster-wide
- Deploys operator controller in `geostudio-operators-system` namespace
- Configures RBAC and necessary permissions
- Does NOT deploy any application instances

### Step 3: Deploy Application (Repeatable)

```bash
# Create production workspace and configure secrets
export DEPLOYMENT_ENV=production
export OC_PROJECT=geostudio-prod

./deploy-geostudio-lima.sh

# Edit production secrets
vim ../workspace/production/env/.env

# Deploy
./deploy-geostudio-lima.sh
```

**What this does:**
- Checks that operator is installed and running
- Creates workspace at `workspace/production/`
- Loads secrets from `workspace/production/env/.env`
- Generates GEOStudio CR from template with variable substitution
- Applies the CR to deploy the application

**Note:** You can run step 3 multiple times to:
- Deploy to different namespaces
- Update application configuration
- Redeploy after making changes

The production approach uses published images from quay.io and manages secrets securely via the gitignored workspace.

---

## Troubleshooting Guide

### Operator Won't Start

**Symptoms:** Operator pod in CrashLoopBackOff

**Diagnosis:**
```bash
kubectl describe pod -n geostudio-operators-system -l control-plane=controller-manager
kubectl logs -n geostudio-operators-system -l control-plane=controller-manager --previous
```

**Common Causes:**
- Missing or invalid CRDs
- RBAC permissions issues
- Image not found or pull errors

### Application Not Deploying

**Symptoms:** GeoStudio CR exists but no application pods are created

**Diagnosis:**
```bash
# Check operator logs
kubectl logs -n geostudio-operators-system deployment/operators-controller-manager -f

# Check GeoStudio CR status
kubectl describe geostudio studio -n default

# Check Helm release
helm list -n default
```

**Common Causes:**
- Helm chart errors (template rendering failures)
- Missing dependencies (PostgreSQL not ready)
- Resource quota exceeded

### Services Not Accessible

**Symptoms:** Pods running but services not reachable

**Diagnosis:**
```bash
# Check service endpoints
kubectl get endpoints -n default

# Verify service selectors match pod labels
kubectl get svc geofm-ui -n default -o yaml
kubectl get pods -n default --show-labels
```

---

## Additional Resources

### Related Files

**Operator Build:**
- `Dockerfile.operator.local` - Local operator image definition
- `Dockerfile.operator` - Production operator image definition
- `build-studio-operators.sh` - Build script for local and production

**Operator Installation:**
- `operators/install-geostudio-operator.sh` - Install operator (one-time)
- `operators/deploy-geostudio-lima.sh` - Deploy application (repeatable)
- `operators/uninstall-geostudio.sh` - Complete uninstall script

**Operator Configuration:**
- `operators/watches.yaml` - Operator watch configuration
- `operators/config/rbac/role.yaml` - Operator RBAC permissions
- `operators/config/crd/` - Custom Resource Definitions
- `operators/Makefile` - Build and deployment targets

**Application Templates:**
- `operators/examples/geostudio-operator-template.yaml` - Main template with variable substitution
- `operators/examples/my-geostudio-midpoint.yaml` - Reference (deprecated)
- `operators/examples/my-geostudio.yaml` - Reference (deprecated)
- `operators/examples/README.md` - Detailed deployment guide

**Helm Chart:**
- `geospatial-studio/` - Bundled Helm chart
- `geospatial-studio/values.yaml` - Default values with placeholders

**Workspace (Runtime):**
- `workspace/<env>/env/.env` - Secrets (gitignored)
- `workspace/<env>/env/env.sh` - Configuration (gitignored)
- `workspace/<env>/geostudio-operator-deploy.yaml` - Generated CR (gitignored)
- `operators/install-geostudio.sh` - Production installation script

### Helm Chart Documentation

For detailed information about the Helm chart configuration, see:
- `geospatial-studio/values.yaml` - Default values and documentation
- `geospatial-studio/templates/` - Kubernetes manifests

### Operator SDK

The GeoStudio Operator is built with [Operator SDK](https://sdk.operatorframework.io/):
- [Helm Operator Tutorial](https://sdk.operatorframework.io/docs/building-operators/helm/)
- [Best Practices](https://sdk.operatorframework.io/docs/best-practices/)

---

## Contributing

When contributing changes to the operator:

1. **Test locally first** using Lima deployment
2. **Update documentation** if adding new features or configuration options
3. **Follow semantic versioning** for operator versions
4. **Test upgrade paths** to ensure smooth upgrades
