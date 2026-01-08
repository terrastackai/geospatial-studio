# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import json
import os
import subprocess

import requests
from dotenv import load_dotenv

load_dotenv()


def _copy_examples():
    examples_dir = "../examples"
    dest_dir = "./docs/examples"
    if not os.path.exists(dest_dir):
        subprocess.run(["mkdir", "-p", dest_dir], text=True, check=True)
    subprocess.run(f"cp -r {examples_dir}/* {dest_dir}/", text=True, check=True, shell=True)


def _fetch_openapi_json(endpoint: str):
    request_headers = {
        "Content-Type": "application/json",
        "x-request-origin": "python-sdk/",
    }
    response = requests.get(url=endpoint, headers=request_headers)

    openapi_json = response.json()
    openapi_json["servers"] = [{"url": "/studio-gateway", "description": "Studio Environment"}]
    with open("docs/openapi.json", "w") as f:
        json.dump(openapi_json, f)


def _docs_command(command):
    try:
        subprocess.run(
            ["mkdocs", f"{command}"],
            text=True,
            check=False,
        )
    except Exception as e:
        print(f"Error running mkdocs {command} {str(e)}")


def build_docs():
    """
    Build SDK docs
    """
    url = os.getenv("BASE_GATEWAY_API_URL", "https://gfm.res.ibm.com/studio-gateway/")
    _fetch_openapi_json(f"{url}/openapi.json")
    _copy_examples()
    _docs_command("build")


def serve_docs():
    """
    Serve SDK docs locally
    """
    url = os.getenv("BASE_GATEWAY_API_URL", "https://gfm.res.ibm.com/studio-gateway/")
    _fetch_openapi_json(f"{url}/openapi.json")
    _copy_examples()
    _docs_command("serve")


def deploy_docs():
    """
    Deploy SDK docs to github pages
    """
    _docs_command("gh-deploy")
