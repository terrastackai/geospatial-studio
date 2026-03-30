#!/usr/bin/env python3

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0

"""
Script to update GPU resource configurations in values.yaml for clusters without GPUs.
Sets GPU limits and requests to 0 and configures CPU/Memory resources for fine-tuning jobs.
"""

import yaml
import argparse
import sys


def update_job_resources_config(filename, gpu_limit=0, gpu_request=0, cpu_limit=4, cpu_request=2, 
                      memory_limit=10, memory_request=8):
    """
    Update GPU and resource configurations in the values.yaml file.
    
    Args:
        filename: Path to the values.yaml file
        gpu_limit: GPU limit (default: 0 for no GPU)
        gpu_request: GPU request (default: 0 for no GPU)
        cpu_limit: CPU cores limit (default: 4)
        cpu_request: CPU cores request (default: 2)
        memory_limit: Memory limit in GB (default: 10)
        memory_request: Memory request in GB (default: 8)
    """
    try:
        with open(filename, 'r') as stream:
            data = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(f"Error loading YAML file: {exc}")
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found")
        sys.exit(1)

    try:
        # Navigate to the configuration using .get() for safe access
        config_map = data.get('gfm-studio-gateway', {}).get('extraEnvironment', {}).get("api",{})
        
        if not config_map:
            print("Warning: 'gfm-studio-gateway.extraEnvironment.api' not found in values.yaml")
            return
        
        # Update all resource configurations
        config_map.update({
            'RESOURCE_LIMIT_GPU': gpu_limit,
            'RESOURCE_REQUEST_GPU': gpu_request,
            'RESOURCE_LIMIT_CPU': cpu_limit,
            'RESOURCE_REQUEST_CPU': cpu_request,
            'RESOURCE_LIMIT_Memory': memory_limit,
            'RESOURCE_REQUEST_Memory': memory_request
        })
        
        print(f"Updated GPU and resource configurations in {filename}:")
        print(f"  GPU Limit: {gpu_limit}, GPU Request: {gpu_request}")
        print(f"  CPU Limit: {cpu_limit}, CPU Request: {cpu_request}")
        print(f"  Memory Limit: {memory_limit}GB, Memory Request: {memory_request}GB")
            
    except Exception as exc:
        print(f"Error updating configuration: {exc}")
        sys.exit(1)

    # Write the updated configuration back to the file
    try:
        with open(filename, 'w') as stream:
            yaml.dump(data, stream, default_flow_style=False, sort_keys=False)
        print(f"Successfully updated {filename}")
    except Exception as exc:
        print(f"Error writing to file: {exc}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Update GPU and resource configurations in values.yaml for clusters without GPUs"
    )
    parser.add_argument(
        "--filename",
        help="Path to the values.yaml file to update",
        type=str
    )
    parser.add_argument(
        "--gpu-limit",
        help="GPU limit (default: 0 for no GPU)",
        type=int,
        default=0
    )
    parser.add_argument(
        "--gpu-request",
        help="GPU request (default: 0 for no GPU)",
        type=int,
        default=0
    )
    parser.add_argument(
        "--cpu-limit",
        help="CPU cores limit (default: 4)",
        type=int,
        default=4
    )
    parser.add_argument(
        "--cpu-request",
        help="CPU cores request (default: 2)",
        type=int,
        default=2
    )
    parser.add_argument(
        "--memory-limit",
        help="Memory limit in GB (default: 10)",
        type=int,
        default=10
    )
    parser.add_argument(
        "--memory-request",
        help="Memory request in GB (default:6)",
        type=int,
        default=6
    )
    
    args = parser.parse_args()
    
    update_job_resources_config(
        args.filename,
        gpu_limit=args.gpu_limit,
        gpu_request=args.gpu_request,
        cpu_limit=args.cpu_limit,
        cpu_request=args.cpu_request,
        memory_limit=args.memory_limit,
        memory_request=args.memory_request
    )


if __name__ == "__main__":
    main()
