#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0

# ==============================================================================
# GEOStudio Operator Deployment Script for Lima
# ==============================================================================
# Deploys GEOStudio using the operator with environment variable substitution
#
# This script:
#   1. Creates/reuses workspace environment from deployment-scripts/setup-workspace-env.sh
#   2. Sources secrets from workspace/<env>/env/.env
#   3. Sources configuration from workspace/<env>/env/env.sh
#   4. Optionally merges values from .studio-api-key if it exists
#   5. Generates GEOStudio CR from template using envsubst
#   6. Applies to Kubernetes cluster
#
# Usage:
#   ./deploy-geostudio-operator-lima.sh                    # Deploy to lima/default
#   ./deploy-geostudio-operator-lima.sh --dry-run          # Generate but don't apply
#   ./deploy-geostudio-operator-lima.sh --namespace prod   # Deploy to different namespace
#
# Options:
#   --dry-run              Generate manifest without applying
#   --namespace NAME       Override namespace (default: default)
#   --env ENV             Override deployment environment (default: lima)
#   -h, --help            Show this help message
# ==============================================================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Default values
export DEPLOYMENT_ENV=${DEPLOYMENT_ENV:-lima}
export OC_PROJECT=${OC_PROJECT:-default}
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --namespace)
      export OC_PROJECT="$2"
      shift 2
      ;;
    --env)
      export DEPLOYMENT_ENV="$2"
      shift 2
      ;;
    -h|--help)
      head -30 "$0" | grep "^#" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# File paths
WORKSPACE_DIR="$PROJECT_ROOT/workspace/$DEPLOYMENT_ENV"
ENV_FILE="$WORKSPACE_DIR/env/.env"
ENV_SH_FILE="$WORKSPACE_DIR/env/env.sh"
TEMPLATE_FILE="$SCRIPT_DIR/examples/geostudio-operator-template.yaml"
OUTPUT_FILE="$WORKSPACE_DIR/geostudio-operator-deploy.yaml"
STUDIO_API_KEY_FILE="$PROJECT_ROOT/.studio-api-key"

echo "=============================================================================="
echo "                    GEOStudio Application Deployment"
echo "=============================================================================="
echo "Environment:      $DEPLOYMENT_ENV"
echo "Namespace:        $OC_PROJECT"
echo "Workspace:        $WORKSPACE_DIR"
echo "=============================================================================="
echo ""

# Check if operator is installed
echo "Checking if GEOStudio operator is installed..."
if ! kubectl get crd geostudios.geostudio.geostudio.ibm.com &> /dev/null; then
  echo ""
  echo "❌ Error: GEOStudio operator is not installed!"
  echo ""
  echo "The GEOStudio operator must be installed before deploying applications."
  echo ""
  echo "To install the operator, run:"
  echo "  ./install-geostudio-operator.sh --local"
  echo ""
  echo "Then run this script again to deploy the application."
  echo ""
  exit 1
fi

# Check if operator is running
OPERATOR_NAMESPACE="geostudio-operators-system"
if ! kubectl get deployment operators-controller-manager -n "$OPERATOR_NAMESPACE" &> /dev/null; then
  echo ""
  echo "⚠️  Warning: Operator deployment not found in namespace: $OPERATOR_NAMESPACE"
  echo ""
  echo "The operator may be installed in a different namespace."
  echo "Continuing with deployment..."
  echo ""
else
  OPERATOR_READY=$(kubectl get deployment operators-controller-manager -n "$OPERATOR_NAMESPACE" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  if [ "$OPERATOR_READY" = "0" ]; then
    echo ""
    echo "⚠️  Warning: Operator is not ready (0 available replicas)"
    echo ""
    echo "Check operator status:"
    echo "  kubectl get pods -n $OPERATOR_NAMESPACE"
    echo "  kubectl logs -n $OPERATOR_NAMESPACE deployment/operators-controller-manager"
    echo ""
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
      echo "Aborted."
      exit 1
    fi
  else
    echo "✓ GEOStudio operator is installed and running"
  fi
fi
echo ""

# Check for envsubst
if ! command -v envsubst &> /dev/null; then
  echo "❌ envsubst not found. Please install it:"
  echo ""
  echo "  macOS:  brew install gettext && brew link --force gettext"
  echo "  Linux:  sudo apt-get install gettext-base"
  echo ""
  exit 1
fi

# Step 1: Setup workspace environment
echo "Step 1/7: Setting up workspace..."
if [ ! -f "$PROJECT_ROOT/deployment-scripts/setup-workspace-env.sh" ]; then
  echo "❌ Error: setup-workspace-env.sh not found"
  exit 1
fi

# Set Lima-specific defaults before running setup
export ROUTE_ENABLED=false

# Run the existing workspace setup script
cd "$PROJECT_ROOT"
./deployment-scripts/setup-workspace-env.sh

# Step 2: Apply Lima-specific configuration overrides
echo ""
echo "Step 2/7: Applying Lima-specific configuration..."

# Generate OAuth cookie secret if not already set
export cookie_secret=$(cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32)

# Apply OS-specific sed commands
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS sed requires '' after -i
  
  # Environment and routing
  sed -i '' 's|export ROUTE_ENABLED=.*|export ROUTE_ENABLED=false|g' "$ENV_SH_FILE"
  sed -i '' "s/export ENVIRONMENT=.*/export ENVIRONMENT=local/g" "$ENV_SH_FILE"
  sed -i '' "s/export CLUSTER_URL=.*/export CLUSTER_URL=localhost/g" "$ENV_SH_FILE"
  
  # Storage configuration
  sed -i '' "s/export SHARE_PIPELINE_PVC=.*/export SHARE_PIPELINE_PVC=true/g" "$ENV_SH_FILE"
  sed -i '' "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=cos-s3-csi-s3fs-sc/g" "$ENV_SH_FILE"
  sed -i '' "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=local-path/g" "$ENV_SH_FILE"
  sed -i '' "s/export STORAGE_PVC_ENABLED=.*/export STORAGE_PVC_ENABLED=true/g" "$ENV_SH_FILE"
  sed -i '' "s/export STORAGE_FILESYSTEM_ENABLED=.*/export STORAGE_FILESYSTEM_ENABLED=false/g" "$ENV_SH_FILE"
  sed -i '' "s/export CREATE_TUNING_FOLDERS_FLAG=.*/export CREATE_TUNING_FOLDERS_FLAG=false/g" "$ENV_SH_FILE"
  sed -i '' "s|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=.*|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=/data|g" "$ENV_SH_FILE"
  
  # OAuth configuration for Keycloak
  sed -i '' "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" "$ENV_SH_FILE"
  sed -i '' "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" "$ENV_SH_FILE"
  sed -i '' "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio|g" "$ENV_SH_FILE"
  sed -i '' "s|export OAUTH_URL=.*|export OAUTH_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio/protocol/openid-connect/auth|g" "$ENV_SH_FILE"
  sed -i '' "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g" "$ENV_SH_FILE"
  
  # .env file updates
  sed -i '' "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g" "$ENV_FILE"
  sed -i '' "s|endpoint=.*|endpoint=https://minio.$OC_PROJECT.svc.cluster.local:9000|g" "$ENV_FILE"
  sed -i '' "s/region=.*/region=us-east-1/g" "$ENV_FILE"
  sed -i '' "s/pg_uri=.*/pg_uri=postgresql.$OC_PROJECT.svc.cluster.local/g" "$ENV_FILE"
  
else
  # Linux sed doesn't need '' after -i
  
  # Environment and routing
  sed -i 's|export ROUTE_ENABLED=.*|export ROUTE_ENABLED=false|g' "$ENV_SH_FILE"
  sed -i "s/export ENVIRONMENT=.*/export ENVIRONMENT=local/g" "$ENV_SH_FILE"
  sed -i "s/export CLUSTER_URL=.*/export CLUSTER_URL=localhost/g" "$ENV_SH_FILE"
  
  # Storage configuration
  sed -i "s/export SHARE_PIPELINE_PVC=.*/export SHARE_PIPELINE_PVC=true/g" "$ENV_SH_FILE"
  sed -i "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=cos-s3-csi-s3fs-sc/g" "$ENV_SH_FILE"
  sed -i "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=local-path/g" "$ENV_SH_FILE"
  sed -i "s/export STORAGE_PVC_ENABLED=.*/export STORAGE_PVC_ENABLED=true/g" "$ENV_SH_FILE"
  sed -i "s/export STORAGE_FILESYSTEM_ENABLED=.*/export STORAGE_FILESYSTEM_ENABLED=false/g" "$ENV_SH_FILE"
  sed -i "s/export CREATE_TUNING_FOLDERS_FLAG=.*/export CREATE_TUNING_FOLDERS_FLAG=false/g" "$ENV_SH_FILE"
  sed -i "s|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=.*|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=/data|g" "$ENV_SH_FILE"
  
  # OAuth configuration for Keycloak
  sed -i "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" "$ENV_SH_FILE"
  sed -i "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" "$ENV_SH_FILE"
  sed -i "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio|g" "$ENV_SH_FILE"
  sed -i "s|export OAUTH_URL=.*|export OAUTH_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio/protocol/openid-connect/auth|g" "$ENV_SH_FILE"
  sed -i "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g" "$ENV_SH_FILE"
  
  # .env file updates
  sed -i "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g" "$ENV_FILE"
  sed -i "s|endpoint=.*|endpoint=https://minio.$OC_PROJECT.svc.cluster.local:9000|g" "$ENV_FILE"
  sed -i "s/region=.*/region=us-east-1/g" "$ENV_FILE"
  sed -i "s/pg_uri=.*/pg_uri=postgresql.$OC_PROJECT.svc.cluster.local/g" "$ENV_FILE"
fi

echo "✓ Set ROUTE_ENABLED=false (Lima uses standard Kubernetes, not OpenShift)"
echo "✓ Set ENVIRONMENT=local and CLUSTER_URL=localhost"
echo "✓ Configured storage classes (COS: cos-s3-csi-s3fs-sc, Local: local-path)"
echo "✓ Configured OAuth for Keycloak integration"
echo "✓ Set OAuth proxy port to 4180"
echo "✓ Configured MinIO endpoint and region"
echo "✓ Configured PostgreSQL URI"

# Step 3: Merge .studio-api-key if it exists
echo ""
echo "Step 3/7: Checking for .studio-api-key..."
if [ -f "$STUDIO_API_KEY_FILE" ]; then
  echo "✓ Found $STUDIO_API_KEY_FILE"
  
  # Source it to get the keys
  source "$STUDIO_API_KEY_FILE"
  
  # Update .env file if keys are empty
  if grep -q "studio_api_key=$" "$ENV_FILE" 2>/dev/null; then
    echo "  → Updating studio_api_key in .env"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s|studio_api_key=.*|studio_api_key=${STUDIO_API_KEY}|g" "$ENV_FILE"
    else
      sed -i "s|studio_api_key=.*|studio_api_key=${STUDIO_API_KEY}|g" "$ENV_FILE"
    fi
  fi
  
  if grep -q "studio_api_encryption_key=$" "$ENV_FILE" 2>/dev/null; then
    echo "  → Updating studio_api_encryption_key in .env"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s|studio_api_encryption_key=.*|studio_api_encryption_key=${API_ENCRYPTION_KEY}|g" "$ENV_FILE"
    else
      sed -i "s|studio_api_encryption_key=.*|studio_api_encryption_key=${API_ENCRYPTION_KEY}|g" "$ENV_FILE"
    fi
  fi
else
  echo "  (not found - will use values from .env)"
fi

# Step 4: Source environment files
echo ""
echo "Step 4/7: Loading environment configuration..."
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Error: Environment file not found: $ENV_FILE"
  echo ""
  echo "This should have been created by setup-workspace-env.sh"
  echo "Please check the workspace setup process"
  exit 1
fi

if [ ! -f "$ENV_SH_FILE" ]; then
  echo "❌ Error: Environment shell file not found: $ENV_SH_FILE"
  exit 1
fi

echo "✓ Sourcing $ENV_FILE"
# Source .env and export all variables
set -a
source "$ENV_FILE"
set +a

echo "✓ Sourcing $ENV_SH_FILE"
source "$ENV_SH_FILE"

# Step 5: Validate required variables
echo ""
echo "Step 5/7: Validating required variables..."

REQUIRED_VARS=(
  "ocp_project"
  "studio_api_key"
  "access_key_id"
  "secret_access_key"
  "pg_password"
  "pg_username"
  "redis_password"
  "oauth_client_secret"
  "oauth_cookie_secret"
  "geoserver_username"
  "geoserver_password"
  "keycloak_admin_user"
  "keycloak_admin_password"
)

MISSING_VARS=()
EMPTY_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var+x}" ]]; then
    MISSING_VARS+=("$var")
  elif [[ -z "${!var}" ]]; then
    EMPTY_VARS+=("$var")
  fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo "❌ Missing required environment variables:"
  printf '  - %s\n' "${MISSING_VARS[@]}"
  echo ""
  echo "These variables must be defined in $ENV_FILE"
  exit 1
fi

if [[ ${#EMPTY_VARS[@]} -gt 0 ]]; then
  echo "⚠️  Warning: The following variables are empty:"
  printf '  - %s\n' "${EMPTY_VARS[@]}"
  echo ""
  echo "Please edit $ENV_FILE with your actual values"
  echo ""
  read -p "Continue anyway? (y/N): " CONTINUE
  if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo "✓ All required variables are set"

# Check for default/weak passwords (security warning)
DEFAULT_PASSWORDS=()
if [[ "${redis_password}" == "devPassword" ]]; then
  DEFAULT_PASSWORDS+=("redis_password=devPassword")
fi
if [[ "${keycloak_admin_password}" == "admin" ]]; then
  DEFAULT_PASSWORDS+=("keycloak_admin_password=admin")
fi
if [[ "${pg_password}" == "devPostgresql123" ]]; then
  DEFAULT_PASSWORDS+=("pg_password=devPostgresql123")
fi

if [[ ${#DEFAULT_PASSWORDS[@]} -gt 0 ]] && [[ "$ENVIRONMENT" != "local" ]]; then
  echo ""
  echo "🔐 SECURITY WARNING: Default passwords detected!"
  printf '  - %s\n' "${DEFAULT_PASSWORDS[@]}"
  echo ""
  echo "These are DEVELOPMENT defaults and should NOT be used in production."
  echo "Generate secure passwords with:"
  echo "  openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n'"
  echo ""
  
  if [[ "$ENVIRONMENT" == "production" ]]; then
    read -p "⚠️  Continue with default passwords in PRODUCTION? (yes/no): " CONTINUE_PROD
    if [[ "$CONTINUE_PROD" != "yes" ]]; then
      echo "Aborted. Please update passwords in $ENV_FILE"
      exit 1
    fi
  else
    read -p "Continue with default passwords? (y/N): " CONTINUE_DEFAULT
    if [[ "$CONTINUE_DEFAULT" != "y" && "$CONTINUE_DEFAULT" != "Y" ]]; then
      echo "Aborted. Please update passwords in $ENV_FILE"
      exit 1
    fi
  fi
fi

# Show optional variables status
OPTIONAL_VARS=("sh_client_id" "sh_client_secret" "nasa_earth_data_bearer_token")
OPTIONAL_SET=()
for var in "${OPTIONAL_VARS[@]}"; do
  if [[ -n "${!var}" ]]; then
    OPTIONAL_SET+=("$var")
  fi
done

if [[ ${#OPTIONAL_SET[@]} -gt 0 ]]; then
  echo "✓ Optional data provider credentials configured:"
  printf '  - %s\n' "${OPTIONAL_SET[@]}"
fi

# Step 5: Generate operator CR from template
echo ""
echo "Step 6/7: Generating GEOStudio operator CR..."

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Generate from template
if ! envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"; then
  echo "❌ Error: Failed to generate manifest from template"
  exit 1
fi

echo "✓ Generated: $OUTPUT_FILE"

# Check for unsubstituted variables
UNSUBSTITUTED=$(grep -o '\${[^}]*}' "$OUTPUT_FILE" || true)
if [[ -n "$UNSUBSTITUTED" ]]; then
  echo ""
  echo "⚠️  Warning: Found unsubstituted variables in generated manifest:"
  echo "$UNSUBSTITUTED" | sort -u | head -10
  echo ""
  echo "These variables may not be exported in your environment"
  echo "Check $ENV_FILE and $ENV_SH_FILE"
  echo ""
fi

# Dry-run mode
if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "=============================================================================="
  echo "                         DRY RUN MODE"
  echo "=============================================================================="
  echo ""
  echo "Generated manifest saved to:"
  echo "  $OUTPUT_FILE"
  echo ""
  echo "To review the manifest:"
  echo "  cat $OUTPUT_FILE"
  echo ""
  echo "To apply manually:"
  echo "  kubectl apply -f $OUTPUT_FILE"
  echo ""
  exit 0
fi

# Apply to cluster
echo ""
echo "Step 7/7: Applying to Kubernetes cluster..."

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
  echo "❌ Error: Cannot connect to Kubernetes cluster"
  echo "Please check your kubeconfig"
  exit 1
fi

# Apply the manifest
if kubectl apply -f "$OUTPUT_FILE"; then
  echo ""
  echo "=============================================================================="
  echo "                   ✅ GEOStudio Deployment Submitted"
  echo "=============================================================================="
  echo ""
  echo "Monitor deployment status:"
  echo "  kubectl get geostudios -n ${ocp_project}"
  echo "  kubectl describe geostudio studio -n ${ocp_project}"
  echo ""
  echo "Monitor pod status:"
  echo "  kubectl get pods -n ${ocp_project}"
  echo "  kubectl get pods -n ${ocp_project} -w"
  echo ""
  echo "Check operator logs:"
  echo "  kubectl logs -n geostudio-operators-system deployment/geostudio-operators-controller-manager -f"
  echo ""
  echo "Generated manifest saved to:"
  echo "  $OUTPUT_FILE"
  echo ""
else
  echo ""
  echo "❌ Error: Failed to apply manifest to cluster"
  echo ""
  echo "Check the generated manifest:"
  echo "  cat $OUTPUT_FILE"
  echo ""
  echo "Validate with kubectl:"
  echo "  kubectl apply --dry-run=client -f $OUTPUT_FILE"
  echo ""
  exit 1
fi
