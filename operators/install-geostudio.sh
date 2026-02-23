#!/bin/bash
# ==============================================================================
# GeoStudio Quick Install Script
# ==============================================================================
# This script performs a clean installation of GeoStudio operator and manifests
#
# Prerequisites:
# - Lima instance running with Kubernetes (k3s)
# - kubectl installed on host machine
# - make and kustomize installed on host machine
#
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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

# Check prerequisites
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

if ! command -v limactl &> /dev/null; then
  log_error "limactl is not installed"
  exit 1
fi

log_success "All prerequisites met"
echo ""

# Setup kubeconfig
log_info "Setting up kubeconfig for Lima cluster..."

# --- PRE-FLIGHT CHECK ---
# Ensure the user has provided the KUBECONFIG environment variable
if [ -z "$KUBECONFIG" ]; then
  log_error "Error: KUBECONFIG environment variable is not set."
  log_error "Please export you kubeconfig before running this script."
  exit 1
fi

# --- CONNECTION TEST ---
if ! kubectl cluster-info &> /dev/null; then
  log_error "Error: Cannot connect to Kubernetes cluster using KUBECONFIG=$KUBECONFIG"
  exit 1
fi

echo "✓ Connected to cluster successfully."

log_success "Connected to Lima Kubernetes cluster"
echo ""

# Install CRD and Operator
log_info "Installing CRD and Operator..."
# make install
make install NAMESPACE=geostudio-operators-system IMG=quay.io/geospatial-studio/geostudio-operator

log_info "Waiting for operator deployment to be created..."
sleep 5

# Check if operator needs image update
OPERATOR_IMAGE=$(kubectl get deployment operators-controller-manager -n geostudio-operators-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")

if [ "$OPERATOR_IMAGE" = "controller:latest" ]; then
  log_info "Updating operator image to use pre-built version..."
  kubectl set image deployment/operators-controller-manager \
    manager=quay.io/geospatial-studio/geostudio-operator:latest \
    -n geostudio-operators-system
  
  log_info "Waiting for operator to be ready..."
  kubectl wait --for=condition=available --timeout=120s \
    deployment/operators-controller-manager -n geostudio-operators-system
fi

log_success "Operator installed and running"
echo ""

# Apply GEOStudio manifest
log_info "Applying GEOStudio manifest..."
kubectl apply -f examples/my-geostudio-midpoint.yaml

log_success "GEOStudio manifest applied"
echo ""

# Show status
log_info "Deployment initiated. Checking initial status..."
echo ""
kubectl get geostudio studio -n default
echo ""

log_success "Installation complete!"
echo ""
echo "To monitor the deployment:"
echo "  kubectl get geostudio studio -n default -o yaml"
echo "  kubectl get pods -n default"
echo "  kubectl logs -n geostudio-operators-system deployment/operators-controller-manager --tail=50"
echo ""
echo "To uninstall:"
echo "  ./uninstall-geostudio.sh"
echo ""
