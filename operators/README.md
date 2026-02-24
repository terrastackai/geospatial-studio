# GeoStudio Operator

The GeoStudio Operator is a Kubernetes operator built using the [Operator Framework](https://operatorframework.io/) with Helm. It automates the deployment, configuration, and lifecycle management of GeoStudio on Kubernetes and OpenShift clusters.

## Directory Structure

```
operators/
├── geostudio-cli.sh                 # 🆕 Unified CLI (use this!)
├── lib/                             # Shared libraries
│   ├── common.sh                    # Logging, colors, utilities
│   ├── k8s-utils.sh                 # Kubernetes helpers
│   ├── operator-commands.sh         # Operator management
│   └── app-commands.sh              # Application management
├── config/                          # Operator configuration
│   ├── crd/                         # Custom Resource Definitions
│   ├── rbac/                        # RBAC roles and bindings
│   ├── manager/                     # Operator deployment manifests
│   └── default/                     # Kustomize overlay
├── examples/                        # Example GeoStudio CRs
│   └── geostudio-operator-template.yaml
├── watches.yaml                     # Operator watch configuration
└── Makefile                         # Build and deploy targets
```

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

## Quick Start - Local Development

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
./geostudio-cli.sh operator install --local
```

### Step 4: Deploy Application

Deploy a GEOStudio application instance:

```bash
./geostudio-cli.sh app deploy
```

### Step 5: Verify Deployment

Monitor the deployment progress:

```bash
# Check operator status
./geostudio-cli.sh operator status

# Check application status
./geostudio-cli.sh app status

# Watch application pods
kubectl get pods -n default -w

# View operator logs
./geostudio-cli.sh operator logs --follow
```

### Step 6: Access the Application

Once deployed, port-forward to access services:

```bash
# Auth Server
kubectl port-forward svc/geofm-ui 8080:8080 -n default

# UI
kubectl port-forward svc/geofm-ui 4180:4180 -n default

# API Gateway
kubectl port-forward svc/geofm-gateway 4181:4181 -n default

# MLflow
kubectl port-forward svc/geofm-mlflow 5000:5000 -n default
```

Access in your browser:
 **UI:** http://localhost:4180
 **API:** http://localhost:4181
 **MLflow:** http://localhost:5000

## CLI Reference

### Operator Commands

```bash
# Install operator (local development)
./geostudio-cli.sh operator install --local

# Install operator (production)
./geostudio-cli.sh operator install --prod --version v0.1.0

# Check operator status
./geostudio-cli.sh operator status

# View operator logs
./geostudio-cli.sh operator logs --follow

# Restart operator
./geostudio-cli.sh operator restart

# Uninstall operator
./geostudio-cli.sh operator uninstall
```

### Application Commands

```bash
# Deploy application (default: lima/default)
./geostudio-cli.sh app deploy

# Deploy to different environment/namespace
./geostudio-cli.sh app deploy --env production --namespace prod

# Generate manifest without deploying
./geostudio-cli.sh app deploy --dry-run

# List all deployed instances
./geostudio-cli.sh app list

# Check application status
./geostudio-cli.sh app status --namespace prod

# View application logs
./geostudio-cli.sh app logs --component gateway --follow

# Restart application
./geostudio-cli.sh app restart --namespace prod

# Delete application
./geostudio-cli.sh app delete --namespace staging
```

## Complete Workflows

### Local Development Setup

Sample Custom Resource Spec: [GEOStudio custom resource](examples/geostudio-operator-template.yaml)

After making changes to the Helm chart or operator:

```bash
# 1. Rebuild operator
./build-studio-operators.sh

# 2. [OPTIONAL: If you have installed it previously] Delete current deployment
./geostudio-cli.sh app delete

# 3. [OPTIONAL: If you have installed it previously] Uninstall operator
./geostudio-cli.sh operator uninstall

# 4. Reinstall operator
./geostudio-cli.sh operator install --local

# 5. Deploy fresh instance
./geostudio-cli.sh app deploy

# 4. Check status
./geostudio-cli.sh operator status
./geostudio-cli.sh app status
```

### Production Deployment

For production deployments, use the `--prod` flag and specify a version:

```bash
./geostudio-cli.sh operator install --prod --version v1.0.0
```

This will pull the operator image from the production registry (quay.io/geospatial-studio).

### Clean Up

```bash
# Delete application only
./geostudio-cli.sh app delete --namespace default

# Delete everything (app + operator)
./geostudio-cli.sh app delete
./geostudio-cli.sh operator uninstall
```

## After Deployment

| | |
|---|---|
| Access the Studio UI | [https://localhost:4180](https://localhost:4180) |
| Access the Studio API | [https://localhost:4181](https://localhost:4181) |
| Authenticate Studio | username: `testuser` password: `testpass123` |
| Access Geoserver | [http://localhost:3000/geoserver](http://localhost:3000/geoserver) |
| Authenticate Geoserver | username: `admin` password: `geoserver` |
| Access MLflow | [http://localhost:5000](http://localhost:5000) |
| Access Keycloak | [http://localhost:8080](http://localhost:8080) |
| Authenticate Keycloak  | username: `admin` password: `admin` |
| Access Minio | Console: [https://localhost:9001](https://localhost:9001)      API: [https://localhost:9000](https://localhost:9000) |
| Authenticate Minio | username: `minioadmin` password: `minioadmin` |

If you need to restart any of the port-forwards you can use the following commands:
```shell
kubectl port-forward -n $OC_PROJECT svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/minio 9001:9001 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/minio 9000:9000 >> studio-pf.log 2>&1 &
```