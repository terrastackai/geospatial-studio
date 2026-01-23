# GPU-Enabled Development Setup (nvkind)

## Overview

This section targets cases where you have a host machine (local or remote) that has access to **NVIDIA GPUs** and leverage [`nvkind`](https://github.com/NVIDIA/nvkind/blob/f1a690fa3f4b0dcb41eb8d6acdda05accf045187/README.md) to create and manage `kind` kubernetes clusters with access to GPUs.

The automated shell script will deploy dependencies (Minio, Keycloak and Postgresql), before generating the deployment configuration for the studio and then deploying the main studio services + pipelines.
    
    **For CPU-only:** Use [Local Development Setup](local-development-kind.md)

---

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| **nvkind** | Latest | [Install Guide](https://github.com/NVIDIA/nvkind#install-nvkind) |
| **Helm** | v3.19 | [Install Helm](https://helm.sh/docs/intro/install/) |
| **OpenShift CLI** | Latest | [Install oc](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html) |
| **kubectl** | Latest | Bundled with oc |
| **jq** | Latest | [Install jq](https://jqlang.github.io/jq/download/) |
| **yq** | Latest | [Install yq](https://github.com/mikefarah/yq#install) |

!!! warning "Helm Version"
    **v3.19 required** - incompatible with v4

## Deployment Steps

### Step 1: Configure nvkind Prerequisites

Follow the [nvkind prerequisites](https://github.com/NVIDIA/nvkind#prerequisites) for your OS.

**Verify GPU detection:**
```bash
nvidia-smi -L
```

**Expected output:**
```
GPU 0: NVIDIA L4 (UUID: GPU-3e71c48d-90c0-f46f-195b-4150320f9910)
```

**Test Docker GPU access:**
```bash
docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all ubuntu:20.04 nvidia-smi -L
```

**Expected output:**
```
GPU 0: NVIDIA L4 (UUID: GPU-3e71c48d-90c0-f46f-195b-4150320f9910)
```
---

### Step 2: Run nvkind Setup

Complete the [setup steps](https://github.com/NVIDIA/nvkind#setup) from nvkind documentation.

**Verify configuration:**
```bash
docker run -v /dev/null:/var/run/nvidia-container-devices/all ubuntu:20.04 nvidia-smi -L
```

**Expected output:**
```bash
# GPU 0: NVIDIA L4 (UUID: GPU-3e71c48d-90c0-f46f-195b-4150320f9910)
```

---

### Step 3: Install nvkind
```bash
# Install nvkind
go install github.com/NVIDIA/nvkind/cmd/nvkind@latest

# Clone and build (if needed)
git clone https://github.com/NVIDIA/nvkind.git
cd nvkind
make
```

---

### Step 4: Create nvkind Cluster
```bash
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
```

---

### Step 5: Configure kubectl
```bash
kubectl cluster-info --context kind-studio
```

---

### Step 6: Install NVIDIA GPU Operator
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && \
helm repo update && \
helm install --wait --generate-name \
  -n gpu-operator --create-namespace \
  nvidia/gpu-operator --version=v25.10.0
```

!!! info "GPU Operator"
    This may take several minutes. It manages NVIDIA drivers and device plugins in the cluster.

**Verify installation:**
```bash
kubectl get pods -n gpu-operator
```

All pods should show `Running` status.

---

### Step 7: Install Python Dependencies
```bash
pip install -r requirements.txt
```

---

### Step 8: Deploy Geospatial Studio
```bash
./deploy_studio_nvkind.sh
```

!!! warning "Deployment Time"
    ~10-15 minutes depending on download speed and GPU operator initialization.

---

## Monitor Deployment

### Using k9s
```bash
k9s
```

---

## Next Steps

!!! success "Deployment Complete!"
    Your GPU-enabled Geospatial Studio is ready.

**Continue to [First Steps](first-steps.md)** to access services and start using the studio.

---

