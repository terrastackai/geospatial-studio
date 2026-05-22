# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import ibm_boto3
from ibm_botocore.client import Config, ClientError
import os
import argparse
import warnings
import time

import dotenv

# Suppress SSL warnings for self-signed certificates (e.g., CRC OpenShift Local)
warnings.filterwarnings('ignore', message='Unverified HTTPS request')

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
        verify=False
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
    "generic-python-processor",
    "pipeline-data"
]


for b in buckets:
    bucket_name = f"{deployment_name}-{b}"
    max_retries = 3
    retry_delay = 5  # seconds
    
    for attempt in range(max_retries):
        try:
            response = cos.create_bucket(
                Bucket=bucket_name,
            )
            if response["ResponseMetadata"]["HTTPStatusCode"] == 200:
                print(f"Bucket {bucket_name} created successfully \u2714")
                break
            else:
                print(f"Potential error creating bucket {bucket_name} please check")
                break
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            if error_code == 'BucketAlreadyOwnedByYou' or error_code == 'BucketAlreadyExists':
                print(f"Bucket {bucket_name} already exists \u2714")
                break
            elif attempt < max_retries - 1:
                print(f"Creating bucket {bucket_name} failed (attempt {attempt + 1}/{max_retries}): {e}")
                print(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff
            else:
                print(f"Creating bucket {bucket_name} failed after {max_retries} attempts: {e}")
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"Creating bucket {bucket_name} failed (attempt {attempt + 1}/{max_retries}): {e}")
                print(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff
            else:
                print(f"Creating bucket {bucket_name} failed after {max_retries} attempts: {e}")
