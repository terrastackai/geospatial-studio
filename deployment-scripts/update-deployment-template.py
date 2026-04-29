# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os
import sys
import yaml
import argparse
from dotenv import load_dotenv

parser = argparse.ArgumentParser()
parser.add_argument("--filename", help="The postgres/geoserver pvc yaml filename", type=str)
parser.add_argument("--env-path", help="Path to the .env file", type=str)
parser.add_argument("--storageclass", help="Storage class name", type=str)
parser.add_argument("--storage", help="Storage size for PV and PVC (e.g., 100Gi, 50Gi)", type=str)
parser.add_argument("--disable-route", action="store_true", help="Disable route")
parser.add_argument("--disable-pvc", action="store_true", help="Disable pvc")
parser.add_argument("--proxy-base-url", help="Geoserver proxy base url", type=str)
parser.add_argument("--geoserver-csrf-whitelist", help="Geoserver csrf whitelist", type=str)
parser.add_argument("--geoserver-run-unprivileged", help="Geoserver run unprivileged config", type=str)
parser.add_argument("--geoserver-image-pull-secret", help="Geoserver image pull secret", type=str)
parser.add_argument("--geoserver-image-uri", help="Geoserver custom image uri", type=str)
parser.add_argument("--cpu-request", help="CPU request (e.g., 1000m, 2000m)", type=str)
parser.add_argument("--cpu-limit", help="CPU limit (e.g., 2000m, 4000m)", type=str)
parser.add_argument("--memory-request", help="Memory request (e.g., 1Gi, 2Gi)", type=str)
parser.add_argument("--memory-limit", help="Memory limit (e.g., 2Gi, 4Gi)", type=str)

args = parser.parse_args()
with open(args.filename) as stream:
    try:
        files = list(yaml.safe_load_all(stream))
    except yaml.YAMLError as exc:
        print(exc)

updated_files = []
try:
    for file in files:
        if args.disable_pvc and file.get('kind') == 'PersistentVolume':
            continue
        if args.disable_route and file.get('kind') == 'Route':
            continue
        if args.proxy_base_url and file.get('kind') == 'ConfigMap':
            file['data']['PROXY_BASE_URL'] = args.proxy_base_url
        if args.geoserver_csrf_whitelist and file.get('kind') == 'ConfigMap':
            file['data']['GEOSERVER_CSRF_WHITELIST'] = args.geoserver_csrf_whitelist
        if args.geoserver_run_unprivileged and file.get('kind') == 'ConfigMap':
            file['data']['RUN_UNPRIVILEGED'] = args.geoserver_run_unprivileged
        if args.geoserver_image_pull_secret and file.get('kind') == 'Deployment':
            pullSecrets = file['spec']['template']['spec']['imagePullSecrets']
            for pullSecret in pullSecrets:
                pullSecret["name"] = args.geoserver_image_pull_secret
        if args.geoserver_image_uri and file.get('kind') == 'Deployment':
            containers = file['spec']['template']['spec']['containers']
            for container in containers:
                container["image"] = args.geoserver_image_uri
        data = file.get('spec', {}).get('storageClassName')
        if args.storageclass and args.storageclass.strip() and args.storageclass.lower() != 'null' and data:
            file['spec']['storageClassName'] = args.storageclass
        # Update storage size for PersistentVolume and PersistentVolumeClaim (skip if None, empty string, or "null")
        if args.storage and args.storage.strip() and args.storage.lower() != 'null' and file.get('kind') == 'PersistentVolume':
            capacity = file.get('spec', {}).get('capacity')
            if capacity:
                file['spec']['capacity']['storage'] = args.storage
        if args.storage and args.storage.strip() and args.storage.lower() != 'null' and file.get('kind') == 'PersistentVolumeClaim':
            requests = file.get('spec', {}).get('resources', {}).get('requests')
            if requests:
                file['spec']['resources']['requests']['storage'] = args.storage

        # Update environment variables for Deployment
        if args.env_path and file.get('kind') == 'Deployment':
            load_dotenv(args.env_path, override=True)
            containers = file.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
            for container in containers:
                if 'env' in container:
                    for env_var in container['env']:
                        if env_var['name'] == 'KC_DB_USERNAME':
                            env_var['value'] = os.environ['pg_username']
                        if env_var['name'] == 'KC_DB_PASSWORD':
                            env_var['value'] = os.environ['pg_password']
                        if env_var['name'] == 'KC_DB_URL_HOST':
                            env_var['value'] = os.environ['pg_uri']

        # Update CPU and memory resources for Deployment
        if file.get('kind') == 'Deployment':
            containers = file.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
            for container in containers:
                resources = container.get('resources', {})

                # Update CPU request (skip if None, empty string, or "null")
                if args.cpu_request and args.cpu_request.strip() and args.cpu_request.lower() != 'null':
                    if 'requests' not in resources:
                        resources['requests'] = {}
                    resources['requests']['cpu'] = args.cpu_request

                # Update CPU limit (skip if None, empty string, or "null")
                if args.cpu_limit and args.cpu_limit.strip() and args.cpu_limit.lower() != 'null':
                    if 'limits' not in resources:
                        resources['limits'] = {}
                    resources['limits']['cpu'] = args.cpu_limit

                # Update memory request (skip if None, empty string, or "null")
                if args.memory_request and args.memory_request.strip() and args.memory_request.lower() != 'null':
                    if 'requests' not in resources:
                        resources['requests'] = {}
                    resources['requests']['memory'] = args.memory_request

                # Update memory limit (skip if None, empty string, or "null")
                if args.memory_limit and args.memory_limit.strip() and args.memory_limit.lower() != 'null':
                    if 'limits' not in resources:
                        resources['limits'] = {}
                    resources['limits']['memory'] = args.memory_limit

                # Ensure resources are set back to container
                if resources:
                    container['resources'] = resources

        updated_files.append(file)

except yaml.YAMLError as exc:
    print(exc)

yaml.dump_all(updated_files, sys.stdout, sort_keys=False, explicit_start=True)

