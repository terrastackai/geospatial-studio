# Installation

Choose your deployment path based on your environment and requirements.

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

**Next:** After deployment, see [First Steps](first-steps.md) to get started.