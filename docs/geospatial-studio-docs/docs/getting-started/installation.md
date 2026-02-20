# Installation Guide

## Choose Your Deployment Method

The Geospatial Studio can be deployed in several ways depending on your infrastructure and requirements. Choose the deployment method that best fits your needs:

## Deployment Options

### 🖥️ Local Deployment
**Best for:** Development, testing, and learning

Deploy the Studio on your local machine using Docker and Kubernetes (Kind or Minikube).

- **Pros:** Quick setup, no cloud costs, full control
- **Cons:** Limited resources, not suitable for production
- **Requirements:** Docker, Kubernetes CLI, 16GB+ RAM recommended

[→ Local Deployment Guide](../deployment/detailed_deployment_local.md)

---

### ☸️ Kubernetes Deployment
**Best for:** Production environments with existing Kubernetes infrastructure

Deploy on any standard Kubernetes cluster (GKE, EKS, AKS, etc.).

- **Pros:** Scalable, cloud-native, flexible
- **Cons:** Requires Kubernetes expertise
- **Requirements:** Kubernetes cluster, kubectl access, GPU nodes (optional)

[→ Kubernetes Deployment Guide](../deployment/detailed_deployment_k8s.md)

---

### 🔴 OpenShift Deployment
**Best for:** Enterprise environments using Red Hat OpenShift

Deploy on Red Hat OpenShift for enhanced security and enterprise features.

- **Pros:** Enterprise support, enhanced security, integrated CI/CD
- **Cons:** Requires OpenShift license
- **Requirements:** OpenShift cluster, oc CLI, appropriate permissions

[→ OpenShift Deployment Guide](../deployment/detailed_deployment_cluster.md)

---

### 🧪 Kind Cluster (Local Kubernetes)
**Best for:** Local development with Kubernetes features

Deploy using Kind (Kubernetes in Docker) for a lightweight local cluster.

- **Pros:** Fast setup, true Kubernetes environment, minimal resources
- **Cons:** Limited to local development
- **Requirements:** Docker, Kind, 8GB+ RAM

[→ Kind Cluster Guide](../deployment/kind_cluster_deployment.md)

---

### 🎮 NVKind Cluster (GPU Support)
**Best for:** Local development with NVIDIA GPU support

Deploy using NVKind for local Kubernetes with GPU acceleration.

- **Pros:** GPU support locally, realistic training environment
- **Cons:** Requires NVIDIA GPU, more complex setup
- **Requirements:** NVIDIA GPU, Docker, NVKind, NVIDIA Container Toolkit

[→ NVKind Cluster Guide](../deployment/nvkind_cluster_deployment.md)

---

## Quick Comparison

| Feature | Local | Kubernetes | OpenShift | Kind | NVKind |
|---------|-------|------------|-----------|------|--------|
| Setup Time | 30 min | 1-2 hours | 1-2 hours | 15 min | 30 min |
| Production Ready | ❌ | ✅ | ✅ | ❌ | ❌ |
| GPU Support | Limited | ✅ | ✅ | ❌ | ✅ |
| Scalability | Low | High | High | Low | Low |
| Cost | Free | Variable | License + Infra | Free | Free |

## System Requirements

### Minimum Requirements
- **CPU:** 4 cores
- **RAM:** 8GB
- **Storage:** 50GB free space
- **OS:** Linux, macOS, or Windows with WSL2

### Recommended Requirements
- **CPU:** 8+ cores
- **RAM:** 16GB+
- **Storage:** 100GB+ SSD
- **GPU:** NVIDIA GPU with 8GB+ VRAM (for training)

## Next Steps

1. Choose your deployment method above
2. Follow the specific deployment guide
3. Complete the [First Steps](first-steps.md) after deployment
4. Start using the [UI](getting-started-UI.md) or [SDK](getting-started-SDK.md)

## Need Help?

- Check the [Architecture documentation](../reference/architecture_and_requirements.md) for system design details
- Review [Sample Payloads](../reference/sample-payloads.md) for API examples
- [Report issues](https://github.com/terrastackai/geospatial-studio/issues) on GitHub