#!/bin/bash
# ==============================================================================
# GeoStudio Local Install Script (for Lima development)
# ==============================================================================
# This script performs a clean installation of GeoStudio operator using a
# locally built image in Lima containerd.
#
# Prerequisites:
# - Lima instance running with Kubernetes (k3s)
# - Local operator image built and imported to Lima via build-operator-lima.sh
# - kubectl installed on host machine
# - make and kustomize installed on host machine
#
# Usage:
#   1. First build and import the local image:
#      ./build-operator-lima.sh
#   2. Then run this installation script:
#      ./operators/install-geostudio-local.sh
#
# ==============================================================================

set -e

# Colors
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

# Local image configuration
LOCAL_IMAGE_NAME="geostudio-operator"
LOCAL_IMAGE_TAG="local"
LOCAL_IMAGE="${LOCAL_IMAGE_NAME}:${LOCAL_IMAGE_TAG}"

echo ""
echo "=========================================="
echo "GeoStudio Local Installation"
echo "=========================================="
echo "This script will install the operator using:"
echo "  Image: ${LOCAL_IMAGE}"
echo "  ImagePullPolicy: Never"
echo "=========================================="
echo ""

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
  log_error "Please export your kubeconfig before running this script."
  log_error "Example: export KUBECONFIG=\"/Users/brianglar/.lima/studio/copied-from-guest/kubeconfig.yaml\""
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

# --- VERIFY LOCAL IMAGE EXISTS ---
log_info "Verifying local image exists in Lima containerd..."

if ! limactl shell studio sudo ctr -n k8s.io images ls | grep -q "${LOCAL_IMAGE_NAME}:${LOCAL_IMAGE_TAG}"; then
  log_error "Local image '${LOCAL_IMAGE}' not found in Lima containerd!"
  echo ""
  log_error "Please build and import the image first by running:"
  log_error "  ./build-operator-lima.sh"
  echo ""
  exit 1
fi

log_success "Local image '${LOCAL_IMAGE}' found in Lima"
echo ""

# Install CRD and Operator
log_info "Installing CRD and Operator..."
make install NAMESPACE=geostudio-operators-system IMG=${LOCAL_IMAGE}

log_info "Waiting for operator deployment to be created..."
sleep 5

# Update the deployment to use local image with Never pull policy
log_info "Configuring operator to use local image..."

# Set the image
kubectl set image deployment/operators-controller-manager \
  manager=${LOCAL_IMAGE} \
  -n geostudio-operators-system

# Set imagePullPolicy to Never
kubectl patch deployment operators-controller-manager \
  -n geostudio-operators-system \
  --type json \
  -p '[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "Never"}]'

# Remove imagePullSecrets if present (not needed for local images)
log_info "Removing imagePullSecrets (not needed for local images)..."
kubectl patch deployment operators-controller-manager \
  -n geostudio-operators-system \
  --type json \
  -p '[{"op": "remove", "path": "/spec/template/spec/imagePullSecrets"}]' 2>/dev/null || true

log_info "Waiting for operator to be ready..."
if kubectl wait --for=condition=available --timeout=120s \
  deployment/operators-controller-manager -n geostudio-operators-system; then
  log_success "Operator is ready!"
else
  log_warning "Operator did not become ready within timeout. Checking status..."
  kubectl get pods -n geostudio-operators-system
  echo ""
  log_info "To view operator logs, run:"
  echo "  kubectl logs -n geostudio-operators-system deployment/operators-controller-manager --tail=50"
fi

echo ""
log_success "Operator installed and configured for local development"
echo ""

# Verify configuration
log_info "Verifying operator configuration..."
DEPLOYED_IMAGE=$(kubectl get deployment operators-controller-manager -n geostudio-operators-system -o jsonpath='{.spec.template.spec.containers[0].image}')
PULL_POLICY=$(kubectl get deployment operators-controller-manager -n geostudio-operators-system -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')

echo "  Image: ${DEPLOYED_IMAGE}"
echo "  ImagePullPolicy: ${PULL_POLICY}"

if [ "$DEPLOYED_IMAGE" = "$LOCAL_IMAGE" ] && [ "$PULL_POLICY" = "Never" ]; then
  log_success "Configuration verified!"
else
  log_warning "Configuration may not be correct. Please check manually."
fi
echo ""

# Apply GEOStudio manifest
log_info "Applying GEOStudio manifest..."
kubectl apply -f my-geostudio-midpoint.yaml

log_success "GEOStudio manifest applied"
echo ""

# Show status
log_info "Deployment initiated. Checking initial status..."
echo ""
kubectl get geostudio studio -n default 2>/dev/null || log_info "GEOStudio resource not ready yet"
echo ""

log_success "Installation complete!"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "To monitor the deployment:"
echo "  kubectl get geostudio studio -n default -o yaml"
echo "  kubectl get pods -n default"
echo "  kubectl logs -n geostudio-operators-system deployment/operators-controller-manager -f"
echo ""
echo "To rebuild and update the operator image:"
echo "  ./build-operator-lima.sh"
echo "  kubectl rollout restart deployment/operators-controller-manager -n geostudio-operators-system"
echo ""
echo "To uninstall:"
echo "  ./operators/uninstall-geostudio.sh"
echo ""
