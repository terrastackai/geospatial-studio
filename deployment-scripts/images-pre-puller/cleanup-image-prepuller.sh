#!/bin/bash
# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
#
# Script to cleanup the image pre-puller DaemonSet
# This script safely removes the DaemonSet and optionally cleans up pulled images

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${NAMESPACE:-OC_PROJECT}"
DAEMONSET_NAME="geostudio-image-prepuller"
YAML_FILE="${1:-image-prepuller-daemonset.yaml}"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
}

# Function to check if DaemonSet exists
check_daemonset_exists() {
    if kubectl get daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to get pod count
get_pod_count() {
    kubectl get pods -n "$NAMESPACE" -l name="$DAEMONSET_NAME" --no-headers 2>/dev/null | wc -l | tr -d ' '
}

# Function to delete DaemonSet
delete_daemonset() {
    print_info "Deleting DaemonSet '$DAEMONSET_NAME' in namespace '$NAMESPACE'..."
    
    if check_daemonset_exists; then
        kubectl delete daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" --wait=false
        print_success "DaemonSet deletion initiated"
    else
        print_warning "DaemonSet '$DAEMONSET_NAME' not found in namespace '$NAMESPACE'"
        return 1
    fi
}

# Function to wait for pods to terminate
wait_for_pod_termination() {
    print_info "Waiting for pods to terminate..."
    
    local max_wait=120  # 2 minutes
    local elapsed=0
    local check_interval=5
    
    while [ $elapsed -lt $max_wait ]; do
        local pod_count=$(get_pod_count)
        
        if [ "$pod_count" -eq 0 ]; then
            print_success "All pods terminated"
            return 0
        fi
        
        echo -ne "\r  Remaining pods: $pod_count (waiting ${elapsed}s/${max_wait}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    echo ""
    print_warning "Timeout waiting for pods to terminate"
    print_info "Remaining pods:"
    kubectl get pods -n "$NAMESPACE" -l name="$DAEMONSET_NAME" 2>/dev/null || true
    return 1
}

# Function to force delete stuck pods
force_delete_pods() {
    print_warning "Force deleting remaining pods..."
    
    local pods=$(kubectl get pods -n "$NAMESPACE" -l name="$DAEMONSET_NAME" --no-headers 2>/dev/null | awk '{print $1}')
    
    if [ -z "$pods" ]; then
        print_info "No pods to force delete"
        return 0
    fi
    
    for pod in $pods; do
        print_info "Force deleting pod: $pod"
        kubectl delete pod "$pod" -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    done
    
    sleep 5
    
    local remaining=$(get_pod_count)
    if [ "$remaining" -eq 0 ]; then
        print_success "All pods force deleted"
        return 0
    else
        print_error "Failed to delete all pods. Manual intervention may be required."
        return 1
    fi
}

# Function to optionally remove pulled images from nodes
remove_images_from_nodes() {
    print_warning "Image removal from nodes is not automated for safety reasons."
    print_info "Images remain cached on nodes and will be used by future deployments."
    print_info "This is the desired behavior for pre-pulling."
    echo ""
    print_info "If you need to remove images manually, you can:"
    echo "  1. SSH into each worker node"
    echo "  2. Run: docker image prune -a --filter 'label=app=geostudio-image-prepuller'"
    echo "     OR: crictl rmi <image-id> (for containerd runtime)"
    echo ""
    print_warning "Only remove images if you're sure they're not needed!"
}

# Function to cleanup backup files
cleanup_backup_files() {
    if [ -f "${YAML_FILE}.bak" ]; then
        print_info "Removing backup file: ${YAML_FILE}.bak"
        rm -f "${YAML_FILE}.bak"
        print_success "Backup file removed"
    fi
}

# Function to show cleanup summary
show_summary() {
    echo ""
    echo "=========================================="
    print_info "Cleanup Summary"
    echo "=========================================="
    
    if check_daemonset_exists; then
        print_warning "DaemonSet still exists (may be terminating)"
    else
        print_success "DaemonSet removed"
    fi
    
    local pod_count=$(get_pod_count)
    if [ "$pod_count" -eq 0 ]; then
        print_success "All pods terminated"
    else
        print_warning "Pods still running: $pod_count"
    fi
    
    echo ""
    print_info "Pulled images remain cached on worker nodes for future use"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    echo "  Geospatial Studio Image Pre-Puller"
    echo "  Cleanup Script"
    echo "=========================================="
    echo ""
    
    check_kubectl
    
    # Check if DaemonSet exists
    if ! check_daemonset_exists; then
        print_warning "DaemonSet '$DAEMONSET_NAME' not found in namespace '$NAMESPACE'"
        print_info "Nothing to cleanup"
        exit 0
    fi
    
    # Show current status
    print_info "Current DaemonSet status:"
    kubectl get daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    
    print_info "Current pod status:"
    kubectl get pods -n "$NAMESPACE" -l name="$DAEMONSET_NAME" 2>/dev/null || true
    echo ""
    
    # Confirm deletion
    read -p "Do you want to delete the DaemonSet? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleanup cancelled"
        exit 0
    fi
    
    # Delete DaemonSet
    if delete_daemonset; then
        # Wait for pods to terminate
        if ! wait_for_pod_termination; then
            read -p "Force delete remaining pods? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                force_delete_pods
            fi
        fi
    fi
    
    # Cleanup backup files
    cleanup_backup_files
    
    # Show information about images
    remove_images_from_nodes
    
    # Show summary
    show_summary
    
    print_success "Cleanup completed"
}

# Run main function
main
