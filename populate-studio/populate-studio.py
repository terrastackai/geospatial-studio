# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import glob
import argparse
import os
import json
import requests

payloads_path = "./populate-studio/payloads"

api_header = {
    "Content-Type": "application/json",
    "X-API-Key": os.getenv("STUDIO_API_KEY")
}

templates = glob.glob(f"{payloads_path}/templates/template-*.json")
tunes = glob.glob(f"{payloads_path}/tunes/tune-*.json")

studio_api_key = os.getenv("STUDIO_API_KEY")
ui_route_url = os.getenv("UI_ROUTE_URL")

def onboard_datasets(choose=True):
    datasets = glob.glob(f"{payloads_path}/datasets/dataset-*.json")
    if choose:
        print("\n--- Available Datasets ---")
        for i, dataset in enumerate(datasets, 1):
            with open(dataset, 'r') as f:
                data = json.load(f)
                dataset_name = data['dataset_name']
            print(f"  {i}. {dataset_name}")
        print(f"  {i+1}. All of the above")
        print("----------------------------------")
        selection = int(input(f"Select a dataset number to onboard (1-{len(datasets)+1}): "))
        if 1 <= selection <= len(datasets):
            selected_dataset = datasets[selection - 1]
            print(f"\n✅ Onboarding the dataset: '{selected_dataset}'...")
            # *** PUT YOUR ONBOARDING LOGIC HERE ***
            resp = requests.post(f'{ui_route_url}/studio-gateway/v2/datasets/onboard', data=open(selected_dataset, 'rb'), headers=api_header, verify=False)
            print(f"Response: {resp.status_code} - {resp.text}")
        else:
            print("🚫 Invalid selection.")
    else:
        for dataset in datasets:
            print(f"\n✅ Onboarding the dataset: '{dataset}'...")
            # *** PUT YOUR ONBOARDING LOGIC HERE ***
            resp = requests.post(f'{ui_route_url}/studio-gateway/v2/datasets/onboard', data=open(selected_dataset, 'rb'), headers=api_header, verify=False)
            print(f"Response: {resp.status_code} - {resp.text}")

def onboard_backbones(choose=True):
    backbones = glob.glob(f"{payloads_path}/backbones/backbone-*.json")
    if choose:
        print("\n--- Available Backbones ---")
        for i, backbone in enumerate(backbones, 1):
            with open(backbone, 'r') as f:
                data = json.load(f)
                backbone_name = data['name']
            print(f"  {i}. {backbone_name}")
        print(f"  {i+1}. All of the above")
        print("----------------------------------")
        selection = int(input(f"Select a backbone number to onboard (1-{len(backbones)+1}): "))
        if 1 <= selection <= len(backbones):
            selected_backbone = backbones[selection - 1]
            print(f"\n✅ Onboarding the backbone: '{selected_backbone}'...")
            # *** PUT YOUR ONBOARDING LOGIC HERE ***
            resp = requests.post(f'{ui_route_url}/studio-gateway/v2/base-models', data=open(selected_backbone, 'rb'), headers=api_header, verify=False)
            print(f"\n Response: {resp.status_code} - {resp.text}")
        else:
            print("🚫 Invalid selection.")
    else:
        for backbone in backbones:
            print(f"\n✅ Onboarding the backbone: '{backbone}'...")
            # *** PUT YOUR ONBOARDING LOGIC HERE ***
            resp = requests.post(f'{ui_route_url}/studio-gateway/v2/base-models', data=open(selected_backbone, 'rb'), headers=api_header, verify=False)
            print(f"\n Response: {resp.status_code} - {resp.text} \n \n")

def onboard_inferences(choose=True):
    inferences = glob.glob(f"{payloads_path}/inferences/inference-*.json")
    if len(inferences) != 0:
        if choose:
            print("\n--- Available Inferences ---")
            for i, inference in enumerate(inferences, 1):
                with open(inference, 'r') as f:
                    data = json.load(f)
                    inference_name = f"{data['description']} - {data['location']}"
                print(f"  {i}. {inference_name}")
            print(f"  {i+1}. All of the above")
            print("----------------------------------")
            selection = int(input(f"Select a inference number to onboard (1-{len(inferences)+1}): "))
            if 1 <= selection <= len(inferences):
                selected_inference = inferences[selection - 1]
                print(f"\n✅ Onboarding the inference: '{selected_inference}'...")
                # *** PUT YOUR ONBOARDING LOGIC HERE ***
                resp = requests.post(f'{ui_route_url}/studio-gateway/v2/inference', data=open(selected_inference, 'rb'), headers=api_header, verify=False)
                print(f"\n Response: {resp.status_code} - {resp.text}")
            else:
                print("🚫 Invalid selection.")
        else:
            for inference in inferences:
                print(f"\n✅ Onboarding the inference: '{inference}'...")
                # *** PUT YOUR ONBOARDING LOGIC HERE ***
                resp = requests.post(f'{ui_route_url}/studio-gateway/v2/inference', data=open(selected_inference, 'rb'), headers=api_header, verify=False)
                print(f"\n Response: {resp.status_code} - {resp.text} \n \n")
    else:
        print("No inference artefacts found to onboard.")

def onboard_tunes(choose=True):
    tunes = glob.glob(f"{payloads_path}/tunes/tune-*.json")
    if len(tunes) != 0:
        if choose:
            print("\n--- Available Tunes ---")
            for i, tune in enumerate(tunes, 1):
                with open(tune, 'r') as f:
                    data = json.load(f)
                    if "name" in data:
                        tune_name = f"{data['name']} - {data['description']}"
                    elif "display_name" in data:
                        tune_name = f"{data['display_name']}"
                print(f"  {i}. {tune_name}")
            print(f"  {i+1}. All of the above")
            print("----------------------------------")
            selection = int(input(f"Select a tune number to onboard (1-{len(tunes)+1}): "))
            if 1 <= selection <= len(tunes):
                selected_tune = tunes[selection - 1]
                print(f"\n✅ Onboarding the tune: '{selected_tune}'...")
                # *** PUT YOUR ONBOARDING LOGIC HERE ***
                resp = requests.post(f'{ui_route_url}/studio-gateway/v2/upload-completed-tunes', data=open(selected_tune, 'rb'), headers=api_header, verify=False)
                print(f"\n Response: {resp.status_code} - {resp.text}")
            else:
                print("🚫 Invalid selection.")
        else:
            for tune in tunes:
                print(f"\n✅ Onboarding the tune: '{tune}'...")
                # *** PUT YOUR ONBOARDING LOGIC HERE ***
                resp = requests.post(f'{ui_route_url}/studio-gateway/v2/upload-completed-tunes', data=open(selected_tune, 'rb'), headers=api_header, verify=False)
                print(f"\n Response: {resp.status_code} - {resp.text} \n \n")
    else:
        print("No tune artefacts found to onboard.")


def onboard_templates(choose=True):
    templates = glob.glob(f"{payloads_path}/templates/template-*.json")
    if len(templates) != 0:
        if choose:
            print("\n--- Available Templates ---")
            for i, template in enumerate(templates, 1):
                with open(template, 'r') as f:
                    data = json.load(f)
                    template_name = f"{data['name']} - {data['description']}"
                print(f"  {i}. {template_name}")
            print(f"  {i+1}. All of the above")
            print("----------------------------------")
            selection = int(input(f"Select a template number to onboard (1-{len(templates)+1}): "))
            if 1 <= selection <= len(templates):
                selected_template = templates[selection - 1]
                print(f"\n✅ Onboarding the template: '{selected_template}'...")
                # *** PUT YOUR ONBOARDING LOGIC HERE ***
                resp = requests.post(f'{ui_route_url}/studio-gateway/v2/tune-templates', data=open(selected_template, 'rb'), headers=api_header, verify=False)
                print(f"\n Response: {resp.status_code} - {resp.text}")
            else:
                print("🚫 Invalid selection.")
        else:
            for template in templates:
                print(f"\n✅ Onboarding the template: '{template}'...")
                # *** PUT YOUR ONBOARDING LOGIC HERE ***
                resp = requests.post(f'{ui_route_url}/studio-gateway/v2/tune-templates', data=open(selected_template, 'rb'), headers=api_header, verify=False)
                print(f"\n Response: {resp.status_code} - {resp.text} \n \n")
    else:
        print("No template artefacts found to onboard.")



parser = argparse.ArgumentParser(
                    prog='python populate-studio.py',
                    description='Load datasets, templates, examples, and tunes into Studio via CLI',
                    epilog='For more information, visit https://')

parser.add_argument('artefact_type', help='all, datasets, templates, tunes, inferences')           # positional argument
parser.add_argument('-v', '--verbose',
                    action='store_true')  # on/off flag

args = parser.parse_args()

os.system('clear')

print('\n \n 🚀  Geospatial Studio Population Script  🚀')
print('-------------------------------------------------')

if args.artefact_type == "datasets":
    onboard_datasets(choose=True)
elif args.artefact_type == "backbones":
    onboard_backbones(choose=True)
elif args.artefact_type == "inferences":
    onboard_inferences(choose=True)
elif args.artefact_type == "tunes":
    onboard_tunes(choose=True)
elif args.artefact_type == "templates":
    onboard_templates(choose=True)
else:
    print("Invalid artefact type. Please choose from: datasets, backbones, inferences, tunes.")


