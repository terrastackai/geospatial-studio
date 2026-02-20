# Deployment Overview

## Introduction

The Geospatial Studio is designed to be flexible and can be deployed in various environments, from local development machines to production Kubernetes clusters. This guide helps you understand the different deployment options and choose the right one for your needs.

## Deployment Architecture

All deployment methods follow a similar architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    Geospatial Studio                     │
├─────────────────────────────────────────────────────────┤
│  Frontend (UI)  │  API Gateway  │  Backend Services     │
├─────────────────────────────────────────────────────────┤
│  Authentication (Keycloak)  │  Storage (MinIO)          │
├─────────────────────────────────────────────────────────┤
│  Database (PostgreSQL)  │  ML Tracking (MLflow)         │
├─────────────────────────────────────────────────────────┤
│  Map Server (GeoServer)  │  Job Queue (Huey)            │
└─────────────────────────────────────────────────────────┘
```

## Deployment Options Comparison

### Local Deployment
**Use Case:** Development, testing, demos, learning

- ✅ Quick setup (30 minutes)
- ✅ No cloud costs
- ✅ Full feature access
- ⚠️ Limited resources
- ⚠️ Not production-ready
- ❌ Limited GPU support (Mac)

**Best for:** Developers getting started, testing features, local development

[→ Local Deployment Guide](detailed_deployment_local.md)

---

### Kubernetes Deployment
**Use Case:** Production workloads, cloud deployments

- ✅ Highly scalable
- ✅ Cloud-native
- ✅ Production-ready
- ✅ Multi-node support
- ⚠️ Requires K8s expertise
- ⚠️ Cloud costs apply

**Best for:** Production deployments, cloud environments (GKE, EKS, AKS)

[→ Kubernetes Deployment Guide](detailed_deployment_k8s.md)

---

### OpenShift Deployment
**Use Case:** Enterprise production environments

- ✅ Enterprise support
- ✅ Enhanced security
- ✅ Integrated CI/CD
- ✅ Multi-tenancy
- ⚠️ Requires license
- ⚠️ More complex setup

**Best for:** Enterprise organizations using Red Hat OpenShift

[→ OpenShift Deployment Guide](detailed_deployment_cluster.md)

---

### Kind Cluster
**Use Case:** Local Kubernetes development

- ✅ Very fast setup (15 minutes)
- ✅ True Kubernetes environment
- ✅ Minimal resources
- ✅ Great for CI/CD testing
- ❌ No GPU support
- ❌ Local only

**Best for:** Kubernetes developers, CI/CD pipelines, quick testing

[→ Kind Cluster Guide](kind_cluster_deployment.md)

---

### NVKind Cluster
**Use Case:** Local GPU-accelerated development

- ✅ GPU support locally
- ✅ Realistic training environment
- ✅ NVIDIA GPU acceleration
- ⚠️ Requires NVIDIA GPU
- ⚠️ More complex setup
- ❌ Local only

**Best for:** ML developers needing local GPU access

[→ NVKind Cluster Guide](nvkind_cluster_deployment.md)

---

## Decision Matrix

Use this matrix to choose your deployment method:

| Your Situation | Recommended Deployment |
|----------------|------------------------|
| Just getting started | [Local](detailed_deployment_local.md) or [Kind](kind_cluster_deployment.md) |
| Need GPU for training locally | [NVKind](nvkind_cluster_deployment.md) |
| Testing Kubernetes configs | [Kind](kind_cluster_deployment.md) |
| Production on cloud | [Kubernetes](detailed_deployment_k8s.md) |
| Enterprise with OpenShift | [OpenShift](detailed_deployment_cluster.md) |
| Development team | [Local](detailed_deployment_local.md) + [Kubernetes](detailed_deployment_k8s.md) |

## Resource Requirements

### Minimum Requirements (All Deployments)
- **CPU:** 4 cores
- **RAM:** 8GB
- **Storage:** 50GB
- **Network:** Internet access for pulling images

### Recommended for Production
- **CPU:** 16+ cores
- **RAM:** 32GB+
- **Storage:** 200GB+ SSD
- **GPU:** NVIDIA GPU with 16GB+ VRAM (for training)
- **Network:** High bandwidth, low latency

### GPU Requirements (for Training)
- **NVIDIA GPU:** Compute Capability 7.0+ (V100, T4, A100, etc.)
- **VRAM:** 8GB minimum, 16GB+ recommended
- **Driver:** NVIDIA Driver 470+
- **CUDA:** 11.8+

## Common Components

All deployments include:

1. **Frontend UI** - React-based web interface
2. **API Gateway** - FastAPI backend services
3. **Authentication** - Keycloak for user management
4. **Storage** - MinIO for object storage
5. **Database** - PostgreSQL for metadata
6. **ML Tracking** - MLflow for experiment tracking
7. **Map Server** - GeoServer for visualization
8. **Job Queue** - Huey for async task processing

## Network Ports

Default ports used across deployments:

| Service | Port | Purpose |
|---------|------|---------|
| Studio UI | 4180 | Web interface |
| Studio API | 4181 | REST API |
| GeoServer | 3000 | Map server |
| MLflow | 5000 | ML tracking |
| Keycloak | 8080 | Authentication |
| MinIO Console | 9001 | Storage UI |
| MinIO API | 9000 | Storage API |
| PostgreSQL | 5432 | Database |

## Security Considerations

### Development Deployments
- Use default credentials (provided in guides)
- HTTP acceptable for local access
- No external access required

### Production Deployments
- **Change all default passwords**
- Use HTTPS/TLS for all services
- Implement network policies
- Enable authentication on all endpoints
- Regular security updates
- Backup strategies

## Next Steps

1. **Choose your deployment method** from the options above
2. **Review the specific guide** for detailed instructions
3. **Prepare your environment** with required tools
4. **Follow the deployment steps** in the guide
5. **Complete first steps** after deployment

## Support

- **Documentation:** Browse other sections for detailed guides
- **Issues:** [GitHub Issues](https://github.com/terrastackai/geospatial-studio/issues)
- **Community:** Join discussions on GitHub

## Related Documentation

- [Architecture Details](../reference/architecture_and_requirements.md)
- [Getting Started Overview](../getting-started/overview.md)
- [First Steps After Deployment](../getting-started/first-steps.md)