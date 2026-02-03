#!/bin/bash
# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
#
# Script to deploy the image pre-puller DaemonSet with progress monitoring
# This script handles low bandwidth scenarios by monitoring progress without strict timeouts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${NAMESPACE:-default}"
DAEMONSET_NAME="geostudio-image-prepuller"
YAML_FILE="${1:-./deployment-scripts/images-pre-puller/image-prepuller-daemonset.yaml}"
CHECK_INTERVAL=10  # Check progress every 10 seconds
MAX_WAIT_TIME=7200  # Maximum wait time: 2 hours (for low bandwidth)

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

# Function to check if YAML file exists
check_yaml_file() {
    if [ ! -f "$YAML_FILE" ]; then
        print_error "YAML file '$YAML_FILE' not found"
        exit 1
    fi
    print_success "YAML file '$YAML_FILE' found"
}

# Function to update namespace in YAML
update_namespace() {
    print_info "Updating namespace in YAML file..."
    sed -i.bak "s/namespace: OC_PROJECT/namespace: $NAMESPACE/g" "$YAML_FILE"
    print_success "Namespace updated to '$NAMESPACE'"
}

# Function to deploy DaemonSet
deploy_daemonset() {
    print_info "Deploying DaemonSet '$DAEMONSET_NAME'..."
    
    if kubectl get daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_warning "DaemonSet already exists. Deleting old version..."
        kubectl delete daemonset "$DAEMONSET_NAME" -n "$NAMESPACE" --wait=true
        sleep 5
    fi
    
    kubectl apply -f "$YAML_FILE"
    print_success "DaemonSet deployed"
}

# Function to get worker node count
get_worker_node_count() {
    kubectl get nodes -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' --no-headers 2>/dev/null | wc -l | tr -d ' '
}

# Function to get pod status
get_pod_status() {
    kubectl get pods -n "$NAMESPACE" -l name="$DAEMONSET_NAME" --no-headers 2>/dev/null || echo ""
}

# Function to get detailed pod progress
get_pod_progress() {
    local pod_name=$1
    local init_containers=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.initContainerStatuses[*].name}' 2>/dev/null || echo "")
    local init_ready=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.initContainerStatuses[*].ready}' 2>/dev/null || echo "")
    
    if [ -z "$init_containers" ]; then
        echo "0/11"
        return
    fi
    
    local total=11
    local ready_count=$(echo "$init_ready" | tr ' ' '\n' | grep -c "true" || echo "0")
    echo "$ready_count/$total"
}

# Function to monitor progress
monitor_progress() {
    print_info "Monitoring image pre-pull progress..."
    print_info "This may take a while depending on your network bandwidth..."
    echo ""
    
    local worker_count=$(get_worker_node_count)
    print_info "Worker nodes detected: $worker_count"
    
    if [ "$worker_count" -eq 0 ]; then
        print_error "No worker nodes found. DaemonSet will not schedule any pods."
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
        local total_pods=$(echo "$pod_status" | wc -l | tr -d ' ')
        local running_pods=$(echo "$pod_status" | grep -c "Running" || echo "0")
        local pending_pods=$(echo "$pod_status" | grep -c "Pending" || echo "0")
        local failed_pods=$(echo "$pod_status" | grep -c -E "Error|CrashLoopBackOff|ImagePullBackOff" || echo "0")
        
        # Get detailed progress for each pod
        local current_status="Pods: $running_pods/$total_pods Running, $pending_pods Pending"
        
        if [ "$current_status" != "$last_status" ]; then
            echo -e "\n${BLUE}[$(date '+%H:%M:%S')]${NC} $current_status"
            
            # Show progress for each pod
            while IFS= read -r line; do
                local pod_name=$(echo "$line" | awk '{print $1}')
                local pod_state=$(echo "$line" | awk '{print $3}')
                local node_name=$(echo "$line" | awk '{print $7}')
                
                if [ "$pod_state" = "Running" ]; then
                    local progress=$(get_pod_progress "$pod_name")
                    echo "  ├─ $node_name: $progress images pulled"
                elif [ "$pod_state" = "Pending" ]; then
                    echo "  ├─ $node_name: Initializing..."
                fi
            done <<< "$pod_status"
            
            last_status="$current_status"
        fi
        
        # Check if all pods are running (all init containers completed)
        if [ "$running_pods" -eq "$worker_count" ] && [ "$pending_pods" -eq 0 ]; then
            # Verify all init containers are complete
            local all_complete=true
            while IFS= read -r line; do
                local pod_name=$(echo "$line" | awk '{print $1}')
                local progress=$(get_pod_progress "$pod_name")
                if [ "$progress" != "11/11" ]; then
                    all_complete=false
                    break
                fi
            done <<< "$pod_status"
            
            if [ "$all_complete" = true ]; then
                echo ""
                print_success "All images successfully pulled on all worker nodes!"
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

# Function to show summary
show_summary() {
    echo ""
    echo "=========================================="
    print_info "Image Pre-Pull Summary"
    echo "=========================================="
    
    local pod_status=$(get_pod_status)
    echo "$pod_status"
    
    echo ""
    print_info "To check detailed status:"
    echo "  kubectl get pods -n $NAMESPACE -l name=$DAEMONSET_NAME -o wide"
    
    echo ""
    print_info "To view logs from a specific pod:"
    echo "  kubectl logs -n $NAMESPACE <pod-name> -c <container-name>"
    
    echo ""
    print_info "To cleanup the DaemonSet:"
    echo "  ./cleanup-image-prepuller.sh"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    echo "  Geospatial Studio Image Pre-Puller"
    echo "=========================================="
    echo ""
    
    check_kubectl
    check_yaml_file
    check_namespace
    update_namespace
    deploy_daemonset
    
    echo ""
    print_info "Waiting for pods to start..."
    sleep 5
    
    if monitor_progress; then
        show_summary
        exit 0
    else
        show_summary
        exit 1
    fi
}

# Run main function
main
