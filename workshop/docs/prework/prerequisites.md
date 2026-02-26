# Prerequisites

Before deploying Geospatial Studio, ensure you have the required software and resources.

## System Requirements

### Minimum Hardware Requirements

=== "Local Deployment"
    | Resource | Minimum | Recommended |
    |----------|---------|-------------|
    | **CPU** | 8 cores | 16+ cores |
    | **RAM** | 16 GB | 32 GB |
    | **Disk Space** | 100 GB free | 200 GB free |
    | **Network** | Stable internet | High-speed internet |

=== "Cluster Deployment"
    | Resource | Minimum | Recommended |
    |----------|---------|-------------|
    | **Worker Nodes** | 3 nodes | 5+ nodes |
    | **CPU per Node** | 8 cores | 16+ cores |
    | **RAM per Node** | 32 GB | 64 GB |
    | **GPU** | Optional | NVIDIA GPU (for training) |
    | **Storage** | 200 GB | 500 GB+ |

### Operating System

=== "Local Deployment"
    - **macOS:** 13.0 or later (ARM or Intel)
    - **Linux:** Ubuntu 20.04+, RHEL 8+, or similar

=== "Cluster Deployment"
    - **Red Hat OpenShift:** 4.12+
    - **Kubernetes:** 1.24+

## Required Software

### For All Deployments

Install the following tools before proceeding:

#### 1. Python 3.11+

```bash
# Check Python version
python --version

# Should output: Python 3.11.x or higher
```

Install Python if needed:

=== "macOS"
    ```bash
    brew install python@3.11
    ```

=== "Linux"
    ```bash
    sudo apt update
    sudo apt install python3.11 python3.11-venv python3-pip
    ```

#### 2. Helm v3.19

!!! warning "Version Compatibility"
    Helm v4 is currently **not compatible**. Use v3.19.

```bash
# Check Helm version
helm version

# Install Helm v3.19
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

#### 3. kubectl

```bash
# Check kubectl version
kubectl version --client

# Install kubectl (bundled with OpenShift CLI)
```

#### 4. OpenShift CLI (oc)

```bash
# Download from: https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html

# Verify installation
oc version
```

#### 5. jq (JSON processor)

```bash
# macOS
brew install jq

# Linux
sudo apt install jq

# Verify
jq --version
```

#### 6. yq (YAML processor)

```bash
# macOS
brew install yq

# Linux
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq

# Verify
yq --version
```

### For Local Deployment Only

#### Lima VM v1.2.1

!!! warning "Version Compatibility"
    Lima v2 is currently **not compatible**. Use v1.2.1.

```bash
# macOS
brew install lima

# Linux - follow instructions at: https://lima-vm.io/docs/installation/

# Verify
limactl --version
```

### For Cluster Deployment Only

#### Cluster Access

Ensure you have:

- ✅ Access to an OpenShift or Kubernetes cluster
- ✅ Cluster admin privileges or appropriate RBAC permissions
- ✅ Ability to create namespaces/projects
- ✅ Ability to create persistent volumes

#### Optional: S3-Compatible Object Storage

For production deployments, you may want external object storage:

- IBM Cloud Object Storage
- AWS S3
- MinIO (external instance)

## Python Dependencies

Install required Python packages:

```bash
# Clone the repository (if not already done)
git clone https://github.com/terrastackai/geospatial-studio.git
cd geospatial-studio

# Install Python dependencies
pip install -r requirements.txt
```

## Network Requirements

Ensure you have:

- ✅ Stable internet connection for downloading container images (~10-20 GB)
- ✅ Access to container registries (Docker Hub, Quay.io, etc.)
- ✅ No restrictive firewall rules blocking required ports

### Required Ports

The following ports will be used during deployment and operation:

=== "Local Deployment (k8s/Lima)"
    | Port | Service | Purpose |
    |------|---------|---------|
    | 4180 | Studio UI | Web interface (OAuth proxy) |
    | 4181 | Gateway API | REST API (OAuth proxy) |
    | 3000 | GeoServer | Map visualization |
    | 5000 | MLflow | Experiment tracking |
    | 8080 | Keycloak | Authentication service |
    | 9000 | MinIO API | Object storage API |
    | 9001 | MinIO Console | Object storage web UI |
    | 54320 | PostgreSQL | Database (port-forwarded from 5432) |

=== "Cluster Deployment (OpenShift)"
    | Port | Service | Purpose |
    |------|---------|---------|
    | 8443 | Studio UI | Web interface (OAuth proxy) |
    | 8443 | Gateway API | REST API (OAuth proxy) |
    | 3000 | GeoServer | Map visualization |
    | 5000 | MLflow | Experiment tracking |
    | 8080 | Keycloak | Authentication service |
    | 9000 | MinIO API | Object storage API |
    | 9001 | MinIO Console | Object storage web UI |
    | 5432 | PostgreSQL | Database |

!!! note "Port Forwarding"
    - **Local deployments** use port forwarding to expose services on localhost
    - **Cluster deployments** use OpenShift routes or Kubernetes ingress
    - PostgreSQL is port-forwarded to **54320** in local deployments to avoid conflicts with existing PostgreSQL installations

## Verification Checklist

Before proceeding, verify you have:

- [ ] Python 3.11+ installed
- [ ] Helm v3.19 installed
- [ ] kubectl installed
- [ ] OpenShift CLI (oc) installed
- [ ] jq installed
- [ ] yq installed
- [ ] Lima VM installed (for local deployment)
- [ ] Cluster access configured (for cluster deployment)
- [ ] Python dependencies installed
- [ ] At least 100 GB free disk space
- [ ] Stable internet connection

## Quick Verification Script

Run this script to verify your prerequisites:

```bash
#!/bin/bash

echo "Checking prerequisites..."

# Check Python
PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 11 ]; then
    echo "✅ Python 3.11+ (found $PYTHON_VERSION)"
else
    echo "❌ Python 3.11+ required (found $PYTHON_VERSION)"
fi

# Check Helm
helm version | grep -q "v3.19" && echo "✅ Helm v3.19" || echo "❌ Helm v3.19 required"

# Check kubectl
kubectl version --client &>/dev/null && echo "✅ kubectl installed" || echo "❌ kubectl required"

# Check oc
oc version &>/dev/null && echo "✅ OpenShift CLI installed" || echo "❌ OpenShift CLI required"

# Check jq
jq --version &>/dev/null && echo "✅ jq installed" || echo "❌ jq required"

# Check yq
yq --version &>/dev/null && echo "✅ yq installed" || echo "❌ yq required"

# Check Lima (for local deployment)
limactl --version &>/dev/null && echo "✅ Lima VM installed" || echo "⚠️  Lima VM required for local deployment"

# Check disk space
BLOCKSIZE=1G df . | awk 'NR==2 {if($4 >= 100) {print "✅ OK ("$4"GB available)"; exit 0} else {print "❌ Low ("$4"GB available)"; exit 1}}'

echo "Verification complete!"
```

Save this as `check-prerequisites.sh`, make it executable, and run:

```bash
chmod +x check-prerequisites.sh
./check-prerequisites.sh
```

## Next Steps

Once all prerequisites are met:

- [Choose Deployment Option →](deployment-options.md)
- [Local Deployment →](local-deployment.md)
- [Cluster Deployment →](cluster-deployment.md)

## Troubleshooting

### Common Issues

??? question "Python version too old"
    Install Python 3.11+ using your package manager or from [python.org](https://www.python.org/downloads/)

??? question "Helm v4 installed"
    Uninstall Helm v4 and install v3.19:
    ```bash
    # Remove Helm v4
    rm $(which helm)
    
    # Install Helm v3.19
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ```

??? question "Lima v2 installed"
    Uninstall Lima v2 and install v1.2.1:
    ```bash
    brew uninstall lima
    brew install lima@1.2.1
    ```

??? question "Insufficient disk space"
    Free up disk space or use an external drive with sufficient capacity

---

[← Back to Pre-work Overview](index.md){ .md-button } [Next: Deployment Options →](deployment-options.md){ .md-button .md-button--primary }