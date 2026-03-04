#!/bin/bash
# ==============================================================================
# GeoStudio Kubernetes Utilities
# ==============================================================================
# Kubernetes-specific helper functions
#
# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# Source common library if not already loaded
if [ -z "$GREEN" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# ==============================================================================
# Configuration
# ==============================================================================

OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-geostudio-operators-system}"
OPERATOR_READY_TIMEOUT="${OPERATOR_READY_TIMEOUT:-120}"
RESOURCE_DELETE_TIMEOUT="${RESOURCE_DELETE_TIMEOUT:-60}"
POD_READY_TIMEOUT="${POD_READY_TIMEOUT:-600}"

# ==============================================================================
# Cluster Detection
# ==============================================================================

detect_cluster_type() {
  # Check current kubectl context for kind
  local current_context=$(kubectl config current-context 2>/dev/null || echo "")
  if [[ "$current_context" == kind-* ]]; then
    echo "kind"
    return 0
  fi
  
  # Check for kind cluster via cluster-info
  if kubectl cluster-info 2>/dev/null | grep -q "kind"; then
    echo "kind"
    return 0
  fi
  
  # Check for OpenShift (look for OpenShift API server or oc command)
  if kubectl get clusterversion 2>/dev/null | grep -q "OpenShift" || \
     kubectl api-resources 2>/dev/null | grep -q "route.openshift.io"; then
    echo "openshift"
    return 0
  fi
  
  # Check if nodes have lima labels (for Lima/k3s)
  if kubectl get nodes -o json 2>/dev/null | grep -q "lima"; then
    echo "lima"
    return 0
  fi
  
  # Check if limactl is available and lima VM 'studio' is running
  if command -v limactl &> /dev/null && limactl list 2>/dev/null | grep -q "studio.*Running"; then
    echo "lima"
    return 0
  fi
  
  # Check for nvkind (NVIDIA GPU-enabled kind)
  # nvkind typically has nvidia.com resources or GPU-related labels
  if kubectl get nodes -o json 2>/dev/null | grep -q "nvidia.com/gpu"; then
    # If it has kind in context but also has NVIDIA GPUs, it's nvkind
    if [[ "$current_context" == *kind* ]] || kubectl cluster-info 2>/dev/null | grep -q "kind"; then
      echo "nvkind"
      return 0
    fi
  fi
  
  # Default to k8s for any other cluster
  echo "k8s"
  return 0
}

get_cluster_type() {
  local cluster_type=${CLUSTER_TYPE:-$(detect_cluster_type)}
  echo "$cluster_type"
}

get_csi_driver_type() {
  # Only IBM Object CSI driver is supported
  echo "ibm-object-csi"
}

# ==============================================================================
# Operator Checks
# ==============================================================================

operator_is_installed() {
  kubectl get crd geostudios.geostudio.geostudio.ibm.com &> /dev/null
  return $?
}

operator_is_running() {
  local namespace=${1:-$OPERATOR_NAMESPACE}
  
  if ! kubectl get deployment operators-controller-manager -n "$namespace" &> /dev/null; then
    return 1
  fi
  
  local ready=$(kubectl get deployment operators-controller-manager -n "$namespace" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  
  [ "$ready" != "0" ]
  return $?
}

wait_for_operator_ready() {
  local namespace=${1:-$OPERATOR_NAMESPACE}
  local timeout=${2:-$OPERATOR_READY_TIMEOUT}
  
  log_info "Waiting for operator to be ready (timeout: ${timeout}s)..."
  
  kubectl wait --for=condition=available deployment/operators-controller-manager \
    -n "$namespace" \
    --timeout="${timeout}s" 2>/dev/null
  
  return $?
}

# ==============================================================================
# Resource Management
# ==============================================================================

get_geostudio_instances() {
  local namespace=${1:-""}
  local ns_flag=""
  [[ -n "$namespace" ]] && ns_flag="-n $namespace" || ns_flag="--all-namespaces"
  
  kubectl get geostudios $ns_flag -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>/dev/null
}

delete_geostudio_instance() {
  local name=$1
  local namespace=$2
  
  log_info "Deleting GeoStudio instance '$name' in namespace '$namespace'..."
  kubectl delete geostudio "$name" -n "$namespace" --timeout=30s 2>/dev/null || true
}

# ==============================================================================
# Image Verification
# ==============================================================================

verify_local_image() {
  local image=$1
  local cluster_type=$(get_cluster_type)
  
  case "$cluster_type" in
    lima)
      verify_lima_image "$image"
      ;;
    kind)
      verify_kind_image "$image"
      ;;
    k8s)
      # For k8s, we assume images are pulled from registry or locally available
      log_info "Skipping image verification for k8s cluster (assuming registry or local availability)"
      return 0
      ;;
    *)
      log_warning "Unknown cluster type: $cluster_type, skipping image verification"
      return 0
      ;;
  esac
}

verify_lima_image() {
  local image=$1
  
  if ! command -v limactl &> /dev/null; then
    log_warning "limactl not found, skipping Lima image verification"
    return 0
  fi
  
  log_info "Verifying local image exists in Lima containerd..."
  
  # Extract image name and tag
  local image_name=$(echo "$image" | cut -d':' -f1)
  local image_tag=$(echo "$image" | cut -d':' -f2)
  
  # Check for the image in Lima containerd
  # The image might be stored with different prefixes (docker.io/library/, etc.)
  if limactl shell studio sudo ctr -n k8s.io images ls | grep -E "(^|/)${image_name}:${image_tag}\s"; then
    log_success "Local image '$image' found in Lima"
    return 0
  else
    log_error "Local image '$image' not found in Lima"
    log_error "Please run: ./geostudio build --local"
    return 1
  fi
}

verify_kind_image() {
  local image=$1
  local kind_cluster_name=${KIND_CLUSTER_NAME:-kind}
  
  if ! command -v kind &> /dev/null; then
    log_warning "kind not found, skipping image verification"
    return 0
  fi
  
  log_info "Verifying local image exists in kind cluster..."
  
  # Get the actual cluster name from kubectl context if not set
  if [ -z "${KIND_CLUSTER_NAME:-}" ]; then
    local current_context=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ "$current_context" == kind-* ]]; then
      kind_cluster_name="${current_context#kind-}"
    else
      # Try to get first available cluster
      local first_cluster=$(kind get clusters 2>/dev/null | head -1)
      if [ -n "$first_cluster" ]; then
        kind_cluster_name="$first_cluster"
      fi
    fi
  fi
  
  # Determine container runtime (docker or podman)
  local container_runtime="docker"
  if command -v podman &> /dev/null && [ -n "${KIND_EXPERIMENTAL_PROVIDER:-}" ]; then
    container_runtime="podman"
  fi
  
  # Extract image name and tag
  local image_name=$(echo "$image" | cut -d':' -f1)
  local image_tag=$(echo "$image" | cut -d':' -f2)
  
  # Check for the image in kind cluster
  if ${container_runtime} exec "${kind_cluster_name}-control-plane" crictl images 2>/dev/null | grep -E "${image_name}\s+${image_tag}"; then
    log_success "Local image '$image' found in kind"
    return 0
  else
    log_error "Local image '$image' not found in kind"
    log_error "Please run: ./geostudio build --local"
    return 1
  fi
}

# ==============================================================================
# CSI Driver Cleanup
# ==============================================================================

cleanup_csi_driver() {
  local skip_csi=${1:-false}
  
  if [ "$skip_csi" = true ]; then
    log_info "Skipping CSI driver cleanup (--skip-csi-cleanup flag)"
    return 0
  fi
  
  log_step "Cleaning up IBM Object S3 CSI Driver"
  
  # Check if CSI driver is installed
  if ! kubectl get deployment cos-s3-csi-controller -n kube-system &> /dev/null; then
    log_info "CSI driver not installed, skipping cleanup"
    echo ""
    return 0
  fi
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would clean up CSI driver components"
    return 0
  fi
  
  # Delete deployments and daemonsets
  log_info "Deleting CSI controller and driver..."
  kubectl delete deployment cos-s3-csi-controller -n kube-system --timeout=30s 2>/dev/null || true
  kubectl delete daemonset cos-s3-csi-driver -n kube-system --timeout=30s 2>/dev/null || true
  
  # Delete service accounts
  log_info "Deleting CSI service accounts..."
  kubectl delete serviceaccount cos-s3-csi-controller cos-s3-csi-driver -n kube-system 2>/dev/null || true
  
  # Delete cluster roles and bindings
  log_info "Deleting CSI cluster roles..."
  kubectl delete clusterrole cos-s3-csi-controller-role cos-s3-csi-driver-role 2>/dev/null || true
  kubectl delete clusterrolebinding cos-s3-csi-controller-rolebind cos-s3-csi-driver-rolebind 2>/dev/null || true
  
  # Delete CSI driver
  log_info "Deleting CSI driver..."
  kubectl delete csidriver cos.s3.csi.ibm.io 2>/dev/null || true
  
  # Delete storage classes
  log_info "Deleting storage classes..."
  kubectl delete storageclass cos-s3-csi-sc cos-s3-csi-s3fs-sc 2>/dev/null || true
  
  # Delete MinIO CA cert
  log_info "Deleting MinIO CA certificate..."
  kubectl delete configmap minio-ca-cert -n kube-system 2>/dev/null || true
  
  echo ""
  log_success "CSI driver cleanup complete"
}
