#!/bin/bash
# ==============================================================================
# GeoStudio Operator Installation Script
# ==============================================================================
# This script installs the GeoStudio operator in either local or production mode.
#
# Modes:
#   --local    : Use locally built image (Lima development)
#   --prod     : Use production image from quay.io
#   --version  : Specify version (default: latest for prod, local for local)
#
# Prerequisites:
#   - Kubernetes cluster accessible via kubectl
#   - make and kustomize installed
#   - For local mode: Lima with imported image via ./build-operator-lima.sh
#   - For prod mode: Access to quay.io/geospatial-studio
#
# Usage:
#   ./operators/install-geostudio.sh --local
#   ./operators/install-geostudio.sh --prod
#   ./operators/install-geostudio.sh --prod --version v0.0.1
#
# ==============================================================================

set -e

# ==============================================================================
# Color Output Functions
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# ==============================================================================
# Configuration
# ==============================================================================

DEPLOYMENT_MODE=""
OPERATOR_VERSION=""
NAMESPACE="geostudio-operators-system"
OPERATOR_IMAGE=""
IMAGE_PULL_POLICY="IfNotPresent"
APPLY_MANIFEST="true"

# ==============================================================================
# Parse Arguments
# ==============================================================================

show_help() {
  cat << EOF
GeoStudio Operator Installation Script

Usage: $0 [OPTIONS]

Options:
  --local              Install using local Lima image (for development)
  --prod               Install using production quay.io image
  --version VERSION    Specify operator version (default: latest for prod, local for local)
  --namespace NS       Kubernetes namespace for operator (default: geostudio-operators-system)
  --skip-manifest      Skip applying GeoStudio CR manifest
  -h, --help           Show this help message

Examples:
  # Local development
  $0 --local

  # Production with latest
  $0 --prod

  # Production with specific version
  $0 --prod --version v0.0.1

  # Local without applying manifest
  $0 --local --skip-manifest

EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --local)
      DEPLOYMENT_MODE="local"
      shift
      ;;
    --prod|--production)
      DEPLOYMENT_MODE="prod"
      shift
      ;;
    --version)
      OPERATOR_VERSION="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --skip-manifest)
      APPLY_MANIFEST="false"
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      ;;
  esac
done

# ==============================================================================
# Validate Configuration
# ==============================================================================

if [ -z "$DEPLOYMENT_MODE" ]; then
  log_error "Deployment mode not specified. Use --local or --prod"
  echo ""
  show_help
fi

# Set defaults based on mode
if [ "$DEPLOYMENT_MODE" = "local" ]; then
  OPERATOR_VERSION="${OPERATOR_VERSION:-local}"
  OPERATOR_IMAGE="geostudio-operator:${OPERATOR_VERSION}"
  IMAGE_PULL_POLICY="Never"
elif [ "$DEPLOYMENT_MODE" = "prod" ]; then
  OPERATOR_VERSION="${OPERATOR_VERSION:-latest}"
  OPERATOR_IMAGE="quay.io/geospatial-studio/geostudio-operator:${OPERATOR_VERSION}"
  IMAGE_PULL_POLICY="IfNotPresent"
fi

# ==============================================================================
# Display Configuration
# ==============================================================================

echo ""
echo "=========================================="
echo "GeoStudio Operator Installation"
echo "=========================================="
echo "Mode:               ${DEPLOYMENT_MODE}"
echo "Image:              ${OPERATOR_IMAGE}"
echo "ImagePullPolicy:    ${IMAGE_PULL_POLICY}"
echo "Namespace:          ${NAMESPACE}"
echo "Apply Manifest:     ${APPLY_MANIFEST}"
echo "=========================================="
echo ""

# ==============================================================================
# Prerequisites Check
# ==============================================================================

log_info "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
  log_error "kubectl is not installed"
  exit 1
fi

if ! command -v make &> /dev/null; then
  log_error "make is not installed"
  exit 1
fi

if ! command -v kustomize &> /dev/null; then
  log_error "kustomize is not installed"
  exit 1
fi

# Check for Lima in local mode
if [ "$DEPLOYMENT_MODE" = "local" ] && ! command -v limactl &> /dev/null; then
  log_error "limactl is not installed (required for local mode)"
  exit 1
fi

log_success "All prerequisites met"
echo ""

# ==============================================================================
# Kubernetes Cluster Check
# ==============================================================================

log_info "Checking Kubernetes cluster connection..."

if [ -z "$KUBECONFIG" ]; then
  log_warning "KUBECONFIG environment variable is not set"
  log_info "Using default kubeconfig from ~/.kube/config"
fi

if ! kubectl cluster-info &> /dev/null; then
  log_error "Cannot connect to Kubernetes cluster"
  log_error "Set KUBECONFIG or ensure cluster is accessible"
  exit 1
fi

log_success "Connected to cluster successfully"
echo ""

# ==============================================================================
# Local Mode: Verify Image Exists
# ==============================================================================

if [ "$DEPLOYMENT_MODE" = "local" ]; then
  log_info "Verifying local image exists in Lima containerd..."
  
  if ! limactl shell studio sudo ctr -n k8s.io images ls | grep -q "geostudio-operator.*${OPERATOR_VERSION}"; then
    log_error "Local image '${OPERATOR_IMAGE}' not found in Lima containerd!"
    echo ""
    log_error "Please build and import the image first by running:"
    log_error "  ./build-operator-lima.sh"
    echo ""
    exit 1
  fi
  
  log_success "Local image '${OPERATOR_IMAGE}' found in Lima"
  echo ""
fi

# ==============================================================================
# Install Operator
# ==============================================================================

log_info "Installing CRDs and Operator..."

# Change to operators directory
cd "$(dirname "$0")"

make install \
  NAMESPACE=${NAMESPACE} \
  IMG=${OPERATOR_IMAGE}

log_info "Waiting for operator deployment to be created..."
sleep 5

# ==============================================================================
# Configure Deployment for Local Mode
# ==============================================================================

if [ "$DEPLOYMENT_MODE" = "local" ]; then
  log_info "Configuring operator for local development..."
  
  # Set the image explicitly (in case kustomize didn't update it)
  kubectl set image deployment/operators-controller-manager \
    manager=${OPERATOR_IMAGE} \
    -n ${NAMESPACE}
  
  # Set imagePullPolicy to Never
  kubectl patch deployment operators-controller-manager \
    -n ${NAMESPACE} \
    --type json \
    -p '[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "Never"}]'
  
  # Remove imagePullSecrets if present (not needed for local images)
  kubectl patch deployment operators-controller-manager \
    -n ${NAMESPACE} \
    --type json \
    -p '[{"op": "remove", "path": "/spec/template/spec/imagePullSecrets"}]' 2>/dev/null || true
  
  log_success "Local configuration applied"
fi

# ==============================================================================
# Wait for Operator
# ==============================================================================

log_info "Waiting for operator to be ready..."

if kubectl wait --for=condition=available --timeout=120s \
  deployment/operators-controller-manager -n ${NAMESPACE}; then
  log_success "Operator is ready!"
else
  log_warning "Operator did not become ready within timeout. Checking status..."
  kubectl get pods -n ${NAMESPACE}
  echo ""
  log_info "To view operator logs, run:"
  echo "  kubectl logs -n ${NAMESPACE} deployment/operators-controller-manager --tail=50"
fi

echo ""
log_success "Operator installed and configured"
echo ""

# ==============================================================================
# Verify Configuration
# ==============================================================================

log_info "Verifying operator configuration..."
DEPLOYED_IMAGE=$(kubectl get deployment operators-controller-manager -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}')
PULL_POLICY=$(kubectl get deployment operators-controller-manager -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')

echo "  Image:           ${DEPLOYED_IMAGE}"
echo "  ImagePullPolicy: ${PULL_POLICY}"

if [ "$DEPLOYED_IMAGE" = "$OPERATOR_IMAGE" ]; then
  log_success "Configuration verified!"
else
  log_warning "Deployed image differs from expected:"
  log_warning "  Expected: ${OPERATOR_IMAGE}"
  log_warning "  Deployed: ${DEPLOYED_IMAGE}"
fi
echo ""

# ==============================================================================
# Apply GeoStudio Manifest
# ==============================================================================

if [ "$APPLY_MANIFEST" = "true" ]; then
  log_info "Applying GEOStudio manifest..."
  
  # Check if manifest file exists
  if [ -f "examples/my-geostudio-midpoint.yaml" ]; then
    kubectl apply -f examples/my-geostudio-midpoint.yaml
    log_success "GEOStudio manifest applied"
  else
    log_warning "Manifest file not found: examples/my-geostudio-midpoint.yaml"
    log_info "Skipping manifest application"
  fi
  
  echo ""
  
  # Show initial status
  log_info "Checking initial deployment status..."
  echo ""
  kubectl get geostudio studio -n default 2>/dev/null || log_info "GEOStudio resource not ready yet"
  echo ""
fi

# ==============================================================================
# Installation Complete
# ==============================================================================

log_success "Installation complete!"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "To monitor the deployment:"
echo "  kubectl get geostudio studio -n default -o yaml"
echo "  kubectl get pods -n default -w"
echo "  kubectl logs -n ${NAMESPACE} deployment/operators-controller-manager -f"
echo ""

if [ "$DEPLOYMENT_MODE" = "local" ]; then
  echo "To rebuild and update the operator image:"
  echo "  ./build-operator-lima.sh"
  echo "  kubectl rollout restart deployment/operators-controller-manager -n ${NAMESPACE}"
  echo ""
fi

echo "To uninstall:"
echo "  ./operators/uninstall-geostudio.sh"
echo ""
