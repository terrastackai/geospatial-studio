# GEOStudio Operator

A Kubernetes operator for deploying and managing GEOStudio using the Operator SDK with Helm.

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Fast-track deployment guide with minimal steps
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Comprehensive deployment guide with production considerations

Choose the guide that fits your needs:
- Use **QUICKSTART** if you want to get up and running quickly
- Use **DEPLOYMENT** for production deployments with detailed explanations

## What is GEOStudio?

GEOStudio is a comprehensive geospatial data platform that provides:
- Machine learning model inference and fine-tuning
- Geospatial data processing pipelines
- Data visualization and management
- Integration with object storage and databases

## Operator Features

- **Declarative Deployment**: Define your GEOStudio configuration as a Kubernetes custom resource
- **Automated Lifecycle Management**: The operator handles installation, upgrades, and configuration changes
- **Namespace Isolation**: Deploy operator and applications in separate namespaces
- **Flexible Configuration**: Customize all aspects of the deployment via environment variables
- **Production Ready**: Supports high availability, monitoring, and security best practices

## Architecture

The operator manages a Helm chart that deploys multiple components:
- **Gateway API**: Backend services for geospatial operations
- **UI**: Web interface for user interaction
- **MLflow**: Machine learning experiment tracking
- **Redis**: Caching and message queue
- **Pipelines**: Data processing workflows

Infrastructure components (deployed separately):
- **PostgreSQL**: Database for application data
- **MinIO**: S3-compatible object storage
- **Keycloak**: Authentication and authorization
- **GeoServer**: Geospatial data serving

## Quick Start

For the fastest deployment experience:

```bash
# Clone the repository
git clone https://github.com/IBM/geospatial-studio.git
cd geospatial-studio

# Follow the QUICKSTART guide
cat operators/QUICKSTART.md
```

Or jump directly to specific sections:
- [Build and push Helm chart](QUICKSTART.md#2-build-and-push-helm-chart)
- [Deploy infrastructure](QUICKSTART.md#3-deploy-infrastructure)
- [Install operator](QUICKSTART.md#5-install-operator)
- [Deploy application](QUICKSTART.md#6-deploy-geostudio-application)

## Support

- **Issues**: https://github.com/IBM/geospatial-studio/issues
- **Discussions**: https://github.com/IBM/geospatial-studio/discussions

## License

Copyright IBM Corporation 2025  
SPDX-License-Identifier: Apache-2.0
