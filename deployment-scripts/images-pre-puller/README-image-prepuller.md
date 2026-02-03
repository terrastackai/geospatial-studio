# Geospatial Studio Image Pre-Puller

This directory contains scripts and configuration for pre-pulling container images to worker nodes before deploying Geospatial Studio. This significantly reduces pod startup time and prevents image pull timeouts, especially in low-bandwidth environments.

## Overview

The image pre-puller uses a Kubernetes DaemonSet to pull all required container images to worker nodes (excluding control plane nodes). It handles 9 container images totaling approximately 5-10GB.

### Container Images

The following images are pre-pulled:

1. `bitnamilegacy/oauth2-proxy:latest` (~100MB)
2. `quay.io/geospatial-studio/geostudio-gateway:latest` (~500MB-1GB)
3. `bitnamilegacy/kubectl:latest` (~50MB)
4. `quay.io/geospatial-studio/geostudio-pipelines:latest` (~500MB-1GB)
5. `linuxserver/yq:latest` (~20MB)
6. `quay.io/geospatial-studio/geostudio-ui:latest` (~200-500MB)
7. `ghcr.io/mlflow/mlflow:latest` (~500MB-1GB)
8. `bitnamilegacy/redis:latest` (~100MB)
9. `quay.io/geospatial-studio/terratorch:latest` (~3-5GB)

## Files

- **`image-prepuller-daemonset.yaml`** - Kubernetes DaemonSet configuration
- **`deploy-image-prepuller.sh`** - Deployment script with progress monitoring
- **`cleanup-image-prepuller.sh`** - Cleanup script for removing the DaemonSet
- **`README-image-prepuller.md`** - This documentation file

## Prerequisites

- `kubectl` installed and configured
- Access to a Kubernetes cluster
- Appropriate RBAC permissions to create DaemonSets
- Image pull secret configured (if using private registries)

## Usage

### 1. Deploy the Image Pre-Puller

```bash
# Deploy with default namespace (OC_PROJECT)
./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh

# Or specify a custom namespace
NAMESPACE=my-namespace ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh

# Or specify a custom YAML file
./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh path/to/custom-daemonset.yaml
```

The deployment script will:
- Verify prerequisites (kubectl, namespace, YAML file)
- Update the namespace in the YAML file
- Deploy the DaemonSet
- Monitor progress with real-time updates
- Show completion status for each worker node

### 2. Monitor Progress

The deployment script automatically monitors progress, showing:
- Number of worker nodes
- Pod status (Running/Pending/Failed)
- Image pull progress per node (e.g., "5/11 images pulled")
- Elapsed time

Example output:
```
[12:00:15] Pods: 3/3 Running, 0 Pending
  ├─ worker-node-1: 11/11 images pulled
  ├─ worker-node-2: 8/11 images pulled
  ├─ worker-node-3: 6/11 images pulled
```

### 3. Manual Status Check

```bash
# Check DaemonSet status
kubectl get daemonset geostudio-image-prepuller -n OC_PROJECT

# Check pod status
kubectl get pods -n OC_PROJECT -l name=geostudio-image-prepuller -o wide

# Check logs from a specific pod
kubectl logs -n OC_PROJECT <pod-name> -c prepull-04-model-inference

# Check all init container logs
kubectl logs -n OC_PROJECT <pod-name> --all-containers=true
```

### 4. Cleanup

After images are pulled and your application is deployed, remove the DaemonSet:

```bash
# Interactive cleanup (prompts for confirmation)
./deployment-scripts/images-pre-puller/cleanup-image-prepuller.sh

# With custom namespace
NAMESPACE=my-namespace ./deployment-scripts/images-pre-puller/cleanup-image-prepuller.sh
```

The cleanup script will:
- Show current DaemonSet and pod status
- Prompt for confirmation
- Delete the DaemonSet
- Wait for pods to terminate gracefully
- Offer force deletion if needed
- Leave pulled images cached on nodes (desired behavior)

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

Update the secret name in `image-prepuller-daemonset.yaml` if different:

```yaml
imagePullSecrets:
- name: your-secret-name
```

### Timeout Settings

The deployment script has a 2-hour timeout (suitable for low bandwidth). Adjust in `deploy-image-prepuller.sh`:

```bash
MAX_WAIT_TIME=7200  # 2 hours in seconds
```

### Node Selection

The DaemonSet is configured to run only on worker nodes (not control plane). This is controlled by node affinity:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/control-plane
          operator: DoesNotExist
        - key: node-role.kubernetes.io/master
          operator: DoesNotExist
```

To target specific nodes, add additional match expressions:

```yaml
- key: node-type
  operator: In
  values:
  - gpu-node
```

## Low Bandwidth Considerations

The solution is optimized for low-bandwidth environments:

1. **No Strict Timeouts**: 2-hour maximum wait time allows for slow downloads
2. **Sequential Pulling**: Images are pulled one at a time per node (via init containers)
3. **Progress Monitoring**: Real-time feedback shows which images are being pulled
4. **Graceful Handling**: Script continues monitoring even if some nodes are slower
5. **Resource Limits**: Conservative CPU/memory limits prevent node overload

## Troubleshooting

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

Verify worker nodes exist:
```bash
kubectl get nodes -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master'
```

Check DaemonSet events:
```bash
kubectl describe daemonset geostudio-image-prepuller -n OC_PROJECT
```

### Slow Image Pulls

This is expected in low-bandwidth environments. The script will continue monitoring. You can:
- Check network bandwidth: `kubectl exec -it <pod-name> -n OC_PROJECT -- sh`
- Monitor node disk usage: `kubectl top nodes`
- Verify no rate limiting from registry

## Best Practices

1. **Pre-pull Before Deployment**: Run this before deploying Geospatial Studio
2. **Verify Completion**: Ensure all pods show "11/11 images pulled" before cleanup
3. **Keep Images Cached**: Don't remove images from nodes after cleanup
4. **Re-run on Node Addition**: Deploy again if new worker nodes are added
5. **Update Image Tags**: Modify YAML if using specific image tags instead of `latest`

## Advanced Usage

### Custom Image List

To modify the image list, edit `image-prepuller-daemonset.yaml` and add/remove init containers:

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