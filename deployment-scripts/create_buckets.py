# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import ibm_boto3
from ibm_botocore.client import Config, ClientError
import os
import argparse

import dotenv

parser = argparse.ArgumentParser(description="Run create bucket with a specified .env file.")
parser.add_argument('--env-path', type=str, default=None,
                    help="Path to the .env file.")
args = parser.parse_args()

if args.env_path:
    env_file_path = os.path.abspath(args.env_path)
    dotenv.load_dotenv(dotenv_path=env_file_path)
else:
    dotenv.load_dotenv()


def get_s3_client():
    cos = ibm_boto3.client(
        "s3",
        aws_access_key_id=os.getenv("access_key_id"),
        aws_secret_access_key=os.getenv("secret_access_key"),
        endpoint_url=os.getenv(
            "endpoint", "https://s3.us-east.cloud-object-storage.appdomain.cloud"
        ),
        config=Config(signature_version="s3v4"),
    )
    return cos


cos = get_s3_client()

deployment_name = os.getenv("deployment_name")

buckets = [
    "fine-tuning",
    "fine-tuning-models",
    "inference",
    "dataset-factory",
    "amo-input-bucket",
    "gfm-mlflow",
    "geoserver",
    "temp-upload",
    "inference-auxdata",
]


for b in buckets:

    try:
        response = cos.create_bucket(
            Bucket=f"{deployment_name}-{b}",
        )
        if response["ResponseMetadata"]["HTTPStatusCode"] == 200:
            print(f"Bucket {deployment_name}-{b} created successfully \u2714")
        else:
            print(f"Potential error creating bucket {deployment_name}-{b} please check")
    except:
        print(f"Bucket {deployment_name}-{b} already exists or could not be created")
        raise
