#!/bin/bash
set -e

# Build and Push Operator Image
# Usage:
#   ./build-operator-lima.sh           # Build for local Lima registry
#   ./build-operator-lima.sh --prod    # Build and push to quay.io

# Configuration
IMAGE_NAME="geostudio-operator"
QUAY_ORG="geospatial-studio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
MODE="local"
if [[ "$1" == "--prod" ]]; then
  MODE="prod"
fi

# Set image details based on mode
if [[ "$MODE" == "prod" ]]; then
  IMAGE_TAG="${2:-latest}"
  FULL_IMAGE="quay.io/${QUAY_ORG}/${IMAGE_NAME}:${IMAGE_TAG}"
  DOCKERFILE="Dockerfile.operator"
else
  IMAGE_TAG="local"
  FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
  DOCKERFILE="Dockerfile.operator.local"
fi

echo "=========================================="
echo "Building Operator Image"
echo "=========================================="
echo "Mode: $MODE"
echo "Image: $FULL_IMAGE"
echo "Dockerfile: $DOCKERFILE"
echo "=========================================="
echo ""

if [[ "$MODE" == "prod" ]]; then
  # Production mode: Build and push to quay.io
  
  # Confirm push to production
  echo "⚠️  WARNING: You are about to push to quay.io"
  echo "Image: $FULL_IMAGE"
  echo ""
  read -p "Are you sure you want to continue? (yes/no): " CONFIRM
  
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi
  
  echo ""
  echo "Checking quay.io login status..."
  if ! docker login quay.io --get-login > /dev/null 2>&1; then
    echo "❌ Not logged in to quay.io"
    echo "Please run: docker login quay.io"
    exit 1
  fi
  echo "✅ Logged in to quay.io"
  
  # Build the image
  echo ""
  echo "Building Docker image..."
  cd "$SCRIPT_DIR"
  docker build -f "$DOCKERFILE" -t "$FULL_IMAGE" .
  
  # Push to quay.io
  echo ""
  echo "Pushing image to quay.io..."
  docker push "$FULL_IMAGE"
  
  echo ""
  echo "=========================================="
  echo "✅ Image built and pushed to quay.io!"
  echo "=========================================="
  echo ""
  echo "Image: $FULL_IMAGE"
  echo ""
  
else
  # Local mode: Build and load into Lima
  
  echo "1. Building Docker image on host..."
  cd "$SCRIPT_DIR"
  docker build --load -f "$DOCKERFILE" -t "$FULL_IMAGE" .
  
  # Step 2: Save image to tar
  echo ""
  echo "2. Saving image to tar..."
  docker save "$FULL_IMAGE" -o /tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar
  
  # Step 3: Copy tar to Lima
  echo ""
  echo "3. Copying image to Lima VM..."
  limactl copy /tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar studio:/tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar
  
  # Step 4: Import image in Lima
  echo ""
  echo "4. Importing image into Lima containerd..."
  limactl shell studio sudo ctr -n k8s.io images import /tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar
  
  # Step 5: Verify image is available
  echo ""
  echo "5. Verifying image in Lima..."
  limactl shell studio sudo ctr -n k8s.io images ls | grep ${IMAGE_NAME}
  
  # Cleanup
  echo ""
  echo "6. Cleaning up temporary files..."
  rm -f /tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar
  limactl shell studio rm -f /tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar
  
  echo ""
  echo "=========================================="
  echo "✅ Image ready in Lima!"
  echo "=========================================="
  echo ""
  echo "Image: $FULL_IMAGE"
  echo ""
  echo "To use in Kubernetes:"
  echo "  imagePullPolicy: Never"
  echo "  image: $FULL_IMAGE"
  echo ""
fi
