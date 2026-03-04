#!/bin/bash
# ==============================================================================
# GeoStudio Operator Commands
# ==============================================================================
# Operator management functions (install, uninstall, status, logs, restart)
#
# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# Source dependencies
if [ -z "$GREEN" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
  source "$(dirname "${BASH_SOURCE[0]}")/k8s-utils.sh"
fi

# ==============================================================================
# Operator Command Router
# ==============================================================================

operator_command() {
  if [ $# -eq 0 ]; then
    show_operator_help
    exit 0
  fi
  
  local subcommand=$1
  shift
  
  case $subcommand in
    install)
      operator_install "$@"
      ;;
    uninstall)
      operator_uninstall "$@"
      ;;
    status)
      operator_status "$@"
      ;;
    logs)
      operator_logs "$@"
      ;;
    restart)
      operator_restart "$@"
      ;;
    --help|-h|help)
      show_operator_help
      exit 0
      ;;
    *)
      log_error "Unknown operator subcommand: $subcommand"
      echo ""
      echo "Run 'geostudio operator help' for usage"
      exit 1
      ;;
  esac
}

# ==============================================================================
# Operator Install
# ==============================================================================

operator_install() {
  local deployment_mode=""
  local operator_version=""
  local namespace="geostudio-operators-system"
  local operator_image=""
  local image_pull_policy="IfNotPresent"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --local)
        deployment_mode="local"
        shift
        ;;
      --prod|--production)
        deployment_mode="prod"
        shift
        ;;
      --version)
        operator_version="$2"
        shift 2
        ;;
      --namespace)
        namespace="$2"
        shift 2
        ;;
      --help|-h)
        show_operator_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_operator_help
        exit 1
        ;;
    esac
  done
  
  # Validate deployment mode
  if [ -z "$deployment_mode" ]; then
    log_error "Deployment mode not specified. Use --local or --prod"
    echo ""
    show_operator_help
    exit 1
  fi
  
  # Set defaults based on mode
  if [ "$deployment_mode" = "local" ]; then
    operator_version="${operator_version:-local}"
    operator_image="geostudio-operator:${operator_version}"
    image_pull_policy="Never"
  elif [ "$deployment_mode" = "prod" ]; then
    operator_version="${operator_version:-latest}"
    operator_image="quay.io/geospatial-studio/geostudio-operator:${operator_version}"
    image_pull_policy="IfNotPresent"
  fi
  
  # Display configuration
  local cluster_type=$(get_cluster_type)
  log_step "Installing GeoStudio Operator"
  echo "Mode:               ${deployment_mode}"
  echo "Cluster Type:       ${cluster_type}"
  echo "Image:              ${operator_image}"
  echo "ImagePullPolicy:    ${image_pull_policy}"
  echo "Namespace:          ${namespace}"
  echo ""
  
  # Check prerequisites
  log_info "Checking prerequisites..."
  
  require_command kubectl "Install kubectl from https://kubernetes.io/docs/tasks/tools/" || exit 1
  require_command make || exit 1
  require_command kustomize "Install kustomize from https://kubectl.docs.kubernetes.io/installation/kustomize/" || exit 1
  
  # Check cluster-specific prerequisites
  local cluster_type=$(get_cluster_type)
  if [ "$deployment_mode" = "local" ]; then
    case "$cluster_type" in
      lima)
        require_command limactl "Install Lima from https://github.com/lima-vm/lima" || exit 1
        ;;
      kind)
        require_command kind "Install kind from https://kind.sigs.k8s.io/" || exit 1
        ;;
      k8s)
        log_info "Native k8s cluster detected"
        ;;
    esac
  fi
  
  log_success "All prerequisites met"
  echo ""
  
  # Check cluster connection
  log_info "Checking Kubernetes cluster connection..."
  check_kubectl_connection || exit 1
  log_success "Connected to cluster successfully"
  echo ""
  
  # Verify local image for local mode
  if [ "$deployment_mode" = "local" ]; then
    log_info "Verifying local image availability..."
    
    if ! verify_local_image "${operator_image}"; then
      log_error "Local image '${operator_image}' not found!"
      echo ""
      log_error "Please build and import the image first by running:"
      log_error "  ./geostudio build --local"
      echo ""
      exit 1
    fi
    
    log_success "Local image '${operator_image}' verified"
    echo ""
  fi
  
  # Install operator
  log_info "Installing CRDs and Operator..."
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would install operator with:"
    echo "  NAMESPACE=${namespace}"
    echo "  IMG=${operator_image}"
    return 0
  fi
  
  # Change to operators directory
  cd "$PROJECT_ROOT/operators"
  
  make install \
    NAMESPACE=${namespace} \
    IMG=${operator_image}
  
  log_info "Waiting for operator deployment to be ready..."
  sleep 2
  
  # Wait for operator
  log_info "Waiting for operator to be ready..."
  
  if kubectl wait --for=condition=available --timeout=120s \
    deployment/operators-controller-manager -n ${namespace}; then
    log_success "Operator is ready!"
  else
    log_warning "Operator did not become ready within timeout"
    kubectl get pods -n ${namespace}
    echo ""
    log_info "To view operator logs, run:"
    echo "  geostudio operator logs"
  fi
  
  echo ""
  log_success "Operator installed successfully"
  echo ""
  log_info "Next steps:"
  echo "./geostudio app deploy"
}

# ==============================================================================
# Operator Uninstall
# ==============================================================================

operator_uninstall() {
  local namespace="geostudio-operators-system"
  local keep_pvcs=false
  local force=false
  local skip_csi_cleanup=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --namespace)
        namespace="$2"
        shift 2
        ;;
      --keep-pvcs)
        keep_pvcs=true
        shift
        ;;
      --force)
        force=true
        shift
        ;;
      --skip-csi-cleanup)
        skip_csi_cleanup=true
        shift
        ;;
      --help|-h)
        show_operator_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  
  log_step "Uninstalling GeoStudio Operator"
  echo "Namespace: $namespace"
  echo ""
  
  # Check for active GeoStudio instances
  log_info "Checking for active GeoStudio instances..."
  local instances=$(kubectl get geostudios --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
  
  if [ "$instances" -gt 0 ]; then
    log_error "Cannot uninstall operator - active GeoStudio instances found:"
    echo ""
    kubectl get geostudios --all-namespaces
    echo ""
    
    if [ "$force" = false ]; then
      log_error "Apps must be deleted before uninstalling the operator."
      echo ""
      log_info "To delete apps, run:"
      echo "  ./geostudio app delete --namespace <namespace>"
      echo ""
      log_info "To force uninstall anyway (not recommended):"
      echo "  ./geostudio operator uninstall --force"
      echo ""
      exit 1
    else
      log_warning "Force flag enabled - proceeding with uninstall despite active apps"
      log_warning "This may leave orphaned resources in the cluster!"
      echo ""
      
      if ! confirm "Are you sure you want to force uninstall?"; then
        log_info "Aborted"
        exit 0
      fi
    fi
  else
    log_success "No active GeoStudio instances found"
  fi
  
  echo ""
  
  if ! confirm "This will remove the operator and all CRDs. Continue?"; then
    log_info "Aborted"
    exit 0
  fi
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would uninstall operator from namespace: $namespace"
    log_info "[DRY-RUN] Would clean up CSI driver (skip_csi=$skip_csi_cleanup)"
    return 0
  fi
  
  cd "$PROJECT_ROOT/operators"
  
  log_info "Uninstalling operator..."
  make uninstall NAMESPACE=${namespace} || true
  
  echo ""
  log_success "Operator uninstalled"
  echo ""
  
  # Clean up CSI driver
  cleanup_csi_driver "$skip_csi_cleanup"
  
  echo ""
  log_success "Uninstall complete"
}

# ==============================================================================
# Operator Status
# ==============================================================================

operator_status() {
  local namespace="geostudio-operators-system"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --namespace)
        namespace="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  
  log_step "GeoStudio Operator Status"
  echo "Namespace: $namespace"
  echo ""
  
  # Check if operator is installed
  if ! operator_is_installed; then
    log_error "Operator is not installed (CRD not found)"
    echo ""
    log_info "To install, run:"
    echo "  geostudio operator install --local"
    exit 1
  fi
  
  log_success "Operator CRDs installed"
  
  # Check if operator is running
  if ! kubectl get deployment operators-controller-manager -n "$namespace" &> /dev/null; then
    log_error "Operator deployment not found in namespace: $namespace"
    exit 1
  fi
  
  log_success "Operator deployment exists"
  
  # Check readiness
  if operator_is_running "$namespace"; then
    log_success "Operator is running and ready"
  else
    log_warning "Operator is not ready"
  fi
  
  echo ""
  kubectl get deployment operators-controller-manager -n "$namespace"
  echo ""
  kubectl get pods -n "$namespace" -l control-plane=controller-manager
}

# ==============================================================================
# Operator Logs
# ==============================================================================

operator_logs() {
  local namespace="geostudio-operators-system"
  local follow=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --namespace)
        namespace="$2"
        shift 2
        ;;
      --follow|-f)
        follow=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  
  if ! kubectl get deployment operators-controller-manager -n "$namespace" &> /dev/null; then
    log_error "Operator deployment not found in namespace: $namespace"
    exit 1
  fi
  
  if [ "$follow" = true ]; then
    kubectl logs -n "$namespace" deployment/operators-controller-manager -f
  else
    kubectl logs -n "$namespace" deployment/operators-controller-manager --tail=100
  fi
}

# ==============================================================================
# Operator Restart
# ==============================================================================

operator_restart() {
  local namespace="geostudio-operators-system"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --namespace)
        namespace="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  
  log_info "Restarting operator in namespace: $namespace"
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would restart operator deployment"
    return 0
  fi
  
  kubectl rollout restart deployment/operators-controller-manager -n "$namespace"
  kubectl rollout status deployment/operators-controller-manager -n "$namespace"
  
  log_success "Operator restarted successfully"
}
