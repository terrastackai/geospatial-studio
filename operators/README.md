# GeoStudio Operator

This directory contains the GeoStudio Kubernetes Operator implementation.

## Documentation

📚 **[Complete Operator Documentation](./operator.md)**

The main documentation covers:
- Overview and architecture
- Quick start for local development
- Production deployment
- Configuration and customization
- Troubleshooting guide

## Quick Links

- **Build local image**: `../build-operator-lima.sh`
- **Install (local)**: `./install-geostudio.sh --local`
- **Install (production)**: `./install-geostudio.sh --prod`
- **Show help**: `./install-geostudio.sh --help`
- **Uninstall**: `./uninstall-geostudio.sh`

## Directory Structure

```
operators/
├── GEOSTUDIO_OPERATORS.md          # Main documentation
├── config/                          # Operator configuration
│   ├── crd/                         # Custom Resource Definitions
│   ├── rbac/                        # RBAC roles and bindings
│   ├── manager/                     # Operator deployment manifests
│   └── default/                     # Kustomize overlay
├── examples/                        # Example GeoStudio CRs
│   ├── my-geostudio.yaml
│   └── my-geostudio-midpoint.yaml
├── watches.yaml                     # Operator watch configuration
├── Makefile                         # Build and deploy targets
├── install-geostudio.sh             # Production installation script
└── uninstall-geostudio.sh          # Cleanup script
```

## Prerequisites

- Kubernetes cluster (Lima for local, any K8s for production)
- kubectl
- make
- kustomize

## Get Started

1. Read the [complete documentation](./operator.md)
2. Follow the Quick Start guide for your environment
3. Deploy GeoStudio with a single command!
