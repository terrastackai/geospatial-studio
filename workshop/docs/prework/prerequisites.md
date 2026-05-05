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

## Resource Allocation Modes

Geospatial Studio supports multiple resource allocation profiles to match different deployment scenarios and workload requirements. During deployment, you'll be prompted to select a resource mode that determines CPU, memory, and storage allocations for all components.

!!! important "Resource Planning"
    The resource requirements listed below include a **30% buffer** to ensure cluster stability and avoid resource exhaustion. Always provision clusters with these recommended totals rather than just the sum of component requests.

### Available Modes

=== "Low Mode"
    **Best for:** Testing, proof-of-concept, or resource-constrained environments

    - **CPU:** ~6-8 cores
    - **Memory:** ~16-20 GB RAM
    - **Storage:** ~50-75 GB

    **Component Resource Requests:**

    | Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
    |-----------|-------------|-----------|----------------|--------------|---------|
    | MinIO | 500m | 1 | 512Mi | 1Gi | 30Gi |
    | Keycloak | 100m | 500m | 256Mi | 512Mi | - |
    | PostgreSQL | 100m | 500m | 256Mi | 512Mi | 2Gi |
    | PgBouncer | 250m | 1 | 256Mi | 1Gi | - |
    | GeoServer | Default | Default | Default | Default | 2Gi |
    | MLflow | Default | Default | Default | Default | 1Gi |
    | Redis Master | Default | Default | Default | Default | 1Gi |
    | Redis Replica | Default | Default | Default | Default | 1Gi |
    | Gateway API | Default | Default | Default | Default | - |
    | Gateway Worker | Default | Default | Default | Default | - |
    | Gateway OAuth | Default | Default | Default | Default | - |
    | UI | Default | Default | Default | Default | - |
    | UI OAuth | Default | Default | Default | Default | - |
    | Studio Storage | - | - | - | - | 10-15Gi |


    !!! note "Default Resources"
        Components marked as "Default" use Kubernetes resources as defined in the Helm chart or scale and timeshare at runtime based on available resource in cluster.

=== "Dev Mode"
    **Best for:** Development, testing, and small-scale deployments

    - **CPU:** ~8-14 cores
    - **Memory:** ~22-32 GB RAM
    - **Storage:** ~75-100 GB

    **Component Resource Requests:**

    | Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
    |-----------|-------------|-----------|----------------|--------------|---------|
    | MinIO | 2 | 4 | 2Gi | 4Gi | 40Gi |
    | Keycloak | 250m | 1 | 512Mi | 1Gi | - |
    | PostgreSQL | 250m | 1 | 512Mi | 1Gi | 2Gi |
    | PgBouncer | 250m | 1 | 256Mi | 1Gi | - |
    | GeoServer | Default | Default | Default | Default | 2Gi |
    | MLflow | Default | Default | Default | Default | 1Gi |
    | Redis Master | Default | Default | Default | Default | 1Gi |
    | Redis Replica | Default | Default | Default | Default | 1Gi |
    | Gateway API | Default | Default | Default | Default | - |
    | Gateway Worker | Default | Default | Default | Default | - |
    | Gateway OAuth | Default | Default | Default | Default | - |
    | UI | Default | Default | Default | Default | - |
    | UI OAuth | Default | Default | Default | Default | - |
    | Studio Storage | - | - | - | - | 15-20Gi |


=== "Medium Mode"
    **Best for:** Production deployments with moderate workloads

    - **CPU:** ~21-32 cores
    - **Memory:** ~62-84 GB RAM
    - **Storage:** ~200-400 GB

    **Component Resource Requests:**

    | Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
    |-----------|-------------|-----------|----------------|--------------|---------|
    | MinIO | 4 | 8 | 3Gi | 6Gi | 100Gi |
    | Keycloak | 500m | 1.5 | 768Mi | 1536Mi | - |
    | PostgreSQL | 500m | 1.5 | 768Mi | 1536Mi | 10Gi |
    | PgBouncer | 1 | 2 | 2Gi | 4Gi | - |
    | GeoServer | 750m | 1.5 | 8Gi | 24Gi | 30Gi |
    | MLflow | 1 | 1 | 6Gi | 12Gi | 1Gi |
    | Redis Master | 1 | 2 | 1Gi | 2Gi | 1Gi |
    | Redis Replica | 1 | 2 | 1Gi | 2Gi | 1Gi |
    | Gateway API | 2 | 4 | 4Gi | 16Gi | - |
    | Gateway Worker | 500m | 1 | 512Mi | 1.5Gi | - |
    | Gateway OAuth | 500m | 1 | 512Mi | 1Gi | - |
    | UI | 1 | 2 | 2Gi | 4Gi | - |
    | UI OAuth | 500m | 1 | 512Mi | 1Gi | - |
    | Studio Storage | - | - | - | - | 20-25Gi |


=== "High Mode"
    **Best for:** Production deployments with high workloads and performance requirements

    - **CPU:** ~31-52 cores
    - **Memory:** ~104-156 GB RAM
    - **Storage:** ~0.8-1.5 TB

    **Component Resource Requests:**

    | Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
    |-----------|-------------|-----------|----------------|--------------|---------|
    | MinIO | 3 | 6 | 4Gi | 8Gi | 500Gi |
    | Keycloak | 750m | 2 | 1Gi | 2Gi | - |
    | PostgreSQL | 750m | 2 | 1Gi | 2Gi | 10Gi |
    | PgBouncer | 1 | 2 | 4Gi | 8Gi | - |
    | GeoServer | 1 | 3 | 12Gi | 48Gi | 200Gi |
    | MLflow | 1 | 1 | 8Gi | 16Gi | 5Gi |
    | Redis Master | 1 | 2 | 2Gi | 4Gi | 5Gi |
    | Redis Replica | 1 | 2 | 2Gi | 4Gi | 5Gi |
    | Gateway API | 4 | 8 | 8Gi | 32Gi | - |
    | Gateway Worker | 1 | 2 | 1Gi | 2Gi | - |
    | Gateway OAuth | 1 | 2 | 512Mi | 1Gi | - |
    | UI | 2 | 4 | 4Gi | 8Gi | - |
    | UI OAuth | 512m | 1 | 512Mi | 1Gi | - |
    | Studio Storage | - | - | - | - | 100-110Gi |


=== "XLarge Mode"
    **Best for:** Enterprise production deployments with maximum performance requirements

    **Recommended Cluster Resources (with 30% buffer):**

    - **CPU:** ~42-74+ cores
    - **Memory:** ~156-240+ GB RAM
    - **Storage:** ~1.8-2.0+ TB

    **Component Resource Requests:**

    | Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
    |-----------|-------------|-----------|----------------|--------------|---------|
    | MinIO | 4 | 8 | 6Gi | 12Gi | 1000Gi |
    | Keycloak | 1 | 4 | 2Gi | 4Gi | - |
    | PostgreSQL | 1 | 4 | 2Gi | 4Gi | 10Gi |
    | PgBouncer | 1 | 2 | 8Gi | 16Gi | - |
    | GeoServer | 2 | 4 | 12Gi | 60Gi | 200Gi |
    | MLflow | 1 | 2 | 8Gi | 16Gi | 10Gi |
    | Redis Master | 1 | 2 | 4Gi | 8Gi | 10Gi |
    | Redis Replica | 1 | 2 | 4Gi | 8Gi | 10Gi |
    | Gateway API | 5 | 10 | 8Gi | 36Gi | - |
    | Gateway Worker | 2 | 4 | 2Gi | 4Gi | - |
    | Gateway OAuth | 2 | 4 | 1Gi | 2Gi | - |
    | UI | 3 | 6 | 8Gi | 16Gi | - |
    | UI OAuth | 1 | 2 | 1Gi | 2Gi | - |
    | Studio Storage | - | - | - | - | 200-220Gi |

=== "Custom Mode"
    **Best for:** Specialized deployments with specific resource requirements

    When selecting custom mode, you'll need to manually configure resource allocations in the `env.sh` file for your deployment environment. This allows fine-grained control over each component's resources.

    !!! tip "Custom Mode Planning"
        When using custom mode, remember to add a 30% buffer to your calculated resource requirements to ensure cluster stability.

### Mode Selection Guidelines

Choose your resource mode based on:

1. **Workload Type:**
   - **Testing/PoC:** Low or Dev mode
   - **Development:** Dev or Medium mode
   - **Production (light):** Medium mode
   - **Production (heavy):** High or XLarge mode

2. **Available Infrastructure:**
   - Match the mode to your cluster's available resources
   - Ensure the recommended totals (with 30% buffer) fit within your cluster capacity
   - Consider storage I/O performance requirements
   - Leave headroom for Kubernetes system components and monitoring tools

3. **Expected Usage:**
   - **Number of concurrent users:** More users = higher mode
   - **Dataset sizes:** Larger datasets = higher mode
   - **Model training frequency:** Frequent training = higher mode
   - **Inference workload:** High inference volume = higher mode

### Resource Planning Example

For a **Medium Mode** deployment:

```
Actual Component Needs:  ~16 CPU, ~48 GB RAM, ~180 GB storage
+ 30% Buffer:            ~5 CPU,  ~16 GB RAM, ~55 GB storage
─────────────────────────────────────────────────────────────
Recommended Cluster:     ~21 CPU, ~64 GB RAM, ~235 GB storage
```

!!! tip "Resource Optimization"
    - Start with a lower mode and scale up based on actual usage
    - Monitor resource utilization using Kubernetes metrics
    - Adjust individual component resources in custom mode if needed
    - Consider using node autoscaling for dynamic workloads
    - The 30% buffer accounts for:
        - Kubernetes system overhead
        - Pod scheduling inefficiencies
        - Temporary resource spikes
        - Monitoring and logging tools

!!! warning "Storage Considerations"
    - Storage values shown are for persistent volumes only
    - Add ~10-20 GB for container images (pulled once per node)
    - Plan for data growth over time (models, datasets, logs)
    - Use high-performance storage classes (SSD/NVMe) for production
    - Consider separate storage tiers for hot vs. cold data

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