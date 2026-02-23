#!/bin/bash
# ==============================================================================
# GeoStudio Complete Uninstall Script
# ==============================================================================
# This script removes all GeoStudio components including:
# - GEOStudio custom resources
# - Infrastructure components (PostgreSQL, MinIO, Keycloak, GeoServer)
# - Application components (MLflow, Gateway, UI, Pipelines)
# - CSI Driver (controller, daemonset, storage classes, CSIDriver resource)
# - Jobs and hooks
# - ConfigMaps and Secrets (in all namespaces)
# - PersistentVolumeClaims
# - Cluster-wide resources (ClusterRoles, ClusterRoleBindings, StorageClasses)
# - Operator and CRDs
#
# NOTE: Container images are NOT deleted to speed up future deployments
#
# Usage:
#   ./uninstall-geostudio.sh [--namespace NAMESPACE] [--keep-pvcs] [--keep-operator]
#
# Options:
#   --namespace NAMESPACE  Namespace where GEOStudio is deployed (default: default)
#   --keep-pvcs           Don't delete PersistentVolumeClaims (keeps data)
#   --keep-operator       Don't uninstall the operator
#   --dry-run            Show what would be deleted without actually deleting
#   -h, --help           Show this help message
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="default"
KEEP_PVCS=false
KEEP_OPERATOR=false
DRY_RUN=false
OPERATOR_NAMESPACE="geostudio-operators-system"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --keep-pvcs)
      KEEP_PVCS=true
      shift
      ;;
    --keep-operator)
      KEEP_OPERATOR=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      head -30 "$0" | grep "^#" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Helper functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
  if [ "$DRY_RUN" = true ]; then
    return 0
  fi
  read -p "$1 (y/N): " response
  case "$response" in
    [yY][eE][sS]|[yY]) 
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

execute() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
  else
    eval "$@"
  fi
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  log_error "kubectl is not installed or not in PATH"
  exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
  log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
  exit 1
fi

echo "================================================================================"
echo "                    GeoStudio Complete Uninstall Script"
echo "================================================================================"
echo ""
echo "This will remove:"
echo "  - GEOStudio custom resources in namespace: $NAMESPACE"
echo "  - Infrastructure: PostgreSQL, MinIO, Keycloak, GeoServer"
echo "  - Applications: MLflow, Gateway, UI, Pipelines"
echo "  - CSI Driver: Controller, DaemonSet, StorageClasses, CSIDriver resource"
echo "  - Jobs, ConfigMaps, Secrets (in namespace: $NAMESPACE and kube-system)"
echo "  - Cluster-wide resources: ClusterRoles, ClusterRoleBindings"
if [ "$KEEP_PVCS" = false ]; then
  echo "  - PersistentVolumeClaims (WARNING: This will DELETE all data!)"
else
  echo "  - PersistentVolumeClaims will be PRESERVED"
fi
if [ "$KEEP_OPERATOR" = false ]; then
  echo "  - Operator and CRDs in namespace: $OPERATOR_NAMESPACE"
else
  echo "  - Operator will be PRESERVED"
fi
echo ""
echo "NOTE: Container images will NOT be deleted (kept for faster redeployment)"
echo ""
echo "================================================================================"
echo ""

if ! confirm "Do you want to proceed?"; then
  log_warning "Uninstall cancelled by user"
  exit 0
fi

echo ""

# ==============================================================================
# Step 1: Delete GEOStudio Custom Resources
# ==============================================================================
log_info "Step 1/10: Deleting GEOStudio custom resources..."

GEOSTUDIOS=$(kubectl get geostudios -n "$NAMESPACE" -o name 2>/dev/null || echo "")
if [ -n "$GEOSTUDIOS" ]; then
  for resource in $GEOSTUDIOS; do
    log_info "Deleting $resource..."
    execute kubectl delete "$resource" -n "$NAMESPACE" --wait=false
  done
  log_info "Waiting for GEOStudio resources to be finalized (max 60s)..."
  execute kubectl wait --for=delete geostudios --all -n "$NAMESPACE" --timeout=60s 2>/dev/null || log_warning "Some resources may still be finalizing"
  log_success "GEOStudio custom resources deleted"
else
  log_info "No GEOStudio custom resources found"
fi

echo ""

# ==============================================================================
# Step 2: Delete Application Components
# ==============================================================================
log_info "Step 2/10: Deleting application components..."

APP_COMPONENTS=(
  "deployment.apps/geofm-gateway"
  "deployment.apps/geofm-mlflow"
  "deployment.apps/geofm-geoserver"
  "deployment.apps/keycloak"
  "deployment.apps/minio"
  "statefulset.apps/postgresql"
  "statefulset.apps/geostudio-redis-master"
  "statefulset.apps/geostudio-redis-replicas"
)

for component in "${APP_COMPONENTS[@]}"; do
  if kubectl get "$component" -n "$NAMESPACE" &> /dev/null; then
    log_info "Deleting $component..."
    execute kubectl delete "$component" -n "$NAMESPACE" --wait=false
  fi
done

log_success "Application components deleted"
echo ""

# ==============================================================================
# Step 3: Delete Jobs (including hook jobs)
# ==============================================================================
log_info "Step 3/10: Deleting jobs..."

JOBS=$(kubectl get jobs -n "$NAMESPACE" -o name 2>/dev/null || echo "")
if [ -n "$JOBS" ]; then
  for job in $JOBS; do
    log_info "Deleting $job..."
    execute kubectl delete "$job" -n "$NAMESPACE" --wait=false
  done
  log_success "Jobs deleted"
else
  log_info "No jobs found"
fi

echo ""

# ==============================================================================
# Step 4: Delete Services
# ==============================================================================
log_info "Step 4/10: Deleting services..."

SERVICES=$(kubectl get svc -n "$NAMESPACE" -o name 2>/dev/null | grep -v "service/kubernetes" || echo "")
if [ -n "$SERVICES" ]; then
  for svc in $SERVICES; do
    log_info "Deleting $svc..."
    execute kubectl delete "$svc" -n "$NAMESPACE" --wait=false
  done
  log_success "Services deleted"
else
  log_info "No services found (except kubernetes service)"
fi

echo ""

# ==============================================================================
# Step 5: Delete ConfigMaps and Secrets
# ==============================================================================
log_info "Step 5/10: Deleting ConfigMaps and Secrets..."

# Delete ConfigMaps (except system ones)
CONFIGMAPS=$(kubectl get configmaps -n "$NAMESPACE" -o name 2>/dev/null | grep -v "kube-root-ca.crt" || echo "")
if [ -n "$CONFIGMAPS" ]; then
  for cm in $CONFIGMAPS; do
    log_info "Deleting $cm..."
    execute kubectl delete "$cm" -n "$NAMESPACE" --wait=false
  done
fi

# Delete Secrets (except default service account token)
SECRETS=$(kubectl get secrets -n "$NAMESPACE" -o name 2>/dev/null | grep -v "default-token" || echo "")
if [ -n "$SECRETS" ]; then
  for secret in $SECRETS; do
    log_info "Deleting $secret..."
    execute kubectl delete "$secret" -n "$NAMESPACE" --wait=false
  done
fi

log_success "ConfigMaps and Secrets deleted"
echo ""

# ==============================================================================
# Step 6: Delete PersistentVolumeClaims and PersistentVolumes
# ==============================================================================
if [ "$KEEP_PVCS" = false ]; then
  log_info "Step 6/10: Deleting PersistentVolumeClaims..."
  log_warning "This will DELETE all persistent data!"
  
  if confirm "Are you sure you want to delete PVCs and lose all data?"; then
    PVCS=$(kubectl get pvc -n "$NAMESPACE" -o name 2>/dev/null || echo "")
    if [ -n "$PVCS" ]; then
      # Store PV names before deleting PVCs
      PV_NAMES=""
      for pvc in $PVCS; do
        PV=$(kubectl get "$pvc" -n "$NAMESPACE" -o jsonpath='{.spec.volumeName}' 2>/dev/null || echo "")
        if [ -n "$PV" ]; then
          PV_NAMES="$PV_NAMES $PV"
        fi
        log_info "Deleting $pvc..."
        execute kubectl delete "$pvc" -n "$NAMESPACE" --wait=false
      done
      
      # Wait a bit for PVCs to be deleted
      sleep 5
      
      # Delete orphaned PVs (with Retain policy)
      if [ -n "$PV_NAMES" ]; then
        log_info "Checking for orphaned PersistentVolumes..."
        for pv in $PV_NAMES; do
          if kubectl get pv "$pv" &> /dev/null; then
            log_info "Deleting orphaned PV: $pv..."
            execute kubectl delete pv "$pv" --wait=false
          fi
        done
      fi
      
      log_success "PersistentVolumeClaims and PersistentVolumes deleted"
    else
      log_info "No PersistentVolumeClaims found"
    fi
  else
    log_warning "Skipped PVC deletion"
  fi
else
  log_info "Step 6/10: Skipping PersistentVolumeClaims (--keep-pvcs flag set)"
fi

echo ""

# ==============================================================================
# Step 7: Delete CSI Driver Components (if deployed)
# ==============================================================================
log_info "Step 7/10: Deleting CSI Driver components..."

# Delete CSI Driver resources in kube-system namespace
if kubectl get deployment cos-s3-csi-controller -n kube-system &> /dev/null; then
  log_info "Deleting CSI controller deployment..."
  execute kubectl delete deployment cos-s3-csi-controller -n kube-system --wait=false
fi

if kubectl get daemonset cos-s3-csi-driver -n kube-system &> /dev/null; then
  log_info "Deleting CSI driver daemonset..."
  execute kubectl delete daemonset cos-s3-csi-driver -n kube-system --wait=false
fi

# Delete CSI ServiceAccounts in kube-system
CSI_SERVICE_ACCOUNTS=$(kubectl get sa -n kube-system -o name 2>/dev/null | grep "cos-s3-csi" || echo "")
if [ -n "$CSI_SERVICE_ACCOUNTS" ]; then
  for sa in $CSI_SERVICE_ACCOUNTS; do
    log_info "Deleting $sa in kube-system..."
    execute kubectl delete "$sa" -n kube-system --wait=false
  done
fi

# Delete ConfigMaps in kube-system (minio-ca-cert)
if kubectl get configmap minio-ca-cert -n kube-system &> /dev/null; then
  log_info "Deleting minio-ca-cert ConfigMap from kube-system..."
  execute kubectl delete configmap minio-ca-cert -n kube-system --wait=false
fi

log_success "CSI Driver components deleted"
echo ""

# ==============================================================================
# Step 8: Delete Cluster-Wide Resources
# ==============================================================================
log_info "Step 8/10: Deleting cluster-wide resources..."

# Delete StorageClasses
STORAGE_CLASSES=$(kubectl get storageclass -o name 2>/dev/null | grep "cos-s3-csi" || echo "")
if [ -n "$STORAGE_CLASSES" ]; then
  for sc in $STORAGE_CLASSES; do
    log_info "Deleting $sc..."
    execute kubectl delete "$sc"
  done
fi

# Delete CSIDriver resource
if kubectl get csidriver cos.s3.csi.ibm.io &> /dev/null; then
  log_info "Deleting CSIDriver resource..."
  execute kubectl delete csidriver cos.s3.csi.ibm.io
fi

# Delete ClusterRoleBindings for geostudio
CLUSTER_ROLEBINDINGS=$(kubectl get clusterrolebinding -o name 2>/dev/null | grep -E "geostudio|cos-s3-csi" || echo "")
if [ -n "$CLUSTER_ROLEBINDINGS" ]; then
  for crb in $CLUSTER_ROLEBINDINGS; do
    log_info "Deleting $crb..."
    execute kubectl delete "$crb"
  done
fi

# Delete ClusterRoles for geostudio
CLUSTER_ROLES=$(kubectl get clusterrole -o name 2>/dev/null | grep -E "geostudio|cos-s3-csi" || echo "")
if [ -n "$CLUSTER_ROLES" ]; then
  for cr in $CLUSTER_ROLES; do
    log_info "Deleting $cr..."
    execute kubectl delete "$cr"
  done
fi

log_success "Cluster-wide resources deleted"
echo ""

# ==============================================================================
# Step 9: Delete Service Accounts and RoleBindings
# ==============================================================================
log_info "Step 9/10: Deleting ServiceAccounts and RoleBindings..."

SERVICE_ACCOUNTS=$(kubectl get sa -n "$NAMESPACE" -o name 2>/dev/null | grep -v "serviceaccount/default" || echo "")
if [ -n "$SERVICE_ACCOUNTS" ]; then
  for sa in $SERVICE_ACCOUNTS; do
    log_info "Deleting $sa..."
    execute kubectl delete "$sa" -n "$NAMESPACE" --wait=false
  done
fi

ROLEBINDINGS=$(kubectl get rolebinding -n "$NAMESPACE" -o name 2>/dev/null || echo "")
if [ -n "$ROLEBINDINGS" ]; then
  for rb in $ROLEBINDINGS; do
    log_info "Deleting $rb..."
    execute kubectl delete "$rb" -n "$NAMESPACE" --wait=false
  done
fi

ROLES=$(kubectl get role -n "$NAMESPACE" -o name 2>/dev/null || echo "")
if [ -n "$ROLES" ]; then
  for role in $ROLES; do
    log_info "Deleting $role..."
    execute kubectl delete "$role" -n "$NAMESPACE" --wait=false
  done
fi

log_success "ServiceAccounts, Roles, and RoleBindings deleted"
echo ""

# ==============================================================================
# Step 10: Uninstall Operator and CRDs
# ==============================================================================
if [ "$KEEP_OPERATOR" = false ]; then
  log_info "Step 10/10: Uninstalling operator and CRDs..."
  
  # Find operator namespaces (check multiple possible names)
  OPERATOR_NAMESPACES=$(kubectl get namespaces -o name 2>/dev/null | grep -E "operators-system|geostudio-operators" | sed 's|namespace/||' || echo "")
  
  if [ -n "$OPERATOR_NAMESPACES" ]; then
    for ns in $OPERATOR_NAMESPACES; do
      log_info "Deleting operator namespace: $ns..."
      execute kubectl delete namespace "$ns" --wait=false --timeout=60s
    done
  else
    log_info "No operator namespaces found"
  fi
  
  # Delete CRDs
  log_info "Deleting CRDs..."
  CRDS=$(kubectl get crd -o name 2>/dev/null | grep "geostudio" || echo "")
  if [ -n "$CRDS" ]; then
    for crd in $CRDS; do
      log_info "Deleting $crd..."
      execute kubectl delete "$crd" --wait=false
    done
  fi
  
  # Delete ClusterRoleBindings (broader search)
  log_info "Deleting operator ClusterRoleBindings..."
  CLUSTER_ROLEBINDINGS=$(kubectl get clusterrolebinding -o name 2>/dev/null | grep -E "operators-|geostudio" || echo "")
  if [ -n "$CLUSTER_ROLEBINDINGS" ]; then
    for crb in $CLUSTER_ROLEBINDINGS; do
      log_info "Deleting $crb..."
      execute kubectl delete "$crb" --wait=false
    done
  fi
  
  # Delete ClusterRoles (broader search)
  log_info "Deleting operator ClusterRoles..."
  CLUSTER_ROLES=$(kubectl get clusterrole -o name 2>/dev/null | grep -E "operators-|geostudio" || echo "")
  if [ -n "$CLUSTER_ROLES" ]; then
    for cr in $CLUSTER_ROLES; do
      log_info "Deleting $cr..."
      execute kubectl delete "$cr" --wait=false
    done
  fi
  
  # Delete MutatingWebhookConfigurations
  log_info "Deleting MutatingWebhookConfigurations..."
  MUTATING_WEBHOOKS=$(kubectl get mutatingwebhookconfigurations -o name 2>/dev/null | grep -E "operators|geostudio" || echo "")
  if [ -n "$MUTATING_WEBHOOKS" ]; then
    for mwh in $MUTATING_WEBHOOKS; do
      log_info "Deleting $mwh..."
      execute kubectl delete "$mwh" --wait=false
    done
  fi
  
  # Delete ValidatingWebhookConfigurations
  log_info "Deleting ValidatingWebhookConfigurations..."
  VALIDATING_WEBHOOKS=$(kubectl get validatingwebhookconfigurations -o name 2>/dev/null | grep -E "operators|geostudio" || echo "")
  if [ -n "$VALIDATING_WEBHOOKS" ]; then
    for vwh in $VALIDATING_WEBHOOKS; do
      log_info "Deleting $vwh..."
      execute kubectl delete "$vwh" --wait=false
    done
  fi
  
  log_success "Operator and CRDs uninstalled"
else
  log_info "Step 10/10: Skipping operator uninstall (--keep-operator flag set)"
fi

echo ""

# ==============================================================================
# Step 11: Clean up local-path-provisioner resources (if deployed by chart)
# ==============================================================================
log_info "Additional Cleanup: Checking for local-path-provisioner (if deployed by chart)..."

if kubectl get namespace local-path-storage &> /dev/null; then
  if kubectl get deployment local-path-provisioner -n local-path-storage &> /dev/null; then
    # Check if it has our labels (indicating we installed it)
    LABELS=$(kubectl get deployment local-path-provisioner -n local-path-storage -o jsonpath='{.metadata.labels}' 2>/dev/null || echo "")
    if [[ "$LABELS" == *"geostudio"* ]]; then
      log_info "Deleting local-path-provisioner (deployed by GeoStudio)..."
      execute kubectl delete namespace local-path-storage --wait=false
    else
      log_info "local-path-provisioner exists but wasn't deployed by GeoStudio (skipping)"
    fi
  fi
fi

log_success "Additional cleanup complete"
echo ""

# ==============================================================================
# Final Sweep: Check for any remaining GeoStudio resources
# ==============================================================================
log_info "Final Sweep: Checking for any remaining GeoStudio resources..."

REMAINING_ISSUES=0

# Check for stuck namespaces
STUCK_NAMESPACES=$(kubectl get namespaces 2>/dev/null | grep -E "operators|geostudio" | grep -v "NAME" || echo "")
if [ -n "$STUCK_NAMESPACES" ]; then
  log_warning "Found namespaces (may be terminating):"
  echo "$STUCK_NAMESPACES"
  REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

# Check for remaining cluster-wide resources
REMAINING_CRDS=$(kubectl get crd -o name 2>/dev/null | grep "geostudio" || echo "")
if [ -n "$REMAINING_CRDS" ]; then
  log_warning "Found remaining CRDs:"
  echo "$REMAINING_CRDS"
  REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

REMAINING_CRB=$(kubectl get clusterrolebinding -o name 2>/dev/null | grep -E "geostudio|operators-" || echo "")
if [ -n "$REMAINING_CRB" ]; then
  log_warning "Found remaining ClusterRoleBindings:"
  echo "$REMAINING_CRB"
  REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

REMAINING_CR=$(kubectl get clusterrole -o name 2>/dev/null | grep -E "geostudio|operators-" || echo "")
if [ -n "$REMAINING_CR" ]; then
  log_warning "Found remaining ClusterRoles:"
  echo "$REMAINING_CR"
  REMAINING_ISSUES=$((REMAINING_ISSUES + 1))
fi

if [ $REMAINING_ISSUES -eq 0 ]; then
  log_success "No remaining resources found - cluster is clean!"
else
  log_warning "Found $REMAINING_ISSUES category/categories with remaining resources"
  echo ""
  echo "Note: Namespaces may take a while to fully terminate."
  echo "      Other resources may require manual deletion if stuck."
fi

echo ""
echo "================================================================================"
echo "                           Uninstall Complete!"
echo "================================================================================"
echo ""

# Summary
log_success "GeoStudio uninstallation completed"
echo ""
echo "Summary:"
echo "  ✓ GEOStudio custom resources removed from namespace: $NAMESPACE"
echo "  ✓ Infrastructure components removed"
echo "  ✓ Application components removed"
echo "  ✓ CSI Driver components removed (kube-system)"
echo "  ✓ Jobs and hooks removed"
echo "  ✓ ConfigMaps and Secrets removed"
echo "  ✓ Cluster-wide resources removed (ClusterRoles, StorageClasses, CSIDriver)"

if [ "$KEEP_PVCS" = false ]; then
  echo "  ✓ PersistentVolumeClaims removed (data deleted)"
else
  echo "  ℹ PersistentVolumeClaims preserved"
fi

if [ "$KEEP_OPERATOR" = false ]; then
  echo "  ✓ Operator and CRDs removed"
else
  echo "  ℹ Operator preserved"
fi

echo ""
echo "  ℹ Container images preserved for faster redeployment"
echo ""

# Check for any remaining resources
log_info "Checking for any remaining resources in namespace $NAMESPACE..."
REMAINING=$(kubectl get all -n "$NAMESPACE" 2>/dev/null | grep -v "service/kubernetes" || echo "")
if [ -n "$REMAINING" ]; then
  log_warning "Some resources remain in namespace $NAMESPACE:"
  echo "$REMAINING"
  echo ""
  echo "You may need to manually delete these resources."
else
  log_success "No resources remaining in namespace $NAMESPACE (clean!)"
fi

echo ""
log_info "To verify the cluster is clean, run:"
echo "  kubectl get all -n $NAMESPACE"
echo "  kubectl get pvc -n $NAMESPACE"
echo "  kubectl get configmaps,secrets -n $NAMESPACE"
echo "  kubectl get all -n kube-system | grep cos-s3-csi"
echo "  kubectl get storageclass | grep cos-s3-csi"
echo "  kubectl get csidriver"
echo "  kubectl get clusterrole,clusterrolebinding | grep -E 'geostudio|cos-s3-csi'"
if [ "$KEEP_OPERATOR" = false ]; then
  echo "  kubectl get crd | grep geostudio"
  echo "  kubectl get namespaces | grep -E 'operators|geostudio'"
  echo "  kubectl get mutatingwebhookconfigurations,validatingwebhookconfigurations | grep -E 'operators|geostudio'"
fi
echo ""
