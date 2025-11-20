# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os
import sys
import yaml
import argparse
from dotenv import load_dotenv

parser = argparse.ArgumentParser()
parser.add_argument("--filename", help="The keycloak deployment filename", type=str)
parser.add_argument("--env-path", help="Path to the .env file", type=str)
parser.add_argument("--disable-route", action="store_true", help="Disable route")
args = parser.parse_args()

load_dotenv(args.env_path, override=True)

with open(args.filename) as stream:
    try:
        files = list(yaml.safe_load_all(stream))
    except yaml.YAMLError as exc:
        print(exc)

updated_files = []
try:
    for file in files:
        if args.disable_route and file.get('kind') == 'Route':
            continue
        data = file.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])

        for container in data:
            if 'env' in container:
                for env_var in container['env']:
                    if env_var['name'] == 'KC_DB_USERNAME':
                        env_var['value'] = os.environ['pg_username']
                    if env_var['name'] == 'KC_DB_PASSWORD':
                        env_var['value'] = os.environ['pg_password']
                    if env_var['name'] == 'KC_DB_URL_HOST':
                        env_var['value'] = os.environ['pg_uri']

        updated_files.append(file)

except yaml.YAMLError as exc:
    print(exc)

yaml.dump_all(updated_files, sys.stdout, sort_keys=False, explicit_start=True)

