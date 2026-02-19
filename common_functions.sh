#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0

# Shared_Functions
# get_user_input
get_user_input() {
    local prompt_msg="$1"
    local result_var_name="$2"
    local input=""

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
