# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import sys
import yaml
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--filename", help="The postgres/geoserver pvc yaml filename", type=str)
parser.add_argument("--storageclass", help="Storage class name", type=str)
parser.add_argument("--disable-route", action="store_true", help="Disable route")
parser.add_argument("--disable-pvc", action="store_true", help="Disable pvc")
parser.add_argument("--proxy-base-url", help="Geoserver proxy base url", type=str)
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
        data = file.get('spec', {}).get('storageClassName')
        if args.storageclass and data:
            file['spec']['storageClassName'] = args.storageclass

        updated_files.append(file)

except yaml.YAMLError as exc:
    print(exc)

yaml.dump_all(updated_files, sys.stdout, sort_keys=False, explicit_start=True)

