# Installation

## Prerequisites

Before choosing a deployment path, ensure these tools are installed:

| Tool | Version | Purpose |
|------|---------|---------|
| Helm | v3.19+ | Kubernetes package manager — [Install](https://helm.sh/docs/intro/install/) |
| OpenShift CLI (oc) | Latest | Kubernetes CLI (includes kubectl) — [Install](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html) |
| jq | Latest | JSON processor — [Install](https://jqlang.github.io/jq/download/) |
| yq | Latest | YAML processor — [Install](https://github.com/mikefarah/yq#install) |
| Python | 3.8+ | Deployment scripts — [Install](https://www.python.org/downloads/) |

!!! note "Additional prerequisites for specific paths"
    - **Kind / NVKind:** Docker installed and running
    - **NVKind:** NVIDIA drivers + Docker GPU runtime (`nvidia-smi` must detect your GPU)
    - **Local (Lima/Minikube):** Lima v1.2.1+ or Minikube, minimum 8GB RAM / 4 CPUs
    - **Cloud K8s / OpenShift:** Existing cluster with kubectl/oc access configured

!!! tip "Not sure?"
    Start with **Lima**

## Deployment Options

## Local Deployment

For development and testing on your local machine:

| Deployment Type | Description | Guide |
|----------------|-------------|-------|
| **Local** | Lima VM + Kubernetes on your machine | [Deploy →](../deployment/detailed_deployment_local.md) |

## Cluster Deployment

For production deployments on Kubernetes clusters:

| Deployment Type | Description | Guide |
|----------------|-------------|-------|
| **OpenShift Cluster** | Red Hat OpenShift for enterprise | [Deploy →](../deployment/detailed_deployment_cluster.md) |
| **Kubernetes Cluster** | Standard K8s cluster (GKE, EKS, AKS) | [Deploy →](../deployment/detailed_deployment_k8s.md) |
| **Kind** | Kubernetes in Docker (local dev) | [Deploy →](../deployment/kind_cluster_deployment.md) |
| **NVKind** | Kind with NVIDIA GPU support | [Deploy →](../deployment/nvkind_cluster_deployment.md) |

---

!!! success "After deployment"
    Once deployment is complete, return to [First Steps](first-steps.md) to access your services, generate an API key, and run your first inference.