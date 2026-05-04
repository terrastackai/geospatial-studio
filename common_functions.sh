#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0

# Shared_Functions
# get_user_input
get_user_input() {
    local prompt_msg="$1"
    local result_var_name="$2"
    local input=""

    # Check if NON_INTERACTIVE mode is enabled and variable is already set
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        # Get the current value of the variable
        input="${!result_var_name}"
        if [[ -n "$input" ]]; then
            echo "Non-interactive mode: Using $result_var_name=$input"
            eval "$result_var_name='$input'"
            return 0
        else
            echo "Error: NON_INTERACTIVE mode enabled but $result_var_name is not set"
            exit 1
        fi
    fi

    # Interactive mode
    while [[ -z "$input" ]]; do
        printf "%s\n" "$prompt_msg"

        read -r input

        if [[ -z "$input" ]]; then
            echo "Error: Input cannot be blank. Please try again."
        fi
    done
    eval "$result_var_name='$input'"
}


# get_menu_selection
get_menu_selection() {
    local prompt_msg="$1"
    local result_var_name="$2"
    local string_to_split="$3"
    local options=()
    IFS=' ' read -r -a options <<< "$string_to_split"
    local num_options=${#options[@]}
    local user_selection=1 # Start with default index 1
    local input=""

    # Check if NON_INTERACTIVE mode is enabled and variable is already set
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        local preset_value="${!result_var_name}"
        if [[ -n "$preset_value" ]]; then
            echo "Non-interactive mode: Using $result_var_name=$preset_value"
            eval "$result_var_name='$preset_value'"
            export "$result_var_name"
            return 0
        else
            # Use default (first option) if not set
            echo "Non-interactive mode: Using default option for $result_var_name: ${options[0]}"
            eval "$result_var_name='${options[0]}'"
            export "$result_var_name"
            return 0
        fi
    fi

    # Interactive mode
    printf "\n\n--- Selection Menu ---\n"

    # Display the numbered menu options
    for ((i = 0; i < num_options; i++)); do
        local option="${options[i]}"
        local display_index=$((i + 1))
        if [[ $i -eq 0 ]]; then
            echo "  $display_index) $option (Default)"
        else
            echo "  $display_index) $option"
        fi
    done
    echo "----------------------"

    # Loop until a valid selection is made
    while true; do
        printf "%s (1-%s, Default: 1): " "$prompt_msg" "$num_options"
        read -r input
        local READ_STATUS=$?
        if [[ $READ_STATUS -ne 0 ]]; then
            printf "\nError: Input reading failed (Status: $READ_STATUS). Exiting."
            return 1
        fi

        if [[ -z "$input" ]]; then
            user_selection=1 # Default choice is 1
            break # Exit the loop
        fi

        if [[ $input =~ ^[0-9]+$ ]]; then
            # Check if the number is within the valid range
            if [[ $input -ge 1 && $input -le $num_options ]]; then
                user_selection=$input
                break # Exit the loop with a valid selection
            else
                echo "Error: Selection '$input' is out of range (1 to $num_options). Please try again."
            fi
        else
            echo "Error: Invalid input. Please enter a number between 1 and $num_options."
        fi
    done

    local selected_index=$((user_selection - 1))

    local final_result="${options[selected_index]}"
    eval "$result_var_name='$final_result'"
    export "$result_var_name"

    echo "Selected option: **$final_result** (Index $user_selection)"
}


# kubectl_wait_with_retry
# Retries kubectl wait command with exponential backoff
# Usage: kubectl_wait_with_retry <max_attempts> <initial_delay> <kubectl_wait_args...>
# Example: kubectl_wait_with_retry 5 10 --for=condition=ready pod/postgresql-0 -n default --timeout=300s
kubectl_wait_with_retry() {
    local max_attempts="$1"
    local initial_delay="$2"
    shift 2
    local kubectl_args="$@"

    local attempt=1
    local delay=$initial_delay

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts: kubectl wait $kubectl_args"

        if eval "kubectl wait $kubectl_args"; then
            echo "kubectl wait succeeded on attempt $attempt"
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            echo "kubectl wait failed. Waiting ${delay}s before retry..."
            
            # Extract pod/resource info from kubectl_args for debugging
            echo ""
            echo "=== Debugging Information ==="
            
            # Try to extract namespace and label selector from args
            local namespace=$(echo "$kubectl_args" | grep -oP '(?<=-n |--namespace[= ])\S+' || echo "default")
            local label_selector=$(echo "$kubectl_args" | grep -oP '(?<=-l )\S+' || echo "")
            local pod_name=$(echo "$kubectl_args" | grep -oP 'pod/\S+' | cut -d'/' -f2 || echo "")
            
            if [[ -n "$label_selector" ]]; then
                echo "Pods matching label '$label_selector' in namespace '$namespace':"
                kubectl get pods -l "$label_selector" -n "$namespace" 2>/dev/null || true
                echo ""
                
                # Get detailed info for pods that are not ready
                local not_ready_pods=$(kubectl get pods -l "$label_selector" -n "$namespace" --no-headers 2>/dev/null | grep -v "Running\|Completed" | awk '{print $1}' || echo "")
                if [[ -n "$not_ready_pods" ]]; then
                    for pod in $not_ready_pods; do
                        echo "--- Describe pod: $pod ---"
                        kubectl describe pod "$pod" -n "$namespace" 2>/dev/null || true
                        echo ""
                        echo "--- Recent events for pod: $pod ---"
                        kubectl get events -n "$namespace" --field-selector involvedObject.name="$pod" --sort-by='.lastTimestamp' | tail -10 || true
                        echo ""
                    done
                fi
            elif [[ -n "$pod_name" ]]; then
                echo "Pod status for '$pod_name' in namespace '$namespace':"
                kubectl get pod "$pod_name" -n "$namespace" 2>/dev/null || true
                echo ""
                echo "--- Describe pod: $pod_name ---"
                kubectl describe pod "$pod_name" -n "$namespace" 2>/dev/null || true
                echo ""
                echo "--- Recent events for pod: $pod_name ---"
                kubectl get events -n "$namespace" --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp' | tail -10 || true
                echo ""
            fi
            
            echo "=== End Debugging Information ==="
            echo ""
            
            sleep $delay
            # Exponential backoff: double the delay for next attempt
            delay=$((delay * 2))
            attempt=$((attempt + 1))
        else
            echo "kubectl wait failed after $max_attempts attempts"
            return 1
        fi
    done
}

auto_indent_and_replace() {
  local template_file="$1"
  local var_name="$2"
  local content="$3"
  local output_file="$4"

  # find the line with the variable and extract its indentation
  local indent=$(grep "\$$var_name" "$template_file" | sed "s/\$$var_name.*//" | head -1)

  # Add indentation to all lines EXPECT the first line
  local indented_content=$(echo "$content" | awk -v indent="$indent" 'NR==1 {print; next} {print indent $0}')


  # Export and replace
  export "$var_name"="$indented_content"
  envsubst "\$$var_name" < "$template_file" > "$output_file"
}

check_deployment_and_prompt() {
    local workload_type=$1
    local workload_name=$2
    local namespace=$3
    local display_name=$4
    local deploy_var_name=$5
    
    local exists=false
    local prompt_workloads=("ibmcloud-object-storage-plugin" "geofm-geoserver", "minio")
    local should_prompt=false
    
    # Check if workload exists based on type
    if [[ "$workload_type" == "helm" ]]; then
        # Check if Helm release exists
        if helm status "$workload_name" -n "$namespace" &> /dev/null; then
            exists=true
        fi
    else
        # Check Kubernetes resources (deployment, statefulset, etc.)
        if kubectl get "$workload_type" "$workload_name" -n "$namespace" &> /dev/null; then
            exists=true
        elif [[ "$workload_type" == "deployment" ]]; then
            for prompt_workload in "${prompt_workloads[@]}"; do
                if [[ "$workload_name" == "$prompt_workload" ]]; then
                    should_prompt=true
                    break
                fi
            done

            if $should_prompt; then
                echo "⚠️  Do you want to deploy $display_name?"
                local options="Deploy Skip"
                typeset choice
                get_menu_selection \
                    "Deploy/Skip $display_name?" \
                    choice \
                    "$options"
                eval "$deploy_var_name='$choice'"
                return 0
            fi
        fi
    fi
    
    if $exists; then
        echo "⚠️  $display_name already exists"
        local options="Deploy Skip"
        typeset choice
        get_menu_selection \
            "Deploy/Redeploy $display_name?" \
            choice \
            "$options"
        eval "$deploy_var_name='$choice'"
    else
        echo "✓ $display_name: Will deploy (no existing $workload_type)"
        eval "$deploy_var_name='Deploy'"
    fi
}

# Helper function to export storage variables
export_storage_vars() {
    local size="$1"
    shift
    for var in "$@"; do
        export "$var"="$size"
    done
}

# Configure resource mode for all components
configure_resource_mode() {
    echo "***********************************************************************************"
    echo "----------------------  Configure Resource Mode  ----------------------------------"
    echo "***********************************************************************************"
    echo "Select resource allocation profile for MinIO, Keycloak, GeoServer, and PostgreSQL:"
    echo "  - dev: 8-14 cores, 22-32 GB RAM, 75-100 GB storage (default/development)"
    echo "  - low: 6-8 cores, 16-20 GB RAM, 50-75 GB storage (testing/PoC)"
    echo "  - medium: 21-32 cores, 62-84 GB RAM, 200-400 GB storage (production-light/enhanced performance)"
    echo "  - high: 31-52 cores, 104-156 GB RAM, 0.8-1.5 TB storage (production-heavy/high-performance workloads)"
    echo "  - xlarge: 42-74+ cores, 156-240+ GB RAM, 1.8-2.0+ TB storage (enterprise/maximum performance)"
    echo "  - custom: User-defined with manual resource configuration in env.sh"
    echo "***********************************************************************************"

    resource_mode_options="dev low medium high xlarge custom"
    typeset resource_mode
    get_menu_selection "Select resource mode" "resource_mode" "$resource_mode_options"

    export RESOURCE_MODE=$resource_mode
    echo "RESOURCE_MODE selected: **$RESOURCE_MODE**"

    if [[ "$RESOURCE_MODE" == "custom" ]]; then
        sed -i -e "s/export RESOURCE_MODE=.*/export RESOURCE_MODE=${RESOURCE_MODE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
        return 0
    fi

    # Set resources based on selected mode
    case $RESOURCE_MODE in
        low)
            # MinIO
            export MINIO_CPU_REQUEST="500m"
            export MINIO_CPU_LIMIT="1000m"
            export MINIO_MEMORY_REQUEST="512Mi"
            export MINIO_MEMORY_LIMIT="1Gi"
            export MINIO_STORAGE="30Gi"
            # Keycloak
            export KEYCLOAK_CPU_REQUEST="100m"
            export KEYCLOAK_CPU_LIMIT="500m"
            export KEYCLOAK_MEMORY_REQUEST="256Mi"
            export KEYCLOAK_MEMORY_LIMIT="512Mi"
            # GeoServer
            export GEOSERVER_CPU_REQUEST="null"
            export GEOSERVER_CPU_LIMIT="null"
            export GEOSERVER_MEMORY_REQUEST="null"
            export GEOSERVER_MEMORY_LIMIT="null"
            export GEOSERVER_STORAGE="2Gi"
            # PostgreSQL
            export POSTGRES_CPU_REQUEST="100m"
            export POSTGRES_CPU_LIMIT="500m"
            export POSTGRES_MEMORY_REQUEST="256Mi"
            export POSTGRES_MEMORY_LIMIT="512Mi"
            export POSTGRES_STORAGE="2Gi"
            # PgBouncer
            export PGBOUNCER_CPU_REQUEST="250m"
            export PGBOUNCER_CPU_LIMIT="1000m"
            export PGBOUNCER_MEMORY_REQUEST="256Mi"
            export PGBOUNCER_MEMORY_LIMIT="1Gi"
            # MLflow
            export MLFLOW_CPU_REQUEST="null"
            export MLFLOW_CPU_LIMIT="null"
            export MLFLOW_MEMORY_REQUEST="null"
            export MLFLOW_MEMORY_LIMIT="null"
            # Redis Master
            export REDIS_MASTER_CPU_REQUEST="null"
            export REDIS_MASTER_CPU_LIMIT="null"
            export REDIS_MASTER_MEMORY_REQUEST="null"
            export REDIS_MASTER_MEMORY_LIMIT="null"
            # Redis Replica
            export REDIS_REPLICA_CPU_REQUEST="null"
            export REDIS_REPLICA_CPU_LIMIT="null"
            export REDIS_REPLICA_MEMORY_REQUEST="null"
            export REDIS_REPLICA_MEMORY_LIMIT="null"
            # Gateway API
            export GATEWAY_API_CPU_REQUEST="null"
            export GATEWAY_API_CPU_LIMIT="null"
            export GATEWAY_API_MEMORY_REQUEST="null"
            export GATEWAY_API_MEMORY_LIMIT="null"
            # Gateway Celery Worker
            export GATEWAY_CELERY_WORKER_CPU_REQUEST="null"
            export GATEWAY_CELERY_WORKER_CPU_LIMIT="null"
            export GATEWAY_CELERY_WORKER_MEMORY_REQUEST="null"
            export GATEWAY_CELERY_WORKER_MEMORY_LIMIT="null"
            # Gateway OAuth
            export GATEWAY_OAUTH_CPU_REQUEST="null"
            export GATEWAY_OAUTH_CPU_LIMIT="null"
            export GATEWAY_OAUTH_MEMORY_REQUEST="null"
            export GATEWAY_OAUTH_MEMORY_LIMIT="null"
            # UI OAuth
            export UI_OAUTH_CPU_REQUEST="null"
            export UI_OAUTH_CPU_LIMIT="null"
            export UI_OAUTH_MEMORY_REQUEST="null"
            export UI_OAUTH_MEMORY_LIMIT="null"
            # UI
            export UI_CPU_REQUEST="null"
            export UI_CPU_LIMIT="null"
            export UI_MEMORY_REQUEST="null"
            export UI_MEMORY_LIMIT="null"
            # Studio
            export GFM_FT_DATA_STORAGE="10Gi"
            export_storage_vars "5Gi" \
                GFM_FT_FILES_STORAGE \
                GFM_FT_MODELS_STORAGE \
                INFERENCE_SHARED_STORAGE
            export_storage_vars "1Gi" \
                GFM_MLFLOW_STORAGE \
                INFERENCE_AUXDATA_STORAGE \
                GENERIC_PYTHON_PROCESSOR_STORAGE \
                REDIS_MASTER_STORAGE \
                REDIS_REPLICAS_STORAGE
            ;;
        dev)
            # MinIO
            export MINIO_CPU_REQUEST="2000m"
            export MINIO_CPU_LIMIT="4000m"
            export MINIO_MEMORY_REQUEST="2Gi"
            export MINIO_MEMORY_LIMIT="4Gi"
            export MINIO_STORAGE="40Gi"
            # Keycloak
            export KEYCLOAK_CPU_REQUEST="250m"
            export KEYCLOAK_CPU_LIMIT="1000m"
            export KEYCLOAK_MEMORY_REQUEST="512Mi"
            export KEYCLOAK_MEMORY_LIMIT="1Gi"
            # GeoServer
            export GEOSERVER_CPU_REQUEST="null"
            export GEOSERVER_CPU_LIMIT="null"
            export GEOSERVER_MEMORY_REQUEST="null"
            export GEOSERVER_MEMORY_LIMIT="null"
            export GEOSERVER_STORAGE="2Gi"
            # PostgreSQL
            export POSTGRES_CPU_REQUEST="250m"
            export POSTGRES_CPU_LIMIT="1000m"
            export POSTGRES_MEMORY_REQUEST="512Mi"
            export POSTGRES_MEMORY_LIMIT="1Gi"
            export POSTGRES_STORAGE="2Gi"
            # PgBouncer
            export PGBOUNCER_CPU_REQUEST="250m"
            export PGBOUNCER_CPU_LIMIT="1000m"
            export PGBOUNCER_MEMORY_REQUEST="256Mi"
            export PGBOUNCER_MEMORY_LIMIT="1Gi"
            # MLflow
            export MLFLOW_CPU_REQUEST="null"
            export MLFLOW_CPU_LIMIT="null"
            export MLFLOW_MEMORY_REQUEST="null"
            export MLFLOW_MEMORY_LIMIT="null"
            # Redis Master
            export REDIS_MASTER_CPU_REQUEST="null"
            export REDIS_MASTER_CPU_LIMIT="null"
            export REDIS_MASTER_MEMORY_REQUEST="null"
            export REDIS_MASTER_MEMORY_LIMIT="null"
            # Redis Replica
            export REDIS_REPLICA_CPU_REQUEST="null"
            export REDIS_REPLICA_CPU_LIMIT="null"
            export REDIS_REPLICA_MEMORY_REQUEST="null"
            export REDIS_REPLICA_MEMORY_LIMIT="null"
            # Gateway API
            export GATEWAY_API_CPU_REQUEST="null"
            export GATEWAY_API_CPU_LIMIT="null"
            export GATEWAY_API_MEMORY_REQUEST="null"
            export GATEWAY_API_MEMORY_LIMIT="null"
            # Gateway Celery Worker
            export GATEWAY_CELERY_WORKER_CPU_REQUEST="null"
            export GATEWAY_CELERY_WORKER_CPU_LIMIT="null"
            export GATEWAY_CELERY_WORKER_MEMORY_REQUEST="null"
            export GATEWAY_CELERY_WORKER_MEMORY_LIMIT="null"
            # Gateway OAuth
            export GATEWAY_OAUTH_CPU_REQUEST="null"
            export GATEWAY_OAUTH_CPU_LIMIT="null"
            export GATEWAY_OAUTH_MEMORY_REQUEST="null"
            export GATEWAY_OAUTH_MEMORY_LIMIT="null"
            # UI OAuth
            export UI_OAUTH_CPU_REQUEST="null"
            export UI_OAUTH_CPU_LIMIT="null"
            export UI_OAUTH_MEMORY_REQUEST="null"
            export UI_OAUTH_MEMORY_LIMIT="null"
            # UI
            export UI_CPU_REQUEST="null"
            export UI_CPU_LIMIT="null"
            export UI_MEMORY_REQUEST="null"
            export UI_MEMORY_LIMIT="null"
            # Studio
            export GFM_FT_DATA_STORAGE="15Gi"
            export_storage_vars "5Gi" \
                GFM_FT_FILES_STORAGE \
                GFM_FT_MODELS_STORAGE \
                INFERENCE_SHARED_STORAGE
            export_storage_vars "1Gi" \
                GFM_MLFLOW_STORAGE \
                INFERENCE_AUXDATA_STORAGE \
                GENERIC_PYTHON_PROCESSOR_STORAGE \
                REDIS_MASTER_STORAGE \
                REDIS_REPLICAS_STORAGE
            ;;
        medium)
            # MinIO
            export MINIO_CPU_REQUEST="4000m"
            export MINIO_CPU_LIMIT="8000m"
            export MINIO_MEMORY_REQUEST="3Gi"
            export MINIO_MEMORY_LIMIT="6Gi"
            export MINIO_STORAGE="100Gi"
            # Keycloak
            export KEYCLOAK_CPU_REQUEST="500m"
            export KEYCLOAK_CPU_LIMIT="1500m"
            export KEYCLOAK_MEMORY_REQUEST="768Mi"
            export KEYCLOAK_MEMORY_LIMIT="1536Mi"
            # GeoServer
            export GEOSERVER_CPU_REQUEST="750m"
            export GEOSERVER_CPU_LIMIT="1500m"
            export GEOSERVER_MEMORY_REQUEST="8Gi"
            export GEOSERVER_MEMORY_LIMIT="24Gi"
            export GEOSERVER_STORAGE="30Gi"
            # PostgreSQL
            export POSTGRES_CPU_REQUEST="500m"
            export POSTGRES_CPU_LIMIT="1500m"
            export POSTGRES_MEMORY_REQUEST="768Mi"
            export POSTGRES_MEMORY_LIMIT="1536Mi"
            export POSTGRES_STORAGE="10Gi"
            # PgBouncer
            export PGBOUNCER_CPU_REQUEST="1"
            export PGBOUNCER_CPU_LIMIT="2"
            export PGBOUNCER_MEMORY_REQUEST="2Gi"
            export PGBOUNCER_MEMORY_LIMIT="4Gi"
            # MLflow
            export MLFLOW_CPU_REQUEST="1"
            export MLFLOW_CPU_LIMIT="1"
            export MLFLOW_MEMORY_REQUEST="6G"
            export MLFLOW_MEMORY_LIMIT="12G"
            # Redis Master
            export REDIS_MASTER_CPU_REQUEST="1"
            export REDIS_MASTER_CPU_LIMIT="2"
            export REDIS_MASTER_MEMORY_REQUEST="1Gi"
            export REDIS_MASTER_MEMORY_LIMIT="2Gi"
            # Redis Replica
            export REDIS_REPLICA_CPU_REQUEST="1"
            export REDIS_REPLICA_CPU_LIMIT="2"
            export REDIS_REPLICA_MEMORY_REQUEST="1Gi"
            export REDIS_REPLICA_MEMORY_LIMIT="2Gi"
            # Gateway API
            export GATEWAY_API_CPU_REQUEST="2"
            export GATEWAY_API_CPU_LIMIT="4"
            export GATEWAY_API_MEMORY_REQUEST="4Gi"
            export GATEWAY_API_MEMORY_LIMIT="16Gi"
            # Gateway Celery Worker
            export GATEWAY_CELERY_WORKER_CPU_REQUEST="500m"
            export GATEWAY_CELERY_WORKER_CPU_LIMIT="1"
            export GATEWAY_CELERY_WORKER_MEMORY_REQUEST="512Mi"
            export GATEWAY_CELERY_WORKER_MEMORY_LIMIT="1536Gi"
            # Gateway OAuth
            export GATEWAY_OAUTH_CPU_REQUEST="500m"
            export GATEWAY_OAUTH_CPU_LIMIT="1"
            export GATEWAY_OAUTH_MEMORY_REQUEST="512Mi"
            export GATEWAY_OAUTH_MEMORY_LIMIT="1024Mi"
            # UI OAuth
            export UI_OAUTH_CPU_REQUEST="500m"
            export UI_OAUTH_CPU_LIMIT="1"
            export UI_OAUTH_MEMORY_REQUEST="512Mi"
            export UI_OAUTH_MEMORY_LIMIT="1024Mi"
            # UI
            export UI_CPU_REQUEST="1"
            export UI_CPU_LIMIT="2"
            export UI_MEMORY_REQUEST="2Gi"
            export UI_MEMORY_LIMIT="4Gi"
            # Studio
            export_storage_vars "20Gi" \
                GFM_FT_DATA_STORAGE \
                GFM_FT_FILES_STORAGE \
                GFM_FT_MODELS_STORAGE \
                INFERENCE_SHARED_STORAGE
            export_storage_vars "1Gi" \
                GFM_MLFLOW_STORAGE \
                INFERENCE_AUXDATA_STORAGE \
                GENERIC_PYTHON_PROCESSOR_STORAGE \
                REDIS_MASTER_STORAGE \
                REDIS_REPLICAS_STORAGE
            ;;
        high)
            # MinIO
            export MINIO_CPU_REQUEST="3000m"
            export MINIO_CPU_LIMIT="6000m"
            export MINIO_MEMORY_REQUEST="4Gi"
            export MINIO_MEMORY_LIMIT="8Gi"
            export MINIO_STORAGE="500Gi"
            # Keycloak
            export KEYCLOAK_CPU_REQUEST="750m"
            export KEYCLOAK_CPU_LIMIT="2000m"
            export KEYCLOAK_MEMORY_REQUEST="1Gi"
            export KEYCLOAK_MEMORY_LIMIT="2Gi"
            # GeoServer
            export GEOSERVER_CPU_REQUEST="1000m"
            export GEOSERVER_CPU_LIMIT="3000m"
            export GEOSERVER_MEMORY_REQUEST="12Gi"
            export GEOSERVER_MEMORY_LIMIT="48Gi"
            export GEOSERVER_STORAGE="200Gi"
            # PostgreSQL
            export POSTGRES_CPU_REQUEST="750m"
            export POSTGRES_CPU_LIMIT="2000m"
            export POSTGRES_MEMORY_REQUEST="1Gi"
            export POSTGRES_MEMORY_LIMIT="2Gi"
            export POSTGRES_STORAGE="10Gi"
            # PgBouncer
            export PGBOUNCER_CPU_REQUEST="1"
            export PGBOUNCER_CPU_LIMIT="2"
            export PGBOUNCER_MEMORY_REQUEST="4Gi"
            export PGBOUNCER_MEMORY_LIMIT="8Gi"
            # MLflow
            export MLFLOW_CPU_REQUEST="1"
            export MLFLOW_CPU_LIMIT="1"
            export MLFLOW_MEMORY_REQUEST="8G"
            export MLFLOW_MEMORY_LIMIT="16G"
            # Redis Master
            export REDIS_MASTER_CPU_REQUEST="1"
            export REDIS_MASTER_CPU_LIMIT="2"
            export REDIS_MASTER_MEMORY_REQUEST="2Gi"
            export REDIS_MASTER_MEMORY_LIMIT="4Gi"
            # Redis Replica
            export REDIS_REPLICA_CPU_REQUEST="1"
            export REDIS_REPLICA_CPU_LIMIT="2"
            export REDIS_REPLICA_MEMORY_REQUEST="2Gi"
            export REDIS_REPLICA_MEMORY_LIMIT="4Gi"
            # Gateway API
            export GATEWAY_API_CPU_REQUEST="4"
            export GATEWAY_API_CPU_LIMIT="8"
            export GATEWAY_API_MEMORY_REQUEST="8Gi"
            export GATEWAY_API_MEMORY_LIMIT="32Gi"
            # Gateway Celery Worker
            export GATEWAY_CELERY_WORKER_CPU_REQUEST="1"
            export GATEWAY_CELERY_WORKER_CPU_LIMIT="2"
            export GATEWAY_CELERY_WORKER_MEMORY_REQUEST="1Gi"
            export GATEWAY_CELERY_WORKER_MEMORY_LIMIT="2Gi"
            # Gateway OAuth
            export GATEWAY_OAUTH_CPU_REQUEST="1"
            export GATEWAY_OAUTH_CPU_LIMIT="2"
            export GATEWAY_OAUTH_MEMORY_REQUEST="512Mi"
            export GATEWAY_OAUTH_MEMORY_LIMIT="1Gi"
            # UI OAuth
            export UI_OAUTH_CPU_REQUEST="512m"
            export UI_OAUTH_CPU_LIMIT="1000m"
            export UI_OAUTH_MEMORY_REQUEST="512Mi"
            export UI_OAUTH_MEMORY_LIMIT="1Gi"
            # UI
            export UI_CPU_REQUEST="2"
            export UI_CPU_LIMIT="4"
            export UI_MEMORY_REQUEST="4Gi"
            export UI_MEMORY_LIMIT="8Gi"
            # Studio
            export_storage_vars "100Gi" \
                GFM_FT_DATA_STORAGE \
                GFM_FT_FILES_STORAGE \
                GFM_FT_MODELS_STORAGE \
                INFERENCE_SHARED_STORAGE \
                INFERENCE_AUXDATA_STORAGE
            export_storage_vars "5Gi" \
                GFM_MLFLOW_STORAGE \
                GENERIC_PYTHON_PROCESSOR_STORAGE \
                REDIS_MASTER_STORAGE \
                REDIS_REPLICAS_STORAGE
            ;;
        xlarge)
            # MinIO
            export MINIO_CPU_REQUEST="4000m"
            export MINIO_CPU_LIMIT="8000m"
            export MINIO_MEMORY_REQUEST="6Gi"
            export MINIO_MEMORY_LIMIT="12Gi"
            export MINIO_STORAGE="1000Gi"
            # Keycloak
            export KEYCLOAK_CPU_REQUEST="1000m"
            export KEYCLOAK_CPU_LIMIT="4000m"
            export KEYCLOAK_MEMORY_REQUEST="2Gi"
            export KEYCLOAK_MEMORY_LIMIT="4Gi"
            # GeoServer
            export GEOSERVER_CPU_REQUEST="2000m"
            export GEOSERVER_CPU_LIMIT="4000m"
            export GEOSERVER_MEMORY_REQUEST="12Gi"
            export GEOSERVER_MEMORY_LIMIT="60Gi"
            # PostgreSQL
            export POSTGRES_CPU_REQUEST="1000m"
            export POSTGRES_CPU_LIMIT="4000m"
            export POSTGRES_MEMORY_REQUEST="2Gi"
            export POSTGRES_MEMORY_LIMIT="4Gi"
            # PgBouncer
            export PGBOUNCER_CPU_REQUEST="1"
            export PGBOUNCER_CPU_LIMIT="2"
            export PGBOUNCER_MEMORY_REQUEST="8Gi"
            export PGBOUNCER_MEMORY_LIMIT="16Gi"
            # MLflow
            export MLFLOW_CPU_REQUEST="1"
            export MLFLOW_CPU_LIMIT="2"
            export MLFLOW_MEMORY_REQUEST="8G"
            export MLFLOW_MEMORY_LIMIT="16G"
            # Redis Master
            export REDIS_MASTER_CPU_REQUEST="1"
            export REDIS_MASTER_CPU_LIMIT="2"
            export REDIS_MASTER_MEMORY_REQUEST="4Gi"
            export REDIS_MASTER_MEMORY_LIMIT="8Gi"
            # Redis Replica
            export REDIS_REPLICA_CPU_REQUEST="1"
            export REDIS_REPLICA_CPU_LIMIT="2"
            export REDIS_REPLICA_MEMORY_REQUEST="4Gi"
            export REDIS_REPLICA_MEMORY_LIMIT="8Gi"
            # Gateway API
            export GATEWAY_API_CPU_REQUEST="5"
            export GATEWAY_API_CPU_LIMIT="10"
            export GATEWAY_API_MEMORY_REQUEST="8Gi"
            export GATEWAY_API_MEMORY_LIMIT="36Gi"
            # Gateway Celery Worker
            export GATEWAY_CELERY_WORKER_CPU_REQUEST="2"
            export GATEWAY_CELERY_WORKER_CPU_LIMIT="4"
            export GATEWAY_CELERY_WORKER_MEMORY_REQUEST="2Gi"
            export GATEWAY_CELERY_WORKER_MEMORY_LIMIT="4Gi"
            # Gateway OAuth
            export GATEWAY_OAUTH_CPU_REQUEST="2"
            export GATEWAY_OAUTH_CPU_LIMIT="4"
            export GATEWAY_OAUTH_MEMORY_REQUEST="1Gi"
            export GATEWAY_OAUTH_MEMORY_LIMIT="2Gi"
            # UI OAuth
            export UI_OAUTH_CPU_REQUEST="1"
            export UI_OAUTH_CPU_LIMIT="2"
            export UI_OAUTH_MEMORY_REQUEST="1Gi"
            export UI_OAUTH_MEMORY_LIMIT="2Gi"
            # UI
            export UI_CPU_REQUEST="3"
            export UI_CPU_LIMIT="6"
            export UI_MEMORY_REQUEST="8Gi"
            export UI_MEMORY_LIMIT="16Gi"
            # Studio
            export_storage_vars "200Gi" \
                GFM_FT_DATA_STORAGE \
                GFM_FT_FILES_STORAGE \
                GFM_FT_MODELS_STORAGE \
                INFERENCE_SHARED_STORAGE \
                INFERENCE_AUXDATA_STORAGE
            export_storage_vars "10Gi" \
                GFM_MLFLOW_STORAGE \
                GENERIC_PYTHON_PROCESSOR_STORAGE \
                REDIS_MASTER_STORAGE \
                REDIS_REPLICAS_STORAGE
            ;;
    esac

    # Update env.sh with resource mode and all component resources
    sed -i -e "s/export RESOURCE_MODE=.*/export RESOURCE_MODE=${RESOURCE_MODE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MINIO_CPU_REQUEST=.*/export MINIO_CPU_REQUEST=${MINIO_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MINIO_CPU_LIMIT=.*/export MINIO_CPU_LIMIT=${MINIO_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MINIO_MEMORY_REQUEST=.*/export MINIO_MEMORY_REQUEST=${MINIO_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MINIO_MEMORY_LIMIT=.*/export MINIO_MEMORY_LIMIT=${MINIO_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MINIO_STORAGE=.*/export MINIO_STORAGE=${MINIO_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export KEYCLOAK_CPU_REQUEST=.*/export KEYCLOAK_CPU_REQUEST=${KEYCLOAK_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export KEYCLOAK_CPU_LIMIT=.*/export KEYCLOAK_CPU_LIMIT=${KEYCLOAK_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export KEYCLOAK_MEMORY_REQUEST=.*/export KEYCLOAK_MEMORY_REQUEST=${KEYCLOAK_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export KEYCLOAK_MEMORY_LIMIT=.*/export KEYCLOAK_MEMORY_LIMIT=${KEYCLOAK_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GEOSERVER_CPU_REQUEST=.*/export GEOSERVER_CPU_REQUEST=${GEOSERVER_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GEOSERVER_CPU_LIMIT=.*/export GEOSERVER_CPU_LIMIT=${GEOSERVER_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GEOSERVER_MEMORY_REQUEST=.*/export GEOSERVER_MEMORY_REQUEST=${GEOSERVER_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GEOSERVER_MEMORY_LIMIT=.*/export GEOSERVER_MEMORY_LIMIT=${GEOSERVER_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GEOSERVER_STORAGE=.*/export GEOSERVER_STORAGE=${GEOSERVER_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export POSTGRES_CPU_REQUEST=.*/export POSTGRES_CPU_REQUEST=${POSTGRES_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export POSTGRES_CPU_LIMIT=.*/export POSTGRES_CPU_LIMIT=${POSTGRES_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export POSTGRES_MEMORY_REQUEST=.*/export POSTGRES_MEMORY_REQUEST=${POSTGRES_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export POSTGRES_MEMORY_LIMIT=.*/export POSTGRES_MEMORY_LIMIT=${POSTGRES_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export POSTGRES_STORAGE=.*/export POSTGRES_STORAGE=${POSTGRES_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export PGBOUNCER_CPU_REQUEST=.*/export PGBOUNCER_CPU_REQUEST=${PGBOUNCER_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export PGBOUNCER_CPU_LIMIT=.*/export PGBOUNCER_CPU_LIMIT=${PGBOUNCER_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export PGBOUNCER_MEMORY_REQUEST=.*/export PGBOUNCER_MEMORY_REQUEST=${PGBOUNCER_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export PGBOUNCER_MEMORY_LIMIT=.*/export PGBOUNCER_MEMORY_LIMIT=${PGBOUNCER_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MLFLOW_CPU_REQUEST=.*/export MLFLOW_CPU_REQUEST=${MLFLOW_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MLFLOW_CPU_LIMIT=.*/export MLFLOW_CPU_LIMIT=${MLFLOW_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MLFLOW_MEMORY_REQUEST=.*/export MLFLOW_MEMORY_REQUEST=${MLFLOW_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export MLFLOW_MEMORY_LIMIT=.*/export MLFLOW_MEMORY_LIMIT=${MLFLOW_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_MASTER_CPU_REQUEST=.*/export REDIS_MASTER_CPU_REQUEST=${REDIS_MASTER_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_MASTER_CPU_LIMIT=.*/export REDIS_MASTER_CPU_LIMIT=${REDIS_MASTER_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_MASTER_MEMORY_REQUEST=.*/export REDIS_MASTER_MEMORY_REQUEST=${REDIS_MASTER_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_MASTER_MEMORY_LIMIT=.*/export REDIS_MASTER_MEMORY_LIMIT=${REDIS_MASTER_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_REPLICA_CPU_REQUEST=.*/export REDIS_REPLICA_CPU_REQUEST=${REDIS_REPLICA_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_REPLICA_CPU_LIMIT=.*/export REDIS_REPLICA_CPU_LIMIT=${REDIS_REPLICA_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_REPLICA_MEMORY_REQUEST=.*/export REDIS_REPLICA_MEMORY_REQUEST=${REDIS_REPLICA_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_REPLICA_MEMORY_LIMIT=.*/export REDIS_REPLICA_MEMORY_LIMIT=${REDIS_REPLICA_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_API_CPU_REQUEST=.*/export GATEWAY_API_CPU_REQUEST=${GATEWAY_API_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_API_CPU_LIMIT=.*/export GATEWAY_API_CPU_LIMIT=${GATEWAY_API_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_API_MEMORY_REQUEST=.*/export GATEWAY_API_MEMORY_REQUEST=${GATEWAY_API_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_API_MEMORY_LIMIT=.*/export GATEWAY_API_MEMORY_LIMIT=${GATEWAY_API_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_CELERY_WORKER_CPU_REQUEST=.*/export GATEWAY_CELERY_WORKER_CPU_REQUEST=${GATEWAY_CELERY_WORKER_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_CELERY_WORKER_CPU_LIMIT=.*/export GATEWAY_CELERY_WORKER_CPU_LIMIT=${GATEWAY_CELERY_WORKER_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_CELERY_WORKER_MEMORY_REQUEST=.*/export GATEWAY_CELERY_WORKER_MEMORY_REQUEST=${GATEWAY_CELERY_WORKER_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_CELERY_WORKER_MEMORY_LIMIT=.*/export GATEWAY_CELERY_WORKER_MEMORY_LIMIT=${GATEWAY_CELERY_WORKER_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_OAUTH_CPU_REQUEST=.*/export GATEWAY_OAUTH_CPU_REQUEST=${GATEWAY_OAUTH_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_OAUTH_CPU_LIMIT=.*/export GATEWAY_OAUTH_CPU_LIMIT=${GATEWAY_OAUTH_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_OAUTH_MEMORY_REQUEST=.*/export GATEWAY_OAUTH_MEMORY_REQUEST=${GATEWAY_OAUTH_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GATEWAY_OAUTH_MEMORY_LIMIT=.*/export GATEWAY_OAUTH_MEMORY_LIMIT=${GATEWAY_OAUTH_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export UI_OAUTH_CPU_REQUEST=.*/export UI_OAUTH_CPU_REQUEST=${UI_OAUTH_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export UI_OAUTH_CPU_LIMIT=.*/export UI_OAUTH_CPU_LIMIT=${UI_OAUTH_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export UI_OAUTH_MEMORY_REQUEST=.*/export UI_OAUTH_MEMORY_REQUEST=${UI_OAUTH_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export UI_OAUTH_MEMORY_LIMIT=.*/export UI_OAUTH_MEMORY_LIMIT=${UI_OAUTH_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export UI_CPU_REQUEST=.*/export UI_CPU_REQUEST=${UI_CPU_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export UI_CPU_LIMIT=.*/export UI_CPU_LIMIT=${UI_CPU_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export UI_MEMORY_REQUEST=.*/export UI_MEMORY_REQUEST=${UI_MEMORY_REQUEST}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export UI_MEMORY_LIMIT=.*/export UI_MEMORY_LIMIT=${UI_MEMORY_LIMIT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GFM_FT_DATA_STORAGE=.*/export GFM_FT_DATA_STORAGE=${GFM_FT_DATA_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GFM_FT_FILES_STORAGE=.*/export GFM_FT_FILES_STORAGE=${GFM_FT_FILES_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GFM_FT_MODELS_STORAGE=.*/export GFM_FT_MODELS_STORAGE=${GFM_FT_MODELS_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export INFERENCE_SHARED_STORAGE=.*/export INFERENCE_SHARED_STORAGE=${INFERENCE_SHARED_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export INFERENCE_AUXDATA_STORAGE=.*/export INFERENCE_AUXDATA_STORAGE=${INFERENCE_AUXDATA_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GFM_MLFLOW_STORAGE=.*/export GFM_MLFLOW_STORAGE=${GFM_MLFLOW_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export GENERIC_PYTHON_PROCESSOR_STORAGE=.*/export GENERIC_PYTHON_PROCESSOR_STORAGE=${GENERIC_PYTHON_PROCESSOR_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_MASTER_STORAGE=.*/export REDIS_MASTER_STORAGE=${REDIS_MASTER_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export REDIS_REPLICAS_STORAGE=.*/export REDIS_REPLICAS_STORAGE=${REDIS_REPLICAS_STORAGE}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

    echo "Resource configuration complete for all components"
}

# Function to conditionally add --set flags for Helm deployment
# Only adds the flag if the value is not 'null' or empty
# Usage: add_helm_set_if_not_null "helm.path.to.value" "$ENV_VAR_VALUE"
add_helm_set_if_not_null() {
    local helm_path="$1"
    local value="$2"

    # Check if value is not empty, not 'null', and not just whitespace
    if [[ -n "$value" && "$value" != "null" && -n "${value// /}" ]]; then
        echo "--set \"${helm_path}=${value}\""
    fi
}

# Function to update values-deploy.yaml with resource configurations
# This function populates the empty resource sections in the values file
# with the values from environment variables set by configure_resource_mode()
update_values_deploy_resources() {
    local values_file="$1"

    if [[ ! -f "$values_file" ]]; then
        echo "Error: Values file not found: $values_file"
        return 1
    fi

    echo "Updating resource configurations in $values_file..."

    # Use yq to update the YAML file with resource values
    # Only update if the environment variable is set and not 'null'

    # PgBouncer resources
    if [[ -n "$PGBOUNCER_CPU_REQUEST" && "$PGBOUNCER_CPU_REQUEST" != "null" && -n "${PGBOUNCER_CPU_REQUEST// /}" ]]; then
        yq eval -i ".pgbouncer.resources.requests.cpu = \"$PGBOUNCER_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$PGBOUNCER_MEMORY_REQUEST" && "$PGBOUNCER_MEMORY_REQUEST" != "null" && -n "${PGBOUNCER_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".pgbouncer.resources.requests.memory = \"$PGBOUNCER_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$PGBOUNCER_CPU_LIMIT" && "$PGBOUNCER_CPU_LIMIT" != "null" && -n "${PGBOUNCER_CPU_LIMIT// /}" ]]; then
        yq eval -i ".pgbouncer.resources.limits.cpu = \"$PGBOUNCER_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$PGBOUNCER_MEMORY_LIMIT" && "$PGBOUNCER_MEMORY_LIMIT" != "null" && -n "${PGBOUNCER_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".pgbouncer.resources.limits.memory = \"$PGBOUNCER_MEMORY_LIMIT\"" "$values_file"
    fi

    # MLflow resources
    if [[ -n "$MLFLOW_CPU_REQUEST" && "$MLFLOW_CPU_REQUEST" != "null" && -n "${MLFLOW_CPU_REQUEST// /}" ]]; then
        yq eval -i ".gfm-mlflow.resources.requests.cpu = \"$MLFLOW_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$MLFLOW_MEMORY_REQUEST" && "$MLFLOW_MEMORY_REQUEST" != "null" && -n "${MLFLOW_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".gfm-mlflow.resources.requests.memory = \"$MLFLOW_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$MLFLOW_CPU_LIMIT" && "$MLFLOW_CPU_LIMIT" != "null" && -n "${MLFLOW_CPU_LIMIT// /}" ]]; then
        yq eval -i ".gfm-mlflow.resources.limits.cpu = \"$MLFLOW_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$MLFLOW_MEMORY_LIMIT" && "$MLFLOW_MEMORY_LIMIT" != "null" && -n "${MLFLOW_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".gfm-mlflow.resources.limits.memory = \"$MLFLOW_MEMORY_LIMIT\"" "$values_file"
    fi

    # Redis Master resources
    if [[ -n "$REDIS_MASTER_CPU_REQUEST" && "$REDIS_MASTER_CPU_REQUEST" != "null" && -n "${REDIS_MASTER_CPU_REQUEST// /}" ]]; then
        yq eval -i ".redis.master.resources.requests.cpu = \"$REDIS_MASTER_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$REDIS_MASTER_MEMORY_REQUEST" && "$REDIS_MASTER_MEMORY_REQUEST" != "null" && -n "${REDIS_MASTER_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".redis.master.resources.requests.memory = \"$REDIS_MASTER_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$REDIS_MASTER_CPU_LIMIT" && "$REDIS_MASTER_CPU_LIMIT" != "null" && -n "${REDIS_MASTER_CPU_LIMIT// /}" ]]; then
        yq eval -i ".redis.master.resources.limits.cpu = \"$REDIS_MASTER_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$REDIS_MASTER_MEMORY_LIMIT" && "$REDIS_MASTER_MEMORY_LIMIT" != "null" && -n "${REDIS_MASTER_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".redis.master.resources.limits.memory = \"$REDIS_MASTER_MEMORY_LIMIT\"" "$values_file"
    fi

    # Redis Replica resources
    if [[ -n "$REDIS_REPLICA_CPU_REQUEST" && "$REDIS_REPLICA_CPU_REQUEST" != "null" && -n "${REDIS_REPLICA_CPU_REQUEST// /}" ]]; then
        yq eval -i ".redis.replica.resources.requests.cpu = \"$REDIS_REPLICA_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$REDIS_REPLICA_MEMORY_REQUEST" && "$REDIS_REPLICA_MEMORY_REQUEST" != "null" && -n "${REDIS_REPLICA_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".redis.replica.resources.requests.memory = \"$REDIS_REPLICA_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$REDIS_REPLICA_CPU_LIMIT" && "$REDIS_REPLICA_CPU_LIMIT" != "null" && -n "${REDIS_REPLICA_CPU_LIMIT// /}" ]]; then
        yq eval -i ".redis.replica.resources.limits.cpu = \"$REDIS_REPLICA_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$REDIS_REPLICA_MEMORY_LIMIT" && "$REDIS_REPLICA_MEMORY_LIMIT" != "null" && -n "${REDIS_REPLICA_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".redis.replica.resources.limits.memory = \"$REDIS_REPLICA_MEMORY_LIMIT\"" "$values_file"
    fi

    # Gateway API resources
    if [[ -n "$GATEWAY_API_CPU_REQUEST" && "$GATEWAY_API_CPU_REQUEST" != "null" && -n "${GATEWAY_API_CPU_REQUEST// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.api.requests.cpu = \"$GATEWAY_API_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_API_MEMORY_REQUEST" && "$GATEWAY_API_MEMORY_REQUEST" != "null" && -n "${GATEWAY_API_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.api.requests.memory = \"$GATEWAY_API_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_API_CPU_LIMIT" && "$GATEWAY_API_CPU_LIMIT" != "null" && -n "${GATEWAY_API_CPU_LIMIT// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.api.limits.cpu = \"$GATEWAY_API_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_API_MEMORY_LIMIT" && "$GATEWAY_API_MEMORY_LIMIT" != "null" && -n "${GATEWAY_API_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.api.limits.memory = \"$GATEWAY_API_MEMORY_LIMIT\"" "$values_file"
    fi

    # Gateway Celery Worker resources
    if [[ -n "$GATEWAY_CELERY_WORKER_CPU_REQUEST" && "$GATEWAY_CELERY_WORKER_CPU_REQUEST" != "null" && -n "${GATEWAY_CELERY_WORKER_CPU_REQUEST// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.celeryWorker.requests.cpu = \"$GATEWAY_CELERY_WORKER_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_CELERY_WORKER_MEMORY_REQUEST" && "$GATEWAY_CELERY_WORKER_MEMORY_REQUEST" != "null" && -n "${GATEWAY_CELERY_WORKER_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.celeryWorker.requests.memory = \"$GATEWAY_CELERY_WORKER_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_CELERY_WORKER_CPU_LIMIT" && "$GATEWAY_CELERY_WORKER_CPU_LIMIT" != "null" && -n "${GATEWAY_CELERY_WORKER_CPU_LIMIT// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.celeryWorker.limits.cpu = \"$GATEWAY_CELERY_WORKER_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_CELERY_WORKER_MEMORY_LIMIT" && "$GATEWAY_CELERY_WORKER_MEMORY_LIMIT" != "null" && -n "${GATEWAY_CELERY_WORKER_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.celeryWorker.limits.memory = \"$GATEWAY_CELERY_WORKER_MEMORY_LIMIT\"" "$values_file"
    fi

    # Gateway OAuth resources
    if [[ -n "$GATEWAY_OAUTH_CPU_REQUEST" && "$GATEWAY_OAUTH_CPU_REQUEST" != "null" && -n "${GATEWAY_OAUTH_CPU_REQUEST// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.oauth.requests.cpu = \"$GATEWAY_OAUTH_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_OAUTH_MEMORY_REQUEST" && "$GATEWAY_OAUTH_MEMORY_REQUEST" != "null" && -n "${GATEWAY_OAUTH_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.oauth.requests.memory = \"$GATEWAY_OAUTH_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_OAUTH_CPU_LIMIT" && "$GATEWAY_OAUTH_CPU_LIMIT" != "null" && -n "${GATEWAY_OAUTH_CPU_LIMIT// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.oauth.limits.cpu = \"$GATEWAY_OAUTH_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$GATEWAY_OAUTH_MEMORY_LIMIT" && "$GATEWAY_OAUTH_MEMORY_LIMIT" != "null" && -n "${GATEWAY_OAUTH_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".gfm-studio-gateway.resources.oauth.limits.memory = \"$GATEWAY_OAUTH_MEMORY_LIMIT\"" "$values_file"
    fi

    # UI resources
    if [[ -n "$UI_CPU_REQUEST" && "$UI_CPU_REQUEST" != "null" && -n "${UI_CPU_REQUEST// /}" ]]; then
        yq eval -i ".geofm-ui.resources.ui.requests.cpu = \"$UI_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$UI_MEMORY_REQUEST" && "$UI_MEMORY_REQUEST" != "null" && -n "${UI_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".geofm-ui.resources.ui.requests.memory = \"$UI_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$UI_CPU_LIMIT" && "$UI_CPU_LIMIT" != "null" && -n "${UI_CPU_LIMIT// /}" ]]; then
        yq eval -i ".geofm-ui.resources.ui.limits.cpu = \"$UI_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$UI_MEMORY_LIMIT" && "$UI_MEMORY_LIMIT" != "null" && -n "${UI_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".geofm-ui.resources.ui.limits.memory = \"$UI_MEMORY_LIMIT\"" "$values_file"
    fi

    # UI OAuth resources
    if [[ -n "$UI_OAUTH_CPU_REQUEST" && "$UI_OAUTH_CPU_REQUEST" != "null" && -n "${UI_OAUTH_CPU_REQUEST// /}" ]]; then
        yq eval -i ".geofm-ui.resources.oauth.requests.cpu = \"$UI_OAUTH_CPU_REQUEST\"" "$values_file"
    fi
    if [[ -n "$UI_OAUTH_MEMORY_REQUEST" && "$UI_OAUTH_MEMORY_REQUEST" != "null" && -n "${UI_OAUTH_MEMORY_REQUEST// /}" ]]; then
        yq eval -i ".geofm-ui.resources.oauth.requests.memory = \"$UI_OAUTH_MEMORY_REQUEST\"" "$values_file"
    fi
    if [[ -n "$UI_OAUTH_CPU_LIMIT" && "$UI_OAUTH_CPU_LIMIT" != "null" && -n "${UI_OAUTH_CPU_LIMIT// /}" ]]; then
        yq eval -i ".geofm-ui.resources.oauth.limits.cpu = \"$UI_OAUTH_CPU_LIMIT\"" "$values_file"
    fi
    if [[ -n "$UI_OAUTH_MEMORY_LIMIT" && "$UI_OAUTH_MEMORY_LIMIT" != "null" && -n "${UI_OAUTH_MEMORY_LIMIT// /}" ]]; then
        yq eval -i ".geofm-ui.resources.oauth.limits.memory = \"$UI_OAUTH_MEMORY_LIMIT\"" "$values_file"
    fi

    echo "✓ Resource configurations updated successfully in $values_file"
    return 0
}

# Function to build all resource --set flags for Helm deployment
# Returns a string of all applicable --set flags (CPU and memory only, no storage)
build_resource_helm_flags() {
    local flags=""

    # PgBouncer resources
    flags+=" $(add_helm_set_if_not_null "pgbouncer.resources.requests.cpu" "$PGBOUNCER_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "pgbouncer.resources.requests.memory" "$PGBOUNCER_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "pgbouncer.resources.limits.cpu" "$PGBOUNCER_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "pgbouncer.resources.limits.memory" "$PGBOUNCER_MEMORY_LIMIT")"

    # MLflow resources (CPU and memory only, no storage)
    flags+=" $(add_helm_set_if_not_null "gfm-mlflow.resources.requests.cpu" "$MLFLOW_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "gfm-mlflow.resources.requests.memory" "$MLFLOW_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "gfm-mlflow.resources.limits.cpu" "$MLFLOW_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "gfm-mlflow.resources.limits.memory" "$MLFLOW_MEMORY_LIMIT")"

    # Redis Master resources (CPU and memory only, no storage)
    flags+=" $(add_helm_set_if_not_null "redis.master.resources.requests.cpu" "$REDIS_MASTER_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "redis.master.resources.requests.memory" "$REDIS_MASTER_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "redis.master.resources.limits.cpu" "$REDIS_MASTER_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "redis.master.resources.limits.memory" "$REDIS_MASTER_MEMORY_LIMIT")"

    # Redis Replica resources (CPU and memory only, no storage)
    flags+=" $(add_helm_set_if_not_null "redis.replica.resources.requests.cpu" "$REDIS_REPLICA_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "redis.replica.resources.requests.memory" "$REDIS_REPLICA_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "redis.replica.resources.limits.cpu" "$REDIS_REPLICA_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "redis.replica.resources.limits.memory" "$REDIS_REPLICA_MEMORY_LIMIT")"

    # Gateway API resources
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.api.requests.cpu" "$GATEWAY_API_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.api.requests.memory" "$GATEWAY_API_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.api.limits.cpu" "$GATEWAY_API_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.api.limits.memory" "$GATEWAY_API_MEMORY_LIMIT")"

    # Gateway Celery Worker resources
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.celeryWorker.requests.cpu" "$GATEWAY_CELERY_WORKER_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.celeryWorker.requests.memory" "$GATEWAY_CELERY_WORKER_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.celeryWorker.limits.cpu" "$GATEWAY_CELERY_WORKER_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.celeryWorker.limits.memory" "$GATEWAY_CELERY_WORKER_MEMORY_LIMIT")"

    # Gateway OAuth resources
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.oauth.requests.cpu" "$GATEWAY_OAUTH_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.oauth.requests.memory" "$GATEWAY_OAUTH_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.oauth.limits.cpu" "$GATEWAY_OAUTH_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "gfm-studio-gateway.resources.oauth.limits.memory" "$GATEWAY_OAUTH_MEMORY_LIMIT")"

    # UI resources
    flags+=" $(add_helm_set_if_not_null "geofm-ui.resources.ui.requests.cpu" "$UI_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "geofm-ui.resources.ui.requests.memory" "$UI_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "geofm-ui.resources.ui.limits.cpu" "$UI_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "geofm-ui.resources.ui.limits.memory" "$UI_MEMORY_LIMIT")"

    # UI OAuth resources
    flags+=" $(add_helm_set_if_not_null "geofm-ui.resources.oauth.requests.cpu" "$UI_OAUTH_CPU_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "geofm-ui.resources.oauth.requests.memory" "$UI_OAUTH_MEMORY_REQUEST")"
    flags+=" $(add_helm_set_if_not_null "geofm-ui.resources.oauth.limits.cpu" "$UI_OAUTH_CPU_LIMIT")"
    flags+=" $(add_helm_set_if_not_null "geofm-ui.resources.oauth.limits.memory" "$UI_OAUTH_MEMORY_LIMIT")"

    # Return the flags (trim leading/trailing spaces)
    echo "$flags" | xargs
}
