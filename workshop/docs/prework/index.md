# Pre-work Overview

!!! warning "Complete Before Workshop"
    The pre-work must be completed **before** attending the workshop. Deployment can take 30-60 minutes depending on your environment and network speed.

## What You'll Do

In this pre-work section, you will:

1. ✅ Verify you have all prerequisites installed
2. ✅ **Clone the workshop repository** (includes all lab materials)
3. ✅ Choose a deployment option (local or cluster)
4. ✅ Deploy Geospatial Studio in your environment
5. ✅ Verify the deployment is working correctly

## Time Required

- **Prerequisites check:** 10 minutes
- **Local deployment:** 30-45 minutes
- **Cluster deployment:** 45-60 minutes
- **Verification:** 10 minutes

**Total:** 1-1.5 hours

## Deployment Options

You have two deployment options:

### Option 1: Local Deployment (Recommended for Workshop)

Deploy Geospatial Studio on your local machine using Lima VM (macOS/Linux).

**Pros:**
- No cloud resources required
- Good for learning and testing
- Easier to troubleshoot
- Simple, pre-configured setup

**Cons:**
- Limited performance (no GPU acceleration)
- Requires significant local resources
- Not suitable for production workloads
- **Fixed in-cluster services only** (PostgreSQL, MinIO, Keycloak)

**Service Configuration:**
- All services automatically deployed within Lima VM
- No option to use external cloud services
- Simplified setup for learning and testing

**Best for:** Workshop participants, developers, testing

[Local Deployment Guide →](local-deployment.md){ .md-button }

### Option 2: Cluster Deployment

Deploy on Red Hat OpenShift or Kubernetes cluster with GPU support.

**Pros:**
- Full performance with GPU acceleration
- Production-ready
- Scalable
- **Flexible service configuration** (in-cluster or external cloud services)

**Cons:**
- Requires cluster access
- More complex setup
- May incur cloud costs

**Service Configuration:**
- Choose between in-cluster services (PostgreSQL, MinIO, Keycloak)
- OR external cloud-managed services:
  - IBM Cloud Databases, AWS RDS, Azure PostgreSQL, GCP Cloud SQL
  - IBM COS, AWS S3, Azure Blob Storage, GCP Cloud Storage
  - IBM Security Verify, external Keycloak, Okta, Azure AD

**Best for:** Production deployments, GPU-intensive workloads, enterprise use

[Cluster Deployment Guide →](cluster-deployment.md){ .md-button }

## What Gets Deployed

The Geospatial Studio deployment includes:

| Component | Purpose | Configuration Options |
|-----------|---------|----------------------|
| **Studio Gateway API** | Main API for all backend services | Always deployed |
| **Studio UI** | Web-based user interface | Always deployed |
| **PostgreSQL** | Database for metadata storage | In-cluster (local) OR cloud-managed (cluster) |
| **MinIO** | S3-compatible object storage | In-cluster (local) OR external S3 (cluster) |
| **Keycloak** | OAuth2 authentication | In-cluster (local) OR external OAuth (cluster) |
| **MLflow** | Experiment tracking for model training | Always deployed |
| **GeoServer** | Geospatial data visualization | Always deployed |
| **Redis** | Caching and message queuing | Always deployed |

!!! info "Service Configuration Flexibility"
    **Local deployment** uses fixed in-cluster services with no configuration options.
    
    **Cluster deployment** offers flexible configuration - you can choose between in-cluster services or external cloud-managed services (IBM Cloud, AWS, Azure, GCP) for PostgreSQL, object storage, and authentication.

!!! info "Architecture Details"
    For a detailed architecture overview with diagrams and component descriptions, see the [Architecture Overview](../introduction/architecture.md) section.

## Next Steps

1. [Check Prerequisites →](prerequisites.md)
2. Choose your deployment option:
    - [Local Deployment →](local-deployment.md)
    - [Cluster Deployment →](cluster-deployment.md)
3. [Verify Installation →](verification.md)

## Need Help?

If you encounter issues during deployment:

- Check the [Troubleshooting Guide](../resources/troubleshooting.md)
- Review the [FAQ](../resources/faq.md)
- Consult the [official documentation](https://terrastackai.github.io/geospatial-studio/)

---

[Next: Prerequisites →](prerequisites.md){ .md-button .md-button--primary }