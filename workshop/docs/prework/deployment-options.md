# Deployment Options

Choose the deployment option that best fits your needs.

## Overview

Geospatial Studio can be deployed in two main ways:

1. **Local Deployment** - On your laptop/workstation
2. **Cluster Deployment** - On OpenShift or Kubernetes

## Service Configuration Options

### Local Deployment
Local deployment uses **fixed in-cluster services** with no configuration options:

- **PostgreSQL**: Automatically deployed in-cluster
- **Object Storage**: MinIO deployed in-cluster
- **Authentication**: Keycloak deployed in-cluster
- **Configuration**: Pre-configured, no external service options

This simplified setup is ideal for learning, testing, and development.

### Cluster Deployment
Cluster deployment offers **flexible service configuration**:

#### Database Options
- **In-cluster PostgreSQL**: CloudNative PostgreSQL or Bitnami Helm charts
- **External Cloud Databases**:
  - IBM Cloud Databases for PostgreSQL
  - AWS RDS for PostgreSQL
  - Azure Database for PostgreSQL
  - Google Cloud SQL for PostgreSQL

#### Object Storage Options
- **In-cluster MinIO**: S3-compatible storage within the cluster
- **External Cloud Storage**:
  - IBM Cloud Object Storage (COS)
  - AWS S3
  - Azure Blob Storage (via S3 gateway)
  - Google Cloud Storage (via S3 gateway)
  - Any S3-compatible storage service

#### Authentication Options
- **In-cluster Keycloak**: OAuth2 provider deployed in the cluster
- **External OAuth Providers**:
  - IBM Security Verify (ISV)
  - External Keycloak instance
  - Azure Active Directory
  - Okta
  - Other OAuth2/OpenID Connect providers

This flexibility allows you to use enterprise-grade cloud services for production deployments while maintaining the option for self-contained deployments.

## Comparison

| Feature | Local Deployment | Cluster Deployment |
|---------|-----------------|-------------------|
| **Setup Time** | 30-45 minutes | 45-60 minutes |
| **Hardware Required** | 16GB RAM, 8 cores | Cluster access |
| **GPU Support** | No (CPU only) | Yes (with GPU nodes) |
| **Cost** | Free | May incur cloud costs |
| **Performance** | Limited | Full performance |
| **Service Configuration** | Fixed (in-cluster only) | Flexible (in-cluster or external) |
| **Database Options** | In-cluster PostgreSQL only | In-cluster or cloud-managed |
| **Storage Options** | In-cluster MinIO only | MinIO or cloud object storage |
| **Auth Options** | In-cluster Keycloak only | Keycloak or external OAuth |
| **Best For** | Learning, testing | Production, GPU workloads |

## Choose Your Path

### Local Deployment
[Continue to Local Deployment →](local-deployment.md){ .md-button .md-button--primary }

### Cluster Deployment
[Continue to Cluster Deployment →](cluster-deployment.md){ .md-button .md-button--primary }