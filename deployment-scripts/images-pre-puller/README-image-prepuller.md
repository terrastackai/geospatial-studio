# Geospatial Studio Image Pre-Puller

This directory contains scripts and configuration for pre-pulling container images before deploying Geospatial Studio. This significantly reduces pod startup time and prevents image pull timeouts, especially in low-bandwidth environments.

## Smart Cluster Detection

The deployment script **automatically detects your cluster topology** and selects the appropriate configuration:

- **Single-node clusters** (Minikube, Kind, Docker Desktop): Deploys to all nodes including control plane
- **Multi-node clusters**: Deploys to worker nodes only, excluding control plane

No manual configuration needed - the script handles everything automatically!

## Overview

The image pre-puller uses a Kubernetes DaemonSet to pull all required container images to nodes. It handles 14 container images totaling approximately 10-12GB.

### Container Images

The following 14 images are pre-pulled:

1. `bitnamilegacy/oauth2-proxy:latest` (~100MB)
2. `quay.io/geospatial-studio/geostudio-gateway:latest` (~500MB-1GB)
3. `bitnamilegacy/kubectl:latest` (~50MB)
4. `quay.io/geospatial-studio/geostudio-pipelines:latest` (~500MB-1GB)
5. `linuxserver/yq:latest` (~20MB)
6. `quay.io/geospatial-studio/geostudio-ui:latest` (~200-500MB)
7. `ghcr.io/mlflow/mlflow:latest` (~500MB-1GB)
8. `bitnamilegacy/redis:latest` (~100MB)
9. `quay.io/geospatial-studio/terratorch:latest` (~3-5GB)
10. `quay.io/minio/minio:latest` (~100MB)
11. `bitnamilegacy/postgresql:latest` (~200MB)
12. `bitnamilegacy/os-shell:latest` (~50MB)
13. `quay.io/keycloak/keycloak:26.4.5` (~500MB)
14. `docker.osgeo.org/geoserver:2.28.1` (~500MB-1GB)

## Files

- **`image-prepuller.yaml`** - Universal DaemonSet template (dynamically configured by script)
- **`deploy-image-prepuller.sh`** - Smart deployment script with automatic cluster detection and cleanup
- **`README-image-prepuller.md`** - This documentation file

## Prerequisites

- `kubectl` installed and configured
- Access to a Kubernetes cluster
- Appropriate RBAC permissions to create DaemonSets
- Image pull secret configured (if using private registries)

## Usage

### 1. Deploy the Image Pre-Puller

```bash
# Deploy with default namespace and auto-cleanup
./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh

# Or specify a custom namespace
NAMESPACE=my-namespace ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh

# Keep DaemonSet running (disable auto-cleanup)
AUTO_CLEANUP=false ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh
```

The deployment script will:
- Verify prerequisites (kubectl, namespace)
- Detect cluster topology automatically
- Generate appropriate configuration dynamically
- Deploy the DaemonSet
- Monitor progress with real-time updates
- Show completion status for each node
- Automatically cleanup DaemonSet (images remain cached)

### 2. Monitor Progress

The deployment script automatically monitors progress, showing:
- Cluster type detection (single-node vs multi-node)
- Number of target nodes
- Pod status (Active/Pending/Complete)
- Real-time image pull progress per node (e.g., "8/14" = 8 images pulled/pulling)
- Elapsed time

Example output for multi-node cluster:
```
[CLUSTER] Detected: Multi-node cluster with 3 worker node(s)
[INFO] Will deploy to WORKER NODES ONLY (excluding control plane)

[12:00:15] Pods: 3/3 Active (2 pulling images, 1 complete), 0 Pending - Progress: 10/14
  ├─ worker-node-1: ✓ Complete (14/14 images pulled)
  ├─ worker-node-2: ⟳ Pulling images (10/14)
  ├─ worker-node-3: ⟳ Pulling images (7/14)

[SUCCESS] All 14 images successfully pulled on all target nodes!
[INFO] Cleaning up DaemonSet (images remain cached on nodes)...
```

Example output for single-node cluster:
```
[CLUSTER] Detected: Single-node cluster (Minikube/Kind/Docker Desktop)
[INFO] Will deploy to ALL nodes (including control plane)

[12:00:15] Pods: 1/1 Active (1 pulling images, 0 complete), 0 Pending - Progress: 5/14
  ├─ minikube: ⟳ Pulling images (5/14)
```

### 3. Manual Status Check

```bash
# Check DaemonSet status
kubectl get daemonset geostudio-image-prepuller -n OC_PROJECT

# Check pod status
kubectl get pods -n OC_PROJECT -l name=geostudio-image-prepuller -o wide

# Check logs from a specific pod
kubectl logs -n OC_PROJECT <pod-name> -c prepull-04-pipelines

# Check all init container logs
kubectl logs -n OC_PROJECT <pod-name> --all-containers=true
```

### 4. Cleanup

**By default, the DaemonSet is automatically cleaned up after successful image pull.**

Images remain cached on nodes for fast deployment. If you disabled auto-cleanup:

```bash
# Manual cleanup
kubectl delete daemonset geostudio-image-prepuller -n <namespace>
```

**Important:** Cleanup only removes the DaemonSet pods, NOT the pulled images. Images remain cached on nodes (this is the desired behavior for pre-pulling).

## Configuration

### Namespace

Update the namespace in the YAML file or set the `NAMESPACE` environment variable:

```bash
NAMESPACE=my-custom-namespace ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh
```

### Image Pull Secret

If using private registries, ensure the image pull secret exists:

```bash
kubectl get secret us-icr-pull-secret -n OC_PROJECT
```

Update the secret name in `image-prepuller.yaml` if different:

```yaml
imagePullSecrets:
- name: your-secret-name
```

### Timeout Settings

The deployment script has a 2-hour timeout (suitable for low bandwidth). Adjust in `deploy-image-prepuller.sh`:

```bash
MAX_WAIT_TIME=7200  # 2 hours in seconds
```

### Automatic Configuration

The deployment script automatically detects your cluster type and generates the appropriate configuration:

**Single-Node Clusters (Minikube, Kind, Docker Desktop):**
- Deploys to all nodes including control plane
- No node affinity restrictions
- Includes tolerations for control plane taints

**Multi-Node Clusters:**
- Deploys to worker nodes only
- Dynamically adds node affinity to exclude control plane
- Includes tolerations for tainted nodes

**How it works:**
1. Script reads the universal template `image-prepuller.yaml`
2. Detects cluster topology (worker node count)
3. Dynamically injects appropriate node affinity configuration
4. Applies configuration directly via stdin (no temporary files)

**Manual Override:**

If you need to manually deploy with specific configuration, edit `image-prepuller.yaml` and replace `# NODE_AFFINITY_PLACEHOLDER` with:

For worker-only deployment:
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/control-plane
          operator: DoesNotExist
```

For all-nodes deployment:
```yaml
# No affinity - runs on all nodes
```

## Low Bandwidth Considerations

The solution is optimized for low-bandwidth environments:

1. **No Strict Timeouts**: 2-hour maximum wait time allows for slow downloads
2. **Sequential Pulling**: Images are pulled one at a time per node (via init containers)
3. **Progress Monitoring**: Real-time feedback shows which images are being pulled
4. **Graceful Handling**: Script continues monitoring even if some nodes are slower
5. **Resource Limits**: Conservative CPU/memory limits prevent node overload

## Troubleshooting

### Cluster Detection Issues

If the script incorrectly detects your cluster type:

1. Check node labels:
```bash
kubectl get nodes --show-labels
```

2. Verify control plane nodes:
```bash
kubectl get nodes -l 'node-role.kubernetes.io/control-plane'
```

3. Verify worker nodes:
```bash
kubectl get nodes -l '!node-role.kubernetes.io/control-plane'
```

4. The script dynamically generates the correct configuration, but you can manually apply if needed:
```bash
# Manually apply with namespace substitution
sed 's/namespace: OC_PROJECT/namespace: your-namespace/' image-prepuller.yaml | kubectl apply -f -
```

### Pods Stuck in Pending

Check node resources and taints:
```bash
kubectl describe node <node-name>
kubectl get pods -n OC_PROJECT -l name=geostudio-image-prepuller -o wide
```

### Image Pull Failures

Check pod events and logs:
```bash
kubectl describe pod <pod-name> -n OC_PROJECT
kubectl logs <pod-name> -n OC_PROJECT -c <container-name>
```

Common issues:
- Image pull secret not configured
- Network connectivity issues
- Registry authentication failures
- Insufficient disk space on nodes

### DaemonSet Not Scheduling

Check DaemonSet status and events:
```bash
kubectl get daemonset geostudio-image-prepuller -n OC_PROJECT
kubectl describe daemonset geostudio-image-prepuller -n OC_PROJECT
```

Verify the correct YAML was selected:
```bash
kubectl get daemonset geostudio-image-prepuller -n OC_PROJECT -o yaml | grep -A5 "affinity\|tolerations"
```

Check pod events:
```bash
kubectl get pods -n OC_PROJECT -l name=geostudio-image-prepuller
kubectl describe pod <pod-name> -n OC_PROJECT
```

### Slow Image Pulls

This is expected in low-bandwidth environments. The script will continue monitoring. You can:
- Check network bandwidth: `kubectl exec -it <pod-name> -n OC_PROJECT -- sh`
- Monitor node disk usage: `kubectl top nodes`
- Verify no rate limiting from registry

## Best Practices

1. **Pre-pull Before Deployment**: Run this before deploying Geospatial Studio
2. **Verify Completion**: Ensure all pods show "14/14 images pulled" before cleanup
3. **Keep Images Cached**: Don't remove images from nodes after cleanup
4. **Re-run on Node Addition**: Deploy again if new worker nodes are added
5. **Update Image Tags**: Modify YAML if using specific image tags instead of `latest`

## Advanced Usage

### Custom Image List

To modify the image list, edit `image-prepuller.yaml` and add/remove init containers:

```yaml
initContainers:
- name: prepull-custom-image
  image: your-registry/your-image:tag
  command: ['sh', '-c', 'echo "✓ Custom image pulled" && sleep 1']
  resources:
    requests:
      cpu: 10m
      memory: 100Mi
```

### Parallel Pulling

For faster pulling on high-bandwidth networks, convert init containers to regular containers (they'll pull in parallel):

```yaml
containers:
- name: pull-image-1
  image: image1:latest
  command: ['sh', '-c', 'sleep infinity']
# ... more containers
```

Note: This increases resource usage and may overwhelm nodes with limited bandwidth.

## License

© Copyright IBM Corporation 2025  
SPDX-License-Identifier: Apache-2.0