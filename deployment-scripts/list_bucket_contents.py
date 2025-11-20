# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import ibm_boto3
from ibm_botocore.client import Config, ClientError
import os
import argparse

import dotenv

parser = argparse.ArgumentParser(description="Run list bucket content with a specified .env file.")
parser.add_argument('--env-path', type=str, default=None,
                    help="Path to the .env file.")
parser.add_argument('--bkt', type=str, default=None,
                    help="Bucket name")
args = parser.parse_args()
print(args)

if not args.bkt:
    raise "A bucket name must be provided"

if args.env_path:
    env_file_path = os.path.abspath(args.env_path)
    dotenv.load_dotenv(dotenv_path=env_file_path)
else:
    dotenv.load_dotenv()


def get_s3_client():
    cos = ibm_boto3.resource(
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

bucket_name = args.bkt
bucket = cos.Bucket(bucket_name)

try:
    response = bucket.objects.all()

    if not response:
        print(f"No files found in bucket: {bucket_name}")
    else:
        print(f"Bucket {bucket_name} has the following files: \u2714")
        for file in response:
            print(f"- {file.key}")
except:
    print(f"Unable to retrieve bucket {bucket_name} files")
    raise
