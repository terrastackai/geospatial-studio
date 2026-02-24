#!/bin/bash
# ==============================================================================
# GeoStudio Build Commands
# ==============================================================================
# Build operator image for local or production use
#
# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
# ==============================================================================

# Source dependencies
if [ -z "$GREEN" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

# ==============================================================================
# Configuration
# ==============================================================================

IMAGE_NAME="geostudio-operator"
QUAY_ORG="geospatial-studio"

# ==============================================================================
# Build Command Router
# ==============================================================================

build_command() {
  if [ $# -eq 0 ]; then
    show_build_help
    exit 0
  fi
  
  local mode=""
  local version=""
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --local)
        mode="local"
        shift
        ;;
      --prod|--production)
        mode="prod"
        shift
        ;;
      --version)
        version="$2"
        shift 2
        ;;
      --help|-h|help)
        show_build_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_build_help
        exit 1
        ;;
    esac
  done
  
  # Validate mode
  if [ -z "$mode" ]; then
    log_error "Build mode not specified. Use --local or --prod"
    echo ""
    show_build_help
    exit 1
  fi
  
  # Execute build
  if [ "$mode" = "local" ]; then
    build_local
  elif [ "$mode" = "prod" ]; then
    build_prod "$version"
  fi
}

# ==============================================================================
# Local Build (Lima)
# ==============================================================================

build_local() {
  local image_tag="local"
  local full_image="${IMAGE_NAME}:${image_tag}"
  local dockerfile="$PROJECT_ROOT/Dockerfile.operator.local"
  
  log_step "Building Operator Image for Lima"
  echo "Mode:       local"
  echo "Image:      $full_image"
  echo "Dockerfile: $(basename $dockerfile)"
  echo ""
  
  # Step 1: Build Docker image
  log_info "1. Building Docker image on host..."
  cd "$PROJECT_ROOT"
  docker build --load -f "$dockerfile" -t "$full_image" .
  
  # Step 2: Save image to tar
  echo ""
  log_info "2. Saving image to tar..."
  docker save "$full_image" -o /tmp/${IMAGE_NAME}-${image_tag}.tar
  
  # Step 3: Copy tar to Lima
  echo ""
  log_info "3. Copying image to Lima VM..."
  limactl copy /tmp/${IMAGE_NAME}-${image_tag}.tar studio:/tmp/${IMAGE_NAME}-${image_tag}.tar
  
  # Step 4: Import image in Lima
  echo ""
  log_info "4. Importing image into Lima containerd..."
  limactl shell studio sudo ctr -n k8s.io images import /tmp/${IMAGE_NAME}-${image_tag}.tar
  
  # Step 5: Verify image is available
  echo ""
  log_info "5. Verifying image in Lima..."
  limactl shell studio sudo ctr -n k8s.io images ls | grep ${IMAGE_NAME}
  
  # Cleanup
  echo ""
  log_info "6. Cleaning up temporary files..."
  rm -f /tmp/${IMAGE_NAME}-${image_tag}.tar
  limactl shell studio rm -f /tmp/${IMAGE_NAME}-${image_tag}.tar
  
  echo ""
  log_success "Image ready in Lima!"
  echo ""
  echo "Image: $full_image"
  echo ""
  log_info "Next steps:"
  echo "  ./geostudio operator install --local"
}

# ==============================================================================
# Production Build (Quay.io)
# ==============================================================================

build_prod() {
  local version=${1:-latest}
  local full_image="quay.io/${QUAY_ORG}/${IMAGE_NAME}:${version}"
  local dockerfile="$PROJECT_ROOT/Dockerfile.operator"
  
  log_step "Building Operator Image for Production"
  echo "Mode:       production"
  echo "Image:      $full_image"
  echo "Dockerfile: $(basename $dockerfile)"
  echo ""
  
  # Confirm push to production
  log_warning "You are about to push to quay.io"
  echo "Image: $full_image"
  echo ""
  
  if ! confirm "Are you sure you want to continue?"; then
    log_info "Aborted"
    exit 0
  fi
  
  # Check quay.io login
  echo ""
  log_info "Checking quay.io login status..."
  if ! docker login quay.io --get-login > /dev/null 2>&1; then
    log_error "Not logged in to quay.io"
    echo ""
    echo "Please run: docker login quay.io"
    exit 1
  fi
  log_success "Logged in to quay.io"
  
  # Build the image
  echo ""
  log_info "Building Docker image..."
  cd "$PROJECT_ROOT"
  docker build -f "$dockerfile" -t "$full_image" .
  
  # Push to quay.io
  echo ""
  log_info "Pushing image to quay.io..."
  docker push "$full_image"
  
  echo ""
  log_success "Image built and pushed to quay.io!"
  echo ""
  echo "Image: $full_image"
  echo ""
  log_info "Next steps:"
  echo "  ./geostudio operator install --prod --version $version"
}

# ==============================================================================
# Help
# ==============================================================================

show_build_help() {
  cat << 'EOF'
GeoStudio CLI - Build Commands

USAGE:
  geostudio build <mode> [options]

MODES:
  --local              Build for local Lima development
  --prod               Build and push to quay.io registry

OPTIONS:
  --version VERSION    Specify version tag for production builds (default: latest)
  --help, -h           Show this help message

EXAMPLES:
  # Build for local development
  geostudio build --local
  
  # Build for production with version tag
  geostudio build --prod --version v1.0.0
  
  # Build for production (latest tag)
  geostudio build --prod

LOCAL BUILD WORKFLOW:
  1. Builds Docker image using Dockerfile.operator.local
  2. Saves image to tar file
  3. Copies tar to Lima VM
  4. Imports into Lima containerd
  5. Verifies image availability
  6. Cleans up temporary files

PRODUCTION BUILD WORKFLOW:
  1. Confirms you want to push to production
  2. Checks quay.io authentication
  3. Builds Docker image using Dockerfile.operator
  4. Pushes to quay.io registry

PREREQUISITES:
  Local:  Docker, Lima (limactl), Lima VM named 'studio'
  Prod:   Docker, authenticated to quay.io (docker login quay.io)

EOF
}
