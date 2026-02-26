#!/bin/bash
# ==============================================================================
# GeoStudio Application Commands
# ==============================================================================
# Application management functions (deploy, delete, list, status, logs, restart)
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
# App Command Router
# ==============================================================================

app_command() {
  if [ $# -eq 0 ]; then
    show_app_help
    exit 0
  fi
  
  local subcommand=$1
  shift
  
  case $subcommand in
    deploy)
      app_deploy "$@"
      ;;
    delete)
      app_delete "$@"
      ;;
    list)
      app_list "$@"
      ;;
    status)
      app_status "$@"
      ;;
    logs)
      app_logs "$@"
      ;;
    restart)
      app_restart "$@"
      ;;
    --help|-h|help)
      show_app_help
      exit 0
      ;;
    *)
      log_error "Unknown app subcommand: $subcommand"
      echo ""
      echo "Run 'geostudio app help' for usage"
      exit 1
      ;;
  esac
}

# ==============================================================================
# App Deploy
# ==============================================================================

app_deploy() {
  export DEPLOYMENT_ENV=${DEPLOYMENT_ENV:-lima}
  export OC_PROJECT=${OC_PROJECT:-default}
  local dry_run_local=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --env)
        export DEPLOYMENT_ENV="$2"
        shift 2
        ;;
      --namespace)
        export OC_PROJECT="$2"
        shift 2
        ;;
      --dry-run)
        dry_run_local=true
        DRY_RUN=true
        shift
        ;;
      --help|-h)
        show_app_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_app_help
        exit 1
        ;;
    esac
  done
  
  # File paths
  local workspace_dir="$PROJECT_ROOT/workspace/$DEPLOYMENT_ENV"
  local env_file="$workspace_dir/env/.env"
  local env_sh_file="$workspace_dir/env/env.sh"
  local template_file="$PROJECT_ROOT/operators/examples/geostudio-operator-template.yaml"
  local output_file="$workspace_dir/geostudio-operator-deploy.yaml"
  local studio_api_key_file="$PROJECT_ROOT/.studio-api-key"
  
  log_step "GEOStudio Application Deployment"
  echo "Environment:      $DEPLOYMENT_ENV"
  echo "Namespace:        $OC_PROJECT"
  echo "Workspace:        $workspace_dir"
  echo ""
  
  # Check if operator is installed
  log_info "Checking if GEOStudio operator is installed..."
  if ! operator_is_installed; then
    echo ""
    log_error "GEOStudio operator is not installed!"
    echo ""
    echo "The GEOStudio operator must be installed before deploying applications."
    echo ""
    log_info "To install the operator, run:"
    echo "  geostudio operator install --local"
    echo ""
    exit 1
  fi
  
  if ! operator_is_running; then
    log_warning "Operator is not ready"
    echo ""
    log_info "Check operator status:"
    echo "  geostudio operator status"
    echo ""
    if ! confirm "Continue anyway?"; then
      log_info "Aborted"
      exit 1
    fi
  else
    log_success "GEOStudio operator is installed and running"
  fi
  echo ""
  
  # Check for envsubst
  if ! command -v envsubst &> /dev/null; then
    log_error "envsubst not found. Please install it:"
    echo ""
    echo "  macOS:  brew install gettext && brew link --force gettext"
    echo "  Linux:  sudo apt-get install gettext-base"
    echo ""
    exit 1
  fi
  
  # Step 1: Setup workspace environment
  log_step "Setting up workspace"
  
  if [ ! -f "$PROJECT_ROOT/deployment-scripts/setup-workspace-env.sh" ]; then
    log_error "setup-workspace-env.sh not found"
    exit 1
  fi
  
  # Set Lima-specific defaults before running setup
  export ROUTE_ENABLED=false
  
  # Run the workspace setup script
  cd "$PROJECT_ROOT"
  ./deployment-scripts/setup-workspace-env.sh
  
  # Step 2: Apply cluster-specific configuration overrides
  local cluster_type=$(get_cluster_type)
  log_step "Applying configuration for $cluster_type cluster"
  
  # Generate OAuth cookie secret
  export cookie_secret=$(cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32)
  
  # Use consistent OAuth client secret that matches Keycloak configuration
  # This must match the value in geospatial-studio/values.yaml (global.keycloak.clientSecret)
  export oauth_client_secret="oauth_client_secret"
  
  # Generate TLS certificates for local development
  log_info "Generating TLS certificates for local development..."
  local tls_dir="$workspace_dir/tls"
  mkdir -p "$tls_dir"
  
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$tls_dir/tls.key" \
    -out "$tls_dir/tls.crt" \
    -subj "/CN=$OC_PROJECT.svc.cluster.local" 2>/dev/null
  
  # Extract the cert and key into base64 env vars
  export TLS_CRT_B64=$(openssl base64 -in "$tls_dir/tls.crt" -A)
  export TLS_KEY_B64=$(openssl base64 -in "$tls_dir/tls.key" -A)
  
  # Generate dummy image pull secret (for local development)
  # This is a valid base64 encoded dockerconfigjson with dummy credentials
  export IMAGE_PULL_SECRET_B64="eyJhdXRocyI6eyJleGFtcGxlLmlvIjp7InVzZXJuYW1lIjoiZXhhbXBsZSIsInBhc3N3b3JkIjoiZXhhbXBsZSIsImVtYWlsIjoiZXhhbXBsZUBleGFtcGxlLmNvbSIsImF1dGgiOiJaWGhoYlhCc1pUcGxlR0Z0Y0d4bCJ9fX0="
  
  # Apply configuration using cross-platform sed
  sed_inplace "$env_sh_file" 's|export ROUTE_ENABLED=.*|export ROUTE_ENABLED=false|g'
  sed_inplace "$env_sh_file" "s/export ENVIRONMENT=.*/export ENVIRONMENT=local/g"
  sed_inplace "$env_sh_file" "s/export CLUSTER_URL=.*/export CLUSTER_URL=localhost/g"
  sed_inplace "$env_sh_file" "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=cos-s3-csi-s3fs-sc/g"
  sed_inplace "$env_sh_file" "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=local-path/g"
  sed_inplace "$env_sh_file" "s/export SHARE_PIPELINE_PVC=.*/export SHARE_PIPELINE_PVC=true/g"
  sed_inplace "$env_sh_file" "s/export STORAGE_PVC_ENABLED=.*/export STORAGE_PVC_ENABLED=true/g"
  sed_inplace "$env_sh_file" "s/export STORAGE_FILESYSTEM_ENABLED=.*/export STORAGE_FILESYSTEM_ENABLED=false/g"
  sed_inplace "$env_sh_file" "s/export CREATE_TUNING_FOLDERS_FLAG=.*/export CREATE_TUNING_FOLDERS_FLAG=false/g"
  sed_inplace "$env_sh_file" "s|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=.*|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=/data|g"
  sed_inplace "$env_sh_file" "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g"
  sed_inplace "$env_sh_file" "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g"
  sed_inplace "$env_sh_file" "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio|g"
  sed_inplace "$env_sh_file" "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g"
  sed_inplace "$env_sh_file" "s/export CREATE_TLS_SECRET=.*/export CREATE_TLS_SECRET=false/g"
  
  # Set default credentials for local development (MinIO, PostgreSQL, Keycloak)
  sed_inplace "$env_file" "s/access_key_id=.*/access_key_id=minioadmin/g"
  sed_inplace "$env_file" "s/secret_access_key=.*/secret_access_key=minioadmin/g"
  sed_inplace "$env_file" "s/oauth_client_secret=.*/oauth_client_secret=$oauth_client_secret/g"
  sed_inplace "$env_file" "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g"
  sed_inplace "$env_file" "s|endpoint=.*|endpoint=https://minio.$OC_PROJECT.svc.cluster.local:9000|g"
  sed_inplace "$env_file" "s/region=.*/region=us-east-1/g"
  sed_inplace "$env_file" "s/pg_username=.*/pg_username=postgres/g"
  sed_inplace "$env_file" "s/pg_password=.*/pg_password=devPostgresql123/g"
  sed_inplace "$env_file" "s/pg_uri=.*/pg_uri=postgresql.$OC_PROJECT.svc.cluster.local/g"
  sed_inplace "$env_file" "s/pg_port=.*/pg_port=5432/g"
  sed_inplace "$env_file" "s/pg_studio_db_name=.*/pg_studio_db_name=geostudio/g"
  sed_inplace "$env_file" "s/geoserver_username=.*/geoserver_username=admin/g"
  sed_inplace "$env_file" "s/geoserver_password=.*/geoserver_password=geoserver/g"
  sed_inplace "$env_file" "s/image_pull_policy=.*/image_pull_policy=IfNotPresent/g"
  sed_inplace "$env_file" "s|tls_crt_b64=.*|tls_crt_b64=$TLS_CRT_B64|g"
  sed_inplace "$env_file" "s|tls_key_b64=.*|tls_key_b64=$TLS_KEY_B64|g"
  sed_inplace "$env_file" "s|image_pull_secret_b64=.*|image_pull_secret_b64=$IMAGE_PULL_SECRET_B64|g"
  
  # Set dummy tokens for Mapbox and Cesium (required for secret creation, even if not used)
  # Using "none" as placeholder - these will be base64 encoded by Helm
  sed_inplace "$env_file" "s/mapbox_token=.*/mapbox_token=none/g"
  sed_inplace "$env_file" "s/cesium_token=.*/cesium_token=none/g"
  
  # Set dummy values for optional API keys (SentinelHub, NASA, Jira)
  sed_inplace "$env_file" "s/sh_client_id=.*/sh_client_id=none/g"
  sed_inplace "$env_file" "s/sh_client_secret=.*/sh_client_secret=none/g"
  sed_inplace "$env_file" "s/nasa_earth_data_bearer_token=.*/nasa_earth_data_bearer_token=none/g"
  sed_inplace "$env_file" "s/jira_api_key=.*/jira_api_key=none/g"
  
  log_success "Configuration applied for $cluster_type"
  
  # Step 3: Merge .studio-api-key if it exists
  log_step "Checking for .studio-api-key"
  if [ -f "$studio_api_key_file" ]; then
    log_success "Found $studio_api_key_file"
    source "$studio_api_key_file"
    
    # Update studio_api_key if it exists in .env
    if grep -q "studio_api_key=" "$env_file" 2>/dev/null; then
      sed_inplace "$env_file" "s|studio_api_key=.*|studio_api_key=${STUDIO_API_KEY}|g"
    fi
    
    # Update studio_api_encryption_key if it exists in .env
    if grep -q "studio_api_encryption_key=" "$env_file" 2>/dev/null; then
      sed_inplace "$env_file" "s|studio_api_encryption_key=.*|studio_api_encryption_key=${API_ENCRYPTION_KEY}|g"
    fi
  else
    log_info "(not found - will use values from .env)"
  fi
  
  # Step 4: Source environment files
  log_step "Loading environment configuration"
  
  if [ ! -f "$env_file" ] || [ ! -f "$env_sh_file" ]; then
    log_error "Environment files not found"
    exit 1
  fi
  
  log_success "Sourcing $env_file"
  set -a
  source "$env_file"
  set +a
  
  log_success "Sourcing $env_sh_file"
  source "$env_sh_file"
  
  # Validate critical variables are set
  log_info "Validating required environment variables..."
  local missing_vars=()
  
  # Check for critical variables
  [ -z "${pg_username:-}" ] && missing_vars+=("pg_username")
  [ -z "${pg_password:-}" ] && missing_vars+=("pg_password")
  [ -z "${pg_uri:-}" ] && missing_vars+=("pg_uri")
  [ -z "${pg_port:-}" ] && missing_vars+=("pg_port")
  [ -z "${access_key_id:-}" ] && missing_vars+=("access_key_id")
  [ -z "${secret_access_key:-}" ] && missing_vars+=("secret_access_key")
  [ -z "${endpoint:-}" ] && missing_vars+=("endpoint")
  [ -z "${region:-}" ] && missing_vars+=("region")
  [ -z "${tls_crt_b64:-}" ] && missing_vars+=("tls_crt_b64")
  [ -z "${tls_key_b64:-}" ] && missing_vars+=("tls_key_b64")
  [ -z "${image_pull_secret_b64:-}" ] && missing_vars+=("image_pull_secret_b64")
  
  if [ ${#missing_vars[@]} -gt 0 ]; then
    log_error "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
      echo "  - $var"
    done
    echo ""
    log_error "Please check your environment files:"
    echo "  - $env_file"
    echo "  - $env_sh_file"
    exit 1
  fi
  
  log_success "All required variables validated"
  
  # Step 5: Generate operator CR from template
  log_step "Generating GEOStudio operator CR"
  
  if [ ! -f "$template_file" ]; then
    log_error "Template file not found: $template_file"
    exit 1
  fi
  
  log_info "Template: $(basename $template_file)"
  log_info "Output:   $output_file"
  
  envsubst < "$template_file" > "$output_file"
  
  log_success "Generated: $output_file"
  
  # Step 6: Apply to Kubernetes cluster
  log_step "Applying to Kubernetes cluster"
  
  if [ "$dry_run_local" = true ] || [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would apply manifest:"
    echo "  kubectl apply -f $output_file"
    echo ""
    log_info "Generated manifest saved to: $output_file"
    return 0
  fi
  
  kubectl apply -f "$output_file"
  
  echo ""
  log_success "GEOStudio Deployment Submitted"
  echo ""
  log_info "Monitor deployment status:"
  echo "  geostudio app status"
  echo "  kubectl get pods -n $OC_PROJECT -w"
  echo ""
  log_info "View operator logs:"
  echo "  geostudio operator logs --follow"
}

# ==============================================================================
# App Delete
# ==============================================================================

app_delete() {
  local namespace="default"
  local keep_pvcs=false
  
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
      *)
        shift
        ;;
    esac
  done
  
  log_step "Deleting GeoStudio Application"
  echo "Namespace: $namespace"
  echo ""
  
  # Check if any instances exist
  local instance_count=$(kubectl get geostudios -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  
  if [ "$instance_count" -eq 0 ]; then
    log_info "No GeoStudio instances found in namespace: $namespace"
    
    # Check if there are any other resources
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local pvc_count=$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$pod_count" -gt 0 ] || [ "$pvc_count" -gt 0 ]; then
      echo ""
      log_warning "Found remaining resources in namespace:"
      [ "$pod_count" -gt 0 ] && echo "  - $pod_count pods"
      [ "$pvc_count" -gt 0 ] && echo "  - $pvc_count PVCs"
      echo ""
      
      if confirm "Delete all resources in namespace $namespace?"; then
        log_info "Deleting all resources..."
        
        # Delete deployments and statefulsets
        kubectl delete deployments --all -n "$namespace" --timeout=10s 2>/dev/null || true
        kubectl delete statefulsets --all -n "$namespace" --timeout=10s 2>/dev/null || true
        
        # Force delete pods
        kubectl delete pods --all -n "$namespace" --force --grace-period=0 2>/dev/null || true
        
        # Delete services, configmaps, secrets, jobs
        kubectl delete services,configmaps,secrets,jobs --all -n "$namespace" 2>/dev/null || true
        
        # Wait before deleting PVCs
        if [ "$keep_pvcs" = false ] && [ "$pvc_count" -gt 0 ]; then
          log_info "Waiting 10 seconds before deleting PVCs..."
          sleep 10
          
          log_info "Deleting PVCs..."
          kubectl delete pvc --all -n "$namespace" --force --grace-period=0 2>/dev/null || true
          sleep 2
        fi
        
        log_success "Resources deleted"
      else
        log_info "Keeping resources"
      fi
    else
      log_info "No resources to delete"
    fi
    
    echo ""
    log_success "Cleanup complete"
    return 0
  fi
  
  # Show what will be deleted
  log_info "Found $instance_count GeoStudio instance(s):"
  kubectl get geostudios -n "$namespace"
  echo ""
  
  if ! confirm "This will delete the GeoStudio instance(s). Continue?"; then
    log_info "Aborted"
    exit 0
  fi
  
  log_info "Deleting GeoStudio instance(s) in namespace: $namespace"
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would delete GeoStudio instance(s)"
    return 0
  fi
  
  # Delete GeoStudio instances
  kubectl delete geostudios --all -n "$namespace" --timeout=20s 2>/dev/null || true
  
  # Delete all application resources
  log_info "Deleting application resources..."
  
  # Delete deployments and statefulsets first
  kubectl delete deployments --all -n "$namespace" --timeout=10s 2>/dev/null || true
  kubectl delete statefulsets --all -n "$namespace" --timeout=10s 2>/dev/null || true
  
  # Force delete any remaining pods
  kubectl delete pods --all -n "$namespace" --force --grace-period=0 2>/dev/null || true
  
  # Delete services, configmaps, secrets, jobs
  kubectl delete services,configmaps,secrets,jobs --all -n "$namespace" 2>/dev/null || true
  
  # Wait 10 seconds for resources to clean up before deleting PVCs
  if [ "$keep_pvcs" = false ]; then
    log_info "Waiting 10 seconds for resources to clean up before deleting PVCs..."
    sleep 10
    
    local pvc_count=$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pvc_count" -gt 0 ]; then
      log_info "Deleting $pvc_count PVCs..."
      kubectl delete pvc --all -n "$namespace" --force --grace-period=0 2>/dev/null || true
      
      # Wait a bit for PVCs to start deleting
      sleep 2
      
      # Check if any are still stuck
      local stuck_pvcs=$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
      if [ "$stuck_pvcs" -gt 0 ]; then
        log_warning "$stuck_pvcs PVCs still terminating (this is normal)"
      fi
    else
      log_info "No PVCs to delete"
    fi
  fi
  
  log_success "GeoStudio instance deleted"
  
  echo ""
  log_info "Note: Shared cluster infrastructure remains installed:"
  echo "  - GeoStudio Operator"
  echo "  - IBM Object S3 CSI Driver"
  echo ""
  log_info "To remove all cluster infrastructure, run:"
  echo "  ./geostudio operator uninstall"
}

# ==============================================================================
# App List
# ==============================================================================

app_list() {
  local namespace=""
  
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
  
  log_step "GeoStudio Instances"
  echo ""
  
  if [ -n "$namespace" ]; then
    kubectl get geostudios -n "$namespace"
  else
    kubectl get geostudios --all-namespaces
  fi
}

# ==============================================================================
# App Status
# ==============================================================================

app_status() {
  local namespace="default"
  
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
  
  log_step "GeoStudio Application Status"
  echo "Namespace: $namespace"
  echo ""
  
  # Check if any instances exist
  if ! kubectl get geostudios -n "$namespace" &> /dev/null; then
    log_error "No GeoStudio instances found in namespace: $namespace"
    exit 1
  fi
  
  log_info "GeoStudio Resources:"
  kubectl get geostudios -n "$namespace"
  echo ""
  
  log_info "Application Pods:"
  kubectl get pods -n "$namespace" -l app.kubernetes.io/name=geostudio 2>/dev/null || echo "No pods found"
  echo ""
  
  log_info "Services:"
  kubectl get svc -n "$namespace" -l app.kubernetes.io/name=geostudio 2>/dev/null || echo "No services found"
}

# ==============================================================================
# App Logs
# ==============================================================================

app_logs() {
  local namespace="default"
  local component=""
  local follow=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --namespace)
        namespace="$2"
        shift 2
        ;;
      --component)
        component="$2"
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
  
  local selector="app.kubernetes.io/name=geostudio"
  if [ -n "$component" ]; then
    selector="${selector},app.kubernetes.io/component=${component}"
  fi
  
  if [ "$follow" = true ]; then
    kubectl logs -n "$namespace" -l "$selector" -f
  else
    kubectl logs -n "$namespace" -l "$selector" --tail=100
  fi
}

# ==============================================================================
# App Restart
# ==============================================================================

app_restart() {
  local namespace="default"
  local component=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --namespace)
        namespace="$2"
        shift 2
        ;;
      --component)
        component="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  
  log_info "Restarting application pods in namespace: $namespace"
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would restart pods"
    return 0
  fi
  
  if [ -n "$component" ]; then
    kubectl rollout restart deployment -n "$namespace" -l "app.kubernetes.io/component=${component}"
  else
    kubectl rollout restart deployment -n "$namespace" -l "app.kubernetes.io/name=geostudio"
  fi
  
  log_success "Restart initiated"
}
