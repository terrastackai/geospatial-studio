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
