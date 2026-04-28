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
    echo "  - dev: Use development values (default, development)"
    echo "  - low: testing deployment (minimal resources)"
    echo "  - medium: Enhanced performance"
    echo "  - high: High-performance workloads"
    echo "  - xlarge: Maximum performance"
    echo "  - custom: Custom resource configuration in env.sh"
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
