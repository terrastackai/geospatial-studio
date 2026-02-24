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

verify_lima_image() {
  local image=$1
  
  if ! command -v limactl &> /dev/null; then
    log_warning "limactl not found, skipping Lima image verification"
    return 0
  fi
  
  log_info "Verifying local image exists in Lima containerd..."
  if limactl shell studio sudo nerdctl image ls | grep -q "$image"; then
    log_success "Local image '$image' found in Lima"
    return 0
  else
    log_error "Local image '$image' not found in Lima"
    log_error "Please run: ./build-studio-operators.sh"
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
