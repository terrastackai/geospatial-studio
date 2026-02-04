#!/bin/bash
# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
#
# Script to deploy the image pre-puller DaemonSet with automatic cluster detection
# Automatically selects the appropriate YAML based on cluster topology

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${NAMESPACE:-default}"
DAEMONSET_NAME="geostudio-image-prepuller"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_YAML="$SCRIPT_DIR/image-prepuller.yaml"
CHECK_INTERVAL=10
MAX_WAIT_TIME=7200  # 2 hours for low bandwidth
AUTO_CLEANUP="${AUTO_CLEANUP:-true}"  # Set to false to keep DaemonSet running

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

print_highlight() {
    echo -e "${CYAN}[CLUSTER]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl is available"
}

# Function to check if namespace exists
check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "Namespace '$NAMESPACE' does not exist. Creating it..."
        kubectl create namespace "$NAMESPACE"
        print_success "Namespace '$NAMESPACE' created"
    else
        print_success "Namespace '$NAMESPACE' exists"
    fi
}

# Function to detect cluster type and prepare configuration
detect_cluster_topology() {
    print_info "Detecting cluster topology..."
    
    # Get total node count
    local total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    # Get worker node count (nodes without control-plane role)
    local worker_nodes=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    # Get control plane node count
    local control_plane_nodes=$(kubectl get nodes -l 'node-role.kubernetes.io/control-plane' --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    echo ""
    print_highlight "Cluster Analysis:"
    echo "  Total nodes: $total_nodes"
    echo "  Control plane nodes: $control_plane_nodes"
    echo "  Worker nodes: $worker_nodes"
    echo ""
    
    # Check if template exists
    if [ ! -f "$TEMPLATE_YAML" ]; then
        print_error "Template YAML file '$TEMPLATE_YAML' not found"
        exit 1
    fi
    
    # Decision logic
    if [ "$worker_nodes" -eq 0 ]; then
        # Single-node cluster (all nodes are control plane)
        print_highlight "Detected: Single-node cluster (Minikube/Kind/Docker Desktop)"
        print_info "Will deploy to ALL nodes (including control plane)"
        CLUSTER_TYPE="single-node"
        TARGET_NODE_COUNT=$total_nodes
        NODE_AFFINITY_CONFIG="# No node affinity - run on all nodes including control plane"
    else
        # Multi-node cluster with dedicated workers
        print_highlight "Detected: Multi-node cluster with $worker_nodes worker node(s)"
        print_info "Will deploy to WORKER NODES ONLY (excluding control plane)"
        CLUSTER_TYPE="multi-node"
        TARGET_NODE_COUNT=$worker_nodes
        NODE_AFFINITY_CONFIG="affinity:\n        nodeAffinity:\n          requiredDuringSchedulingIgnoredDuringExecution:\n            nodeSelectorTerms:\n            - matchExpressions:\n              - key: node-role.kubernetes.io/control-plane\n                operator: DoesNotExist"
    fi
    
    echo ""
    print_success "Configuration prepared for $CLUSTER_TYPE cluster"
    print_info "Target nodes for image pre-pull: $TARGET_NODE_COUNT"
    echo ""
}

# Function to deploy DaemonSet
deploy_daemonset() {
    print_info "Deploying DaemonSet '$DAEMONSET_NAME'..."
    
    if kubectl get daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_warning "DaemonSet already exists. Deleting old version..."
        kubectl delete daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" --wait=true
        sleep 5
    fi
    
    # Apply YAML directly from stdin (no temporary files)
    sed "s|# NODE_AFFINITY_PLACEHOLDER|$NODE_AFFINITY_CONFIG|" "$TEMPLATE_YAML" | \
    sed "s/namespace: OC_PROJECT/namespace: $NAMESPACE/" | \
    kubectl apply -f -
    
    print_success "DaemonSet deployed"
}

# Function to get pod status
get_pod_status() {
    kubectl get pods -n "$NAMESPACE" -l name="$DAEMONSET_NAME" --no-headers 2>/dev/null || echo ""
}

# Function to get detailed pod progress
get_pod_progress() {
    local pod_name=$1
    
    # Get init container statuses - both completed and running
    local init_states=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{range .status.initContainerStatuses[*]}{.state}{"\n"}{end}' 2>/dev/null || echo "")
    
    if [ -z "$init_states" ]; then
        echo "0/14"
        return
    fi
    
    local total=14
    # Count completed (terminated with exitCode 0) and currently running containers
    local completed=$(echo "$init_states" | grep -c "exitCode.:0" 2>/dev/null | tr -d ' \n' || echo "0")
    local running=$(echo "$init_states" | grep -c "running" 2>/dev/null | tr -d ' \n' || echo "0")
    
    completed=${completed:-0}
    running=${running:-0}
    
    # If a container is running, count it as in-progress (completed + 1)
    local progress=$((completed + running))
    
    echo "$progress/$total"
}

# Function to monitor progress
monitor_progress() {
    print_info "Monitoring image pre-pull progress..."
    print_info "This may take a while depending on your network bandwidth..."
    echo ""
    
    if [ "$TARGET_NODE_COUNT" -eq 0 ]; then
        print_error "No target nodes found. Cannot proceed."
        exit 1
    fi
    
    local elapsed=0
    local last_status=""
    
    while [ $elapsed -lt $MAX_WAIT_TIME ]; do
        local pod_status=$(get_pod_status)
        
        if [ -z "$pod_status" ]; then
            print_warning "No pods found yet. Waiting..."
            sleep $CHECK_INTERVAL
            elapsed=$((elapsed + CHECK_INTERVAL))
            continue
        fi
        
        # Count pods in different states
        local total_pods=$(echo "$pod_status" | wc -l | tr -d ' \n')
        local running_pods=$(echo "$pod_status" | grep -c "Running" 2>/dev/null | tr -d ' \n' || echo "0")
        local init_pods=$(echo "$pod_status" | grep -c "PodInitializing\|Init:" 2>/dev/null | tr -d ' \n' || echo "0")
        local pending_pods=$(echo "$pod_status" | grep -c "Pending" 2>/dev/null | tr -d ' \n' || echo "0")
        local failed_pods=$(echo "$pod_status" | grep -c -E "Error|CrashLoopBackOff|ImagePullBackOff" 2>/dev/null | tr -d ' \n' || echo "0")
        
        # Ensure they are valid integers
        running_pods=${running_pods:-0}
        init_pods=${init_pods:-0}
        pending_pods=${pending_pods:-0}
        failed_pods=${failed_pods:-0}
        
        # Adjust counts - PodInitializing is a sub-state, not separate from Running/Pending
        local active_pods=$((init_pods + running_pods))
        
        # Get detailed progress for each pod to include in status
        local progress_summary=""
        while IFS= read -r line; do
            local pod_name=$(echo "$line" | awk '{print $1}')
            local progress=$(get_pod_progress "$pod_name")
            progress_summary="$progress"
            break  # Only need first pod for summary
        done <<< "$pod_status"
        
        # Get detailed progress for each pod
        local current_status="Pods: $active_pods/$total_pods Active ($init_pods pulling images, $running_pods complete), $pending_pods Pending - Progress: $progress_summary"
        
        if [ "$current_status" != "$last_status" ]; then
            echo -e "\n${BLUE}[$(date '+%H:%M:%S')]${NC} $current_status"
            
            # Show progress for each pod
            while IFS= read -r line; do
                local pod_name=$(echo "$line" | awk '{print $1}')
                local pod_state=$(echo "$line" | awk '{print $3}')
                local node_name=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "unknown")
                
                if [ "$pod_state" = "Running" ]; then
                    local progress=$(get_pod_progress "$pod_name")
                    echo "  ├─ $node_name: ✓ Complete ($progress images pulled)"
                elif [[ "$pod_state" =~ "Init:" ]] || [ "$pod_state" = "PodInitializing" ]; then
                    local progress=$(get_pod_progress "$pod_name")
                    echo "  ├─ $node_name: ⟳ Pulling images ($progress)"
                elif [ "$pod_state" = "Pending" ]; then
                    echo "  ├─ $node_name: ⏳ Starting..."
                fi
            done <<< "$pod_status"
            
            last_status="$current_status"
        fi
        
        # Check if all pods are running (all init containers completed)
        if [ "$running_pods" -eq "$TARGET_NODE_COUNT" ] && [ "$pending_pods" -eq 0 ]; then
            # Verify all init containers are complete
            local all_complete=true
            while IFS= read -r line; do
                local pod_name=$(echo "$line" | awk '{print $1}')
                local progress=$(get_pod_progress "$pod_name")
                if [ "$progress" != "14/14" ]; then
                    all_complete=false
                    break
                fi
            done <<< "$pod_status"
            
            if [ "$all_complete" = true ]; then
                echo ""
                print_success "All 14 images successfully pulled on all target nodes!"
                print_info "Total time: $((elapsed / 60)) minutes $((elapsed % 60)) seconds"
                return 0
            fi
        fi
        
        # Check for failed pods
        if [ "$failed_pods" -gt 0 ]; then
            echo ""
            print_error "Some pods failed. Checking logs..."
            kubectl get pods -n "$NAMESPACE" -l name="$DAEMONSET_NAME" | grep -E "Error|CrashLoopBackOff|ImagePullBackOff" || true
            print_warning "You may need to check pod logs for details"
        fi
        
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
    done
    
    print_error "Timeout reached after $((MAX_WAIT_TIME / 60)) minutes"
    print_warning "Some images may still be pulling. Check status with: kubectl get pods -n $NAMESPACE -l name=$DAEMONSET_NAME"
    return 1
}

# Function to cleanup DaemonSet after successful pull
cleanup_daemonset() {
    print_info "Cleaning up DaemonSet (images remain cached on nodes)..."
    
    if kubectl delete daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" --wait=true 2>/dev/null; then
        print_success "DaemonSet removed successfully"
        print_info "Images remain cached on nodes for fast deployment"
    else
        print_warning "Failed to delete DaemonSet (may already be deleted)"
    fi
}

# Function to show summary
show_summary() {
    echo ""
    echo "=========================================="
    print_info "Image Pre-Pull Summary"
    echo "=========================================="
    echo "Cluster Type: $CLUSTER_TYPE"
    echo "Target Nodes: $TARGET_NODE_COUNT"
    echo ""
    
    if kubectl get daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_info "DaemonSet Status:"
        kubectl get daemonset "$DAEMONSET_NAME" -n "$NAMESPACE"
        echo ""
        print_info "To manually cleanup the DaemonSet:"
        echo "  kubectl delete daemonset $DAEMONSET_NAME -n $NAMESPACE"
    else
        print_success "DaemonSet cleaned up"
        print_info "Images cached and ready for deployment"
    fi
    
    echo ""
    print_info "To check cached images on nodes:"
    echo "  kubectl get pods -n $NAMESPACE -l name=$DAEMONSET_NAME -o wide"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    echo "  Geospatial Studio Image Pre-Puller"
    echo "  Smart Cluster Detection"
    echo "=========================================="
    echo ""
    
    check_kubectl
    check_namespace
    detect_cluster_topology
    deploy_daemonset
    
    echo ""
    print_info "Waiting for pods to start..."
    sleep 5
    
    if monitor_progress; then
        # Auto-cleanup if enabled
        if [ "$AUTO_CLEANUP" = "true" ]; then
            echo ""
            cleanup_daemonset
        fi
        show_summary
        exit 0
    else
        show_summary
        exit 1
    fi
}

# Run main function
main

