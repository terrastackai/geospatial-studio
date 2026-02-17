# GeoStudio Operator - Quick Start Guide

This guide provides the minimal steps to deploy the GeoStudio operator and application.

## Prerequisites

- Kubernetes cluster (Lima, Minikube, or any K8s cluster)
- `kubectl` configured to access your cluster
- `helm` CLI (v3.12+)
- `docker` CLI with access to push to quay.io
- `envsubst` command (install via `brew install gettext` on macOS)

## Deployment Steps

### 1. Set Kubernetes Context

```bash
# For Lima users
export KUBECONFIG="/Users/brianglar/.lima/studio/copied-from-guest/kubeconfig.yaml"

# For other clusters, ensure your kubeconfig is set
kubectl config current-context
```

### 2. Build and Push Helm Chart

```bash
cd geospatial-studio

# Update dependencies
helm dependency update

# Package the chart
helm package . --destination .

# Push to quay.io (replace version if needed)
helm push geospatial-studio-0.1.4.tgz oci://quay.io/geospatial-studio/charts/geospatial-studio
```

### 3. Deploy Infrastructure

```bash
# Deploy PostgreSQL, Keycloak, MinIO, and GeoServer
./operators/scripts/setup-infrastructure.sh
```

**Note:** This script will prompt for namespace and other configuration options.

### 4. Build and Push Operator

```bash
cd operators

# Build operator image (update version tag as needed)
docker build --load \
  --build-arg CHART_VERSION=0.1.4 \
  -t quay.io/geospatial-studio/geostudio-operator:v0.0.2a10 .

# Push to quay.io
docker push quay.io/geospatial-studio/geostudio-operator:v0.0.2a10
```

### 5. Install Operator

```bash
# Install CRDs and deploy operator to geostudio-operator-system namespace
make install NAMESPACE=geostudio-operator-system IMG=quay.io/geospatial-studio/geostudio-operator
```

### 6. Deploy GeoStudio Application

```bash
# Copy example environment file
cp operators/examples/.env.example .geostudio-env

# Edit the environment file with your configuration
vim .geostudio-env

# Source the environment variables
set -a
source .geostudio-env
set +a

# Generate GeoStudio custom resource from template
envsubst < operators/examples/geostudio-template2.yaml > my-geostudio.yaml

# Review the generated configuration (optional but recommended)
cat my-geostudio.yaml

# Deploy GeoStudio application
kubectl apply -f my-geostudio.yaml
```

### 7. Verify Deployment

```bash
# Check operator status
kubectl get pods -n geostudio-operator-system

# Check GeoStudio custom resource
kubectl get geostudio -n ${NAMESPACE:-default}

# Check application pods
kubectl get pods -n ${NAMESPACE:-default}

# Watch deployment progress
kubectl get pods -n ${NAMESPACE:-default} -w
```

## Accessing the Application

### Port Forwarding

```bash
# Forward UI port
kubectl port-forward svc/geofm-ui 8080:80 -n ${NAMESPACE:-default}

# Forward API Gateway port
kubectl port-forward svc/geofm-gateway 8081:4180 -n ${NAMESPACE:-default}

# Forward MLflow port
kubectl port-forward svc/geofm-mlflow 5000:5000 -n ${NAMESPACE:-default}
```

Access the application:
- **UI:** http://localhost:8080
- **API:** http://localhost:8081
- **MLflow:** http://localhost:5000

## Configuration

### Environment Variables

Edit `.geostudio-env` to customize your deployment. Key variables include:

```bash
NAMESPACE=default                          # Target namespace
CLUSTER_URL=localhost                      # Cluster URL for routes
POSTGRES_PASSWORD=your-secure-password     # PostgreSQL password
MINIO_PASSWORD=your-secure-password        # MinIO password
REDIS_PASSWORD=your-secure-password        # Redis password
```

For a complete list of variables, see `operators/examples/.env.example`.

## Updating the Deployment

### Update Application Configuration

```bash
# Edit environment variables
vim .geostudio-env

# Regenerate and apply
set -a
source .geostudio-env
set +a
envsubst < operators/examples/geostudio-template2.yaml > my-geostudio.yaml
kubectl apply -f my-geostudio.yaml
```

### Update Operator

```bash
cd operators

# Build new operator version
docker build --load \
  --build-arg CHART_VERSION=0.1.4 \
  -t quay.io/geospatial-studio/geostudio-operator:v0.0.2a11 .

# Push to registry
docker push quay.io/geospatial-studio/geostudio-operator:v0.0.2a11

# Update deployment
make deploy IMG=quay.io/geospatial-studio/geostudio-operator:v0.0.2a11 NAMESPACE=geostudio-operator-system
```

## Troubleshooting

### Check Operator Logs

```bash
kubectl logs -n geostudio-operator-system -l control-plane=controller-manager -f
```

### Check Application Logs

```bash
# Gateway logs
kubectl logs -n ${NAMESPACE:-default} -l app.kubernetes.io/name=gfm-studio-gateway

# UI logs
kubectl logs -n ${NAMESPACE:-default} -l app.kubernetes.io/name=geofm-ui

# MLflow logs
kubectl logs -n ${NAMESPACE:-default} -l app.kubernetes.io/name=gfm-mlflow
```

### Check Events

```bash
kubectl get events -n ${NAMESPACE:-default} --sort-by='.lastTimestamp' | tail -20
```

### Common Issues

**Pods in ImagePullBackOff:**
- Ensure images are accessible from your cluster
- Create image pull secrets if using private registries

**Database Connection Errors:**
- Verify PostgreSQL is running: `kubectl get pods -l app.kubernetes.io/name=postgresql`
- Check database credentials in `.geostudio-env`

**Operator Not Reconciling:**
- Verify CRDs are installed: `kubectl get crd | grep geostudio`
- Check operator pod status: `kubectl get pods -n geostudio-operator-system`

## Cleanup

### Remove Application

```bash
kubectl delete -f my-geostudio.yaml
```

### Remove Infrastructure

```bash
kubectl delete deployment minio keycloak geoserver -n ${NAMESPACE:-default}
helm uninstall postgresql -n ${NAMESPACE:-default}
```

### Remove Operator

```bash
cd operators
make undeploy NAMESPACE=geostudio-operator-system
make uninstall
```

### Remove Namespace

```bash
kubectl delete namespace ${NAMESPACE:-default}
kubectl delete namespace geostudio-operator-system
```

## Next Steps

- Review the full deployment guide in [DEPLOYMENT.md](DEPLOYMENT.md) for production considerations
- Configure monitoring and observability
- Set up backup and disaster recovery
- Enable high availability for production workloads

## Support

For issues and questions:
- GitHub Issues: https://github.com/IBM/geospatial-studio/issues
- Full Documentation: [DEPLOYMENT.md](DEPLOYMENT.md)
