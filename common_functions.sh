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
