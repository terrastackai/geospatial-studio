# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import json
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from time import sleep
from uuid import UUID

import boto3
import pandas as pd
import requests
from botocore.exceptions import ClientError
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor
from rich.progress import (
    BarColumn,
    DownloadColumn,
    Progress,
    TextColumn,
    TimeRemainingColumn,
    TransferSpeedColumn,
)

from ....config import settings
from ...base_client import BaseClient
from .models import (
    DataAdvisorIn,
    InferenceCreateInput,
    ModelCreateInput,
    ModelOnboardingInputSchema,
    ModelUpdateInput,
)


class Client(BaseClient):
    """A client for interacting with the Geospatial Studio inference API endpoints"""

    ##############################################
    # Model
    ##############################################

    def create_model(self, data: ModelCreateInput, output: str = "json"):
        """
        Creates a new model using the provided data.

        Args:
            data (ModelCreateInput`): The input data required to create a new model.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The response containing the created model Metadata.
        """
        payload = json.loads(ModelCreateInput(**data).model_dump_json())
        response = self.http_post(f"{self.api_version}/models", data=payload, output=output, data_field="results")
        return response

    def list_models(self, output: str = "json"):
        """
        Lists all available models.

        Args:
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary containing the list of models.
        """
        response = self.http_get(
            endpoint=f"{self.api_version}/models?limit=1000&skip=0", output=output, data_field="results"
        )
        return response

    def update_model(self, model_id: UUID, data: ModelUpdateInput, output: str = "json"):
        """
        Updates metadata of a specified model.

        Args:
            model_id (UUID): The unique identifier of the model to be updated.
            data (dict): A dictionary containing the new metadata for the model.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: The response from the server containing the updated metadata.
        """
        payload = json.loads(ModelUpdateInput(**data).model_dump_json())
        response = self.http_patch(
            f"{self.api_version}/models/{model_id}", data=payload, output=output, data_field="results"
        )
        return response

    def deploy_model(self, model_id: str, data: ModelOnboardingInputSchema, output="json"):
        """
        Deploys a model

        Args:
            model_id (str): The unique identifier of the model to be deployed
            data (ModelOnboardingInputSchema): Urls to the model checkpoint and configs

        """
        payload = json.loads(ModelOnboardingInputSchema(**data).model_dump_json())
        response = self.http_post(
            f"{self.api_version}/models/{model_id}/deploy", data=payload, output=output, data_field="results"
        )
        return response

    def get_model(self, model_id: UUID, output: str = "json"):
        """
        Retrieves a model's information using its ID.

        Parameters:
            model_id (UUID): The unique identifier of the model to retrieve.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The model's status and information
        """
        response = self.http_get(f"{self.api_version}/models/{model_id}", output=output, data_field="results")
        return response

    def delete_model(self, model_id: str, output: str = "json"):
        """
        Deletes a specified model using its ID.

        Args:
            model_id (str): The ID of the model to be deleted.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: The response from the server after deleting the model.
        """
        response = self.http_delete(f"{self.api_version}/models/{model_id}", output=output)
        return response

    ##############################################
    # Inference
    ##############################################

    def submit_inference(self, data: InferenceCreateInput, output: str = "json"):
        """
        Submits an inference task to the server.

        Args:
            data (InferenceCreateInput): The input data for the inference task.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The server's response containing the results of the inference task.
        """
        payload = json.loads(InferenceCreateInput(**data).model_dump_json())
        response = self.http_post(f"{self.api_version}/inference", data=payload, output=output, data_field="results")
        return response

    def list_inferences(self, output: str = "json"):
        """
        Lists inferences submitted to the Studio. Limit to most recent 10.

        Args:
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: A dictionary containing a list of inference tasks submitted to the studio
        """
        response = self.http_get(f"{self.api_version}/inference?limit=10&skip=0", output=output, data_field="results")
        return response

    def get_inference(self, inference_id: UUID, output: str = "json"):
        """
        Retrieves the inference with the given inference ID.

        Args:
            inference_id (uuid.UUID): The unique identifier of the inference task.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The inference task data in the specified output format.
        """
        response = self.http_get(f"{self.api_version}/inference/{inference_id}", output=output, data_field="results")
        return response

    def delete_inference(self, inference_id: UUID, output: str = "json"):
        """
        Deletes an inference using its ID.

        Args:
            inference_id (uuid.UUID): The ID of the inference to be deleted.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: The response from the server after deleting the inference.
        """
        response = self.http_delete(f"{self.api_version}/inference/{inference_id}", output=output)
        return response

    def get_inference_tasks(self, inference_id: UUID, output: str = "json"):
        """
        Retrieves the tasks associated with an inference.

        Args:
            inference_id (uuid.UUID): The unique identifier of the inference.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The inference task data in the specified output format.
        """
        response = self.http_get(
            f"{self.api_version}/inference/{inference_id}/tasks", output=output, data_field="results"
        )
        return response

    def get_task_output_url(self, task_id: UUID, output: str = "json"):
        """
        Retrieves the output url for a specific inference task.

        Args:
            task_id (UUID): The unique identifier of the task.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The inference task data in the specified output format.
        """
        response = self.http_get(f"{self.api_version}/tasks/{task_id}/output", output=output, data_field="results")
        return response

    def get_task_step_logs(self, task_id: UUID, step_id: str, output: str = "json"):
        """
        Retrieves the logs for a specific step of an inference task.

        Args:
            task_id (UUID): The unique identifier of the task.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The inference task data in the specified output format.
        """
        response = self.http_get(
            f"{self.api_version}/tasks/{task_id}/logs/{step_id}", output=output, data_field="results"
        )
        return response

    def inference_task_status_df(self, inference_id: UUID):
        tasks = self.get_inference_tasks(inference_id)["tasks"]

        process_id_list = []
        for t in tasks:
            if t["task_id"].split("_")[-1] != "planning":
                process_id_list = process_id_list + [X["process_id"] for X in t["pipeline_steps"]]

        headers = ["task_id"] + list(set(process_id_list))
        df = pd.DataFrame(columns=headers)

        c = 0
        for i, t in enumerate(tasks):
            if t["task_id"].split("_")[-1] != "planning":
                status = [X["status"] for X in t["pipeline_steps"]]
                df.loc[c] = [t["task_id"]] + status
                c += 1

        for d in range(0, len(df)):
            print(d)

            df["task_id"].loc[d] = (
                "_".join(df["task_id"].loc[d].split("_")[:-1])
                + "_"
                + (df["task_id"].loc[d].split("_")[-1]).zfill(len(str(len(df))))
            )

        df = df.sort_values(by=["task_id"])
        return df

    ##############################################
    # Data availability
    ##############################################
    def check_data_availability(self, datasource: str, data: DataAdvisorIn, output: str = "json"):
        """
        Query data-advisor service to check data availability before running an inference.

        Args:
            data (dict): A dictionary containing the necessary parameters for the data availability check.
            output (str, optional): The desired output format. Default is "json".

        Returns:
            dict: The response from the server containing the data availability information.
        """
        payload = json.loads(DataAdvisorIn(**data).model_dump_json())
        response = self.http_post(
            f"{self.api_version}/data-advice/{datasource}", data=payload, output=output, data_field="results"
        )
        return response

    def list_datasource_collections(self, datasource: str, output: str = "json"):
        """
        Query data-advisor to list collections available for a specific data source
        """
        response = self.http_get(f"{self.api_version}/data-advice/{datasource}", output=output, data_field="results")
        return response

    ##############################################
    # Data sources
    ##############################################
    def list_datasource(
        self, connector: str = None, collection: str = None, limit: int = 25, skip: int = 0, output: str = "json"
    ):
        """
        Lists all data sources available in the studio.

        Args:
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary containing a list of data sources available through the studio
        """
        url = [f"limit={limit}", f"skip={skip}"]

        if connector:
            url.append(f"connector={connector}")
        if collection:
            url.append(f"collection={collection}")
        response = self.http_get(
            f"{self.api_version}/data-sources?{'&'.join(url)}", output=output, data_field="results"
        )
        return response

    def get_datasource(self, datasource_id: UUID, output: str = "json"):
        """
        Retrieves a specific data source's information.

        Args:
            datasource_id (UUID): The unique identifier of the data source to retrieve.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: The response from the server containing the data source details.
        """
        results = self.list_datasource()["results"]
        data_source = list(filter(lambda x: x["id"] == datasource_id, results))
        return data_source

    ##############################################
    #  Files
    ##############################################
    def get_fileshare_links(self, object_name: str):
        """
        Generate presigned urls for sharing files i.e uploading and downloading files.

        Args:
            object_name (str): The name of the object (file) for which to generate upload links.

        Returns:
            dict: A dictionary containing the upload links.
        """
        print("Going to generate the upload link")
        response = self.http_get(
            f"{self.api_version}/file-share?object_name={object_name}", output="json", data_field="results"
        )
        return response

    def upload_file_to_url(self, upload_url: str, filepath: str):
        """
        Uploads a file to a specified URL using a PUT request.

        Args:
            upload_url (str): The URL to which the file will be uploaded.
            filepath (str): The path to the file that will be uploaded.

        Returns:
            requests.Response: The response from the server after the file upload.
        """

        print("Going to upload the file to the url.")

        fields = {}
        path = Path(filepath)
        total_size = path.stat().st_size
        filename = path.name

        with Progress(
            TextColumn("[bold black]{task.description}"),
            BarColumn(),
            DownloadColumn(),
            TransferSpeedColumn(),
            TimeRemainingColumn(),
        ) as progress_bar:
            task = progress_bar.add_task(filename, total=total_size)
            with open(filepath, "rb") as f:
                fields["file"] = ("filename", f)
                e = MultipartEncoder(fields=fields)
                last_bytes = 0

                def monitor_callback(monitor):
                    nonlocal last_bytes
                    bytes_diff = monitor.bytes_read - last_bytes
                    progress_bar.update(task, advance=bytes_diff)
                    last_bytes = monitor.bytes_read

                m = MultipartEncoderMonitor(e, monitor_callback)

                headers = {"Content-Type": m.content_type}
                response = requests.put(upload_url, data=m, headers=headers)
        return response

    def upload_file(self, filename: str):
        """
        Streamlines :py:meth:`get_upload_links` and :py:meth:`upload_file_to_url`.
        Uploads a file to a specified location using the provided upload links.
        """
        links = self.get_fileshare_links(object_name=filename.split("/")[-1])
        # print(links)
        upload_url = links.get("upload_url", None)
        if upload_url:
            self.upload_file_to_url(links["upload_url"], filename)
        return links

    def create_download_presigned_url(
        self,
        bucket_name: str,
        object_key: str,
        endpoint_url: str,
        region_name: str,
        service_name: str,
        aws_access_key_id: str = None,
        aws_secret_access_key: str = None,
        expiration: int = 3600,
        **kwargs,
    ):
        """Function to create presigned url to download object from bucket

        Parameters
        ----------
        bucket_name : str
            The bucket name in the instance
        object_key : str
            Object path to pre-sign
        endpoint_url: str
            s3 Endpoint i.e https://s3.us-east.cloud-object-storage.appdomain.cloud
        region_name: str
            Region where bucket lives. i.e us-east
        service_name: str
            service to connect to i.e s3
        aws_access_key_id: str
            AWS Access key to the instance
        aws_secret_access_key: str
            AWS secret access key to the instance
        expiration : int, optional
            Expiration duration in seconds, by default 3600

        Returns
        -------
        str
            Presigned download url
        """

        s3_client = boto3.client(
            service_name,
            region_name=region_name,
            endpoint_url=endpoint_url,
            aws_secret_access_key=aws_secret_access_key,
            aws_access_key_id=aws_access_key_id,
            **kwargs,
        )
        try:
            download_url = s3_client.generate_presigned_url(
                ClientMethod="get_object",
                Params={"Bucket": bucket_name, "Key": object_key},
                ExpiresIn=expiration,
            )
        except ClientError as e:
            print(f"Error creating presigned URL: {e}")
            return None

        return download_url

    def create_upload_presigned_url(
        self,
        bucket_name: str,
        object_key: str,
        endpoint_url: str,
        region_name: str,
        service_name: str,
        aws_access_key_id: str = None,
        aws_secret_access_key: str = None,
        expiration: int = 3600,
        **kwargs,
    ):
        """Function to create presigned url to upload object from bucket

        Parameters
        ----------
        bucket_name : str
            The bucket name in the instance
        object_key : str
            Object path to pre-sign
        endpoint_url: str
            s3 Endpoint i.e https://s3.us-east.cloud-object-storage.appdomain.cloud
        region_name: str
            Region where bucket lives. i.e us-east
        service_name: str
            service to connect to i.e s3
        aws_access_key_id: str
            AWS Access key to the instance
        aws_secret_access_key: str
            AWS secret access key to the instance
        expiration : int, optional
            Expiration duration in seconds, by default 3600

        Returns
        -------
        str
            Presigned upload url
        """

        s3_client = boto3.client(
            service_name,
            region_name=region_name,
            endpoint_url=endpoint_url,
            aws_secret_access_key=aws_secret_access_key,
            aws_access_key_id=aws_access_key_id,
            **kwargs,
        )
        try:
            upload_url = s3_client.generate_presigned_url(
                ClientMethod="put_object",
                Params={"Bucket": bucket_name, "Key": object_key},
                ExpiresIn=expiration,
            )
        except ClientError as e:
            print(f"Error creating presigned URL: {e}")
            return None

        return upload_url

    ##############################################
    #   Polling
    ##############################################
    def poll_inference_until_finished(self, inference_id, poll_frequency=10):
        """
        Polls the status of an inference task until it is completed or failed.
        Defaults to a minimum of 5seconds poll frequency.

        Args:
            inference_id (str): The unique identifier of the inference task.
            poll_frequency (int, optional): The time interval in seconds between polls. Defaults to 5 seconds.

        Returns:
            dict: The response from the inference task when it is completed or failed.
        """
        poll_frequency = 10 if poll_frequency < 10 else poll_frequency
        finished = False

        while finished is False:
            r = self.get_inference(inference_id)
            status = r["status"]
            time_taken = (
                datetime.now(timezone.utc)
                - datetime.strptime(r["created_at"], "%Y-%m-%dT%H:%M:%S.%fZ").replace(tzinfo=timezone.utc)
            ).seconds

            if "COMPLETED" in status:
                print(status + " - " + str(time_taken) + " seconds")
                finished = True
                return r

            elif status == "FAILED":
                print(status + " - " + str(time_taken) + " seconds")
                finished = True
                return r

            elif status == "STOPPED":
                print(status + " - " + str(time_taken) + " seconds")
                finished = True
                return r

            else:
                print(status + " - " + str(time_taken) + " seconds", end="\r")

            sleep(poll_frequency)

    ##############################################
    #   Geoserver layers
    ##############################################
    def get_geoserver_url(self):
        return f"{settings.BASE_STUDIO_UI_URL}geofm-geoserver"

    def get_layer_timestamps(self, layer_name: str):
        wmts_url = f"{self.get_geoserver_url()}/geoserver/gwc/service/wmts?Version=1.0.0&REQUEST=GetDomainValues&Layer={layer_name}&domain=time"

        response = requests.get(wmts_url)
        root = ET.fromstring(response.text)
        namespace = "{http://demo.geo-solutions.it/share/wmts-multidim/wmts_multi_dimensional.xsd}"

        domain_element = root.find(f"{namespace}Domain")

        if domain_element is not None:
            domain_dates_string = domain_element.text
            domain_dates_list = domain_dates_string.split(",")
            return domain_dates_list
