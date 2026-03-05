#!/bin/bash
# ==============================================================================
# GeoStudio Common Library
# ==============================================================================
# Shared utilities and functions used across all GeoStudio CLI commands
#
# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# ==============================================================================
# Color Constants
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# ==============================================================================
# Logging Functions
# ==============================================================================

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

log_step() {
  echo ""
  echo -e "${BLUE}==>${NC} $1"
}

# ==============================================================================
# User Interaction
# ==============================================================================

confirm() {
  local prompt="$1"
  if [ "$DRY_RUN" = true ]; then
    return 0
  fi
  read -p "$prompt (y/N): " response
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
    "$@"
  fi
}

# ==============================================================================
# Script Path Resolution
# ==============================================================================

resolve_script_paths() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  PROJECT_ROOT="$SCRIPT_DIR/.."
  LIB_DIR="$SCRIPT_DIR/lib"
}

# ==============================================================================
# Prerequisites Checking
# ==============================================================================

require_command() {
  local cmd=$1
  local install_hint=${2:-""}
  
  if ! command -v "$cmd" &> /dev/null; then
    log_error "$cmd is not installed or not in PATH"
    if [[ -n "$install_hint" ]]; then
      echo ""
      echo "$install_hint"
      echo ""
    fi
    return 1
  fi
  return 0
}

check_kubectl_connection() {
  if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    log_error "Check your kubeconfig and cluster connection"
    return 1
  fi
  return 0
}

# ==============================================================================
# Kubernetes Utilities
# ==============================================================================

resource_exists() {
  local resource_type=$1
  local resource_name=$2
  local namespace=${3:-""}
  
  local ns_flag=""
  [[ -n "$namespace" ]] && ns_flag="-n $namespace"
  
  kubectl get "$resource_type" "$resource_name" $ns_flag &> /dev/null
  return $?
}

wait_for_resource_deletion() {
  local resource=$1
  local namespace=$2
  local timeout=${3:-60}
  
  kubectl wait --for=delete "$resource" -n "$namespace" --timeout="${timeout}s" 2>/dev/null || true
}

# ==============================================================================
# Cross-Platform sed Wrapper
# ==============================================================================

sed_inplace() {
  local file=$1
  shift
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@" "$file"
  else
    sed -i "$@" "$file"
  fi
}

# ==============================================================================
# Help Display
# ==============================================================================

show_help_from_header() {
  local script=$1
  head -50 "$script" | grep "^#" | sed 's/^# \?//'
}
