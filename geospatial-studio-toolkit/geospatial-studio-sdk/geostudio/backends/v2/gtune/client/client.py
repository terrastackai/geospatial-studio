# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import json
import os
from datetime import datetime, timezone
from time import sleep
from typing import Any

import pandas as pd
import requests
from joblib import Parallel, delayed
from rich.progress import track

# from typing import Annotated, Any
from ....config import settings
from ...base_client import BaseClient
from .models import (
    BaseModelParamsIn,
    BaseModelsIn,
    DatasetOnboardIn,
    DatasetUpdateIn,
    HpoTuneSubmitIn,
    PreScanDatasetIn,
    TaskIn,
    TryOutTuneInput,
    TuneSubmitIn,
    TuneUpdateIn,
    UploadTuneInput,
)

# from fastapi import Body


def create_new_cell(contents):
    """
    Inserts a new cell with the given contents into the current Jupyter notebook.

    Args:
        contents (str): The content to be inserted into the new cell.

    Returns:
        None
    """
    from IPython.core.getipython import get_ipython

    shell = get_ipython()

    payload = dict(
        source="set_next_input",
        text=contents,
        replace=False,
    )
    shell.payload_manager.write_payload(payload, single=False)


class Client(BaseClient):
    ##############################################
    #  Tunes
    ##############################################

    def list_tunes(self, output: str = "json"):
        """
        Lists all fine tuning jobs in the studio.

        Args:
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary containing the list of tunes found.
        """
        response = self.http_get(f"{self.api_version}/tunes", output=output, data_field="results")
        return response

    def get_tune(self, tune_id: str, output: str = "json"):
        """
        Retrieves a tune by ID. If the tune's status is Failed, a pre-signed url for the logs is generated.

        Parameters:
            tune_id (str): The unique identifier of the tune to retrieve.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The tune's status and information
        """
        response = self.http_get(f"{self.api_version}/tunes/{tune_id}", output=output)
        return response

    def update_tune(self, tune_id: str, data: TuneUpdateIn, output: str = "json"):
        """
        Update a tune in the database

        Args:
            tune_id (str): The unique identifier of the tune to be updated.
            data (TuneUpdateIn): A dictionary containing the data to update for the tune.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary of the updated tune.
        """
        payload = json.loads(TuneUpdateIn(**data).model_dump_json())
        response = self.http_patch(f"{self.api_version}/tunes/{tune_id}", data=payload, output=output)
        return response

    def delete_tune(self, tune_id, output: str = "json"):
        """
        Deletes a specified tune using its ID.

        Args:
            tune_id (str): The ID of the tune to be deleted.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: Message of successfully deleted tune
        """
        response = self.http_delete(f"{self.api_version}/tunes/{tune_id}", output=output)
        return response

    def submit_tune(self, data: TuneSubmitIn, output: str = "json"):
        """
        Submit a fine-tuning job to the Geospatial studio platform

        Args:
            data (TuneSubmitIn): Parameters for the tuning job.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The server's response containing the submitted tune info.
        """
        data["name"] = data["name"].lower().replace(" ", "-").replace("_", "-")

        payload = json.loads(TuneSubmitIn(**data).model_dump_json())
        response = self.http_post(f"{self.api_version}/submit-tune", data=payload, output=output)
        return response

    def submit_hpo_tune(self, data: HpoTuneSubmitIn, output: str = "json"):
        """Submit a fine-tuning job with terratorch-iterate enabled.

        Args:
            data (HpoTuneSubmitIn): Parameters for the tuning job
            output ( str, optional):  The desired output format. Defaults to "json".

        Returns:
            dict: The server's response containing the submitted tune info.
        """
        if isinstance(data, dict):
            data = HpoTuneSubmitIn(**data)

        if not os.path.isfile(data.config_file):
            raise ValueError(f"Config file not found: {data.config_file}")
        if os.path.getsize(data.config_file) == 0:
            raise ValueError(f"Config file is empty: {data.config_file}")

        filename = os.path.basename(data.config_file)
        with open(data.config_file, "rb") as fobj:
            config_content = fobj.read()

        files = {"config_file": (filename, config_content, "application/x-yaml")}
        payload = {"tune_metadata": data.tune_metadata.model_dump_json()}
        response = self.http_post(
            f"{self.api_version}/submit-hpo-tune",
            data=payload,
            files=files,
            output=output,
        )
        return response

    def upload_completed_tunes(self, data: UploadTuneInput):
        """
        Upload a completed fine-tuning job to the Geostudio platform

        Args:
            data (UploadTuneInput): Parameters to update the tune with

        Returns:
            dict: Message of successfully uploaded tune
        """
        payload = json.loads(UploadTuneInput(**data).model_dump_json())
        response = self.http_post(f"{self.api_version}/upload-completed-tunes", data=payload, output="json")
        return response

    def try_out_tune(self, tune_id: str, data: TryOutTuneInput):
        """Try-out inference on a tune without deploying the model.

        Args:
            tune_id (str): The unique identifier of the tune experiment.
            data (TryOutTuneInput): The inference configurations to try the tune on

        Returns:
            dict: Dictionary containing the details of the inference submitted.
        """
        payload = json.loads(TryOutTuneInput(**data).model_dump_json())
        response = self.http_post(f"{self.api_version}/tunes/{tune_id}/try-out", data=payload, output="json")
        return response

    def download_tune(self, tune_id: str, output: str = "json"):
        """
        Downloads a tuned model from the server.

        Args:
            tune_id (str): The unique identifier of the tuned model to download.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: Dictionary with tune details including presigned urls to download the artifacts.
        """
        response = self.http_get(f"{self.api_version}/tunes/{tune_id}/download", output=output)
        return response

    def get_mlflow_metrics(self, tune_id: str, output: str = "json"):
        """
        Retrieves the MLflow URLs for the training and testing metrics of a given Tune experiment.

        Args:
            tune_id (str): The ID of the Tune experiment.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary containing the MLflow URLs for the training and testing metrics.
                The dictionary will have the keys "train_mlflow_url" and "test_mlflow_url".
                If no metrics are found, the value for "train_mlflow_url" will be None.
        """
        response = self.get_tune(tune_id)

        ui_url_path = f"{settings.BASE_STUDIO_UI_URL}mlflow/#"
        # Sample output [{'Train': '/experiments/exp_id/runs/run_id'}, {'Test': '/experiments/exp_id/runs/run_id'}]
        train_path = None
        test_path = None
        try:
            if response["metrics"]:
                merged = {k: v for d in response["metrics"] for k, v in d.items()}
                train_path = merged.get("Train")
                test_path = merged.get("Test")

                train_path = f"{ui_url_path}{train_path}"
                if test_path:
                    test_path = f"{ui_url_path}{test_path}"

                return {"train_mlflow_url": train_path, "test_mlflow_url": test_path}
            else:
                print(f"No mlflow url found for {tune_id}")

        except Exception as e:
            print(f"Error getting metrics urls: {e} ")

    def get_tune_metrics(self, tune_id: str, output: str = "json"):
        """
        Retrieves the MLflow metrics for a specific tune.

        Args:
            tune_id (str): The unique identifier of the tune.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: The metrics of the tune in the specified format.
        """
        response = self.http_get(f"{self.api_version}/tunes/{tune_id}/metrics", output=output)
        return response

    def get_tune_metrics_df(self, tune_id: str, run_name: str = "Train"):
        """
        Retrieves the MLflow metrics for a specific tune and displays them in a pandas DataFrame

        Args:
            tune_id (str): The unique identifier of the tune.

        Returns:
            pd.DataFrame: A pandas DataFrame containing the tuning metrics.

        """
        m = self.get_tune_metrics(tune_id)
        if not m.get("runs"):
            return pd.DataFrame()
        run = next((run for run in m.get("runs") if run.get("name") == run_name), {})
        if not run.get("metrics"):
            return pd.DataFrame()
        mdf = pd.DataFrame.from_records(run["metrics"][0])

        for i in range(2, len(run["metrics"])):
            mdf_tmp = pd.DataFrame.from_records(run["metrics"][i]).drop(["epoch"], axis=1)
            mdf = pd.concat([mdf, mdf_tmp], axis=1)

        mdf.sort_values(["epoch"], inplace=True)

        return mdf

    def get_training_image(self, filename: str, train_run_id: str):
        mlflow_url = f"{'/'.join(self.api_url[:-1].split('/')[:-1])}/mlflow"
        response = self.http_get(f"{mlflow_url}/get-artifact?path={filename}&run_uuid={train_run_id}", output="raw")
        img_bytes = response.content
        return img_bytes

    def list_tuning_artefacts(self, tune_id: str):
        """
        Resolve the MLflow training run referenced by a tune and list artefact paths.

        This function:
        - Calls gfm_client.get_tune(tune_id) to obtain tune metadata that contains a
            reference to the MLflow training run (expected under a metric named 'Train').
        - Queries the MLflow server's artifacts list endpoint for that run to obtain
            available artifact file paths.

        Parameters
        ----------
        tune_id : str
            Identifier of the tune (used to lookup metrics that contain the MLflow train run).

        Returns
        -------
        tuple[list[str], str]
            A tuple (art_files, train_run_id) where:
            - art_files : list[str] — list of artifact paths returned by MLflow (from the
                'files' array -> each element's 'path').
            - train_run_id : str — the resolved MLflow run id extracted from the tune metadata.

        Notes
        -----
        - The function expects the tune metadata (gfm_client.get_tune) to include a metric
        mapping containing a 'Train' entry whose value includes the MLflow run UUID (the
        run id is taken as the last path segment after splitting on '/').
        - The MLflow artifacts list response is assumed to include a JSON 'files' array where
        each item has a 'path' key.
        - Example:
            art_files, run_id = list_tuning_artefacts('geotune-xxxxx', 'https://my-mlflow')
        """

        mlflow_url = f"{'/'.join(self.api_url[:-1].split('/')[:-1])}/mlflow"

        tune_info = self.get_tune(tune_id)
        train_run_id = {k: v for d in tune_info["metrics"] for k, v in d.items()}["Train"].split("/")[-1]

        # req = requests.get(f"{mlflow_url}/api/2.0/mlflow/artifacts/list?run_id={train_run_id}")
        print(f"{mlflow_url}/api/2.0/mlflow/artifacts/list?run_id={train_run_id}")
        req = self.http_get(f"{mlflow_url}/api/2.0/mlflow/artifacts/list?run_id={train_run_id}", output="json")
        art_list = req["files"]
        art_files = [X["path"] for X in art_list]
        print(f"Found {len(art_files)} artefacts")
        return art_files, train_run_id

    def get_tuning_artefacts(self, tune_id: str, epochs: list = None, image_numbers: list = None):
        """
        Download fine‑tuning artefact images from an MLflow run referenced by a tune.

        This function:
        - Resolves the MLflow training run id for the given tune via gfm_client.get_tune(...)
        - Lists artefacts for that run from the MLflow server
        - Optionally filters artefact filenames by epoch and/or image number
        - Downloads matching artefacts in parallel and returns a list of records

        Parameters
        ----------
        tune_id : str
            Identifier of the tune (used to lookup metrics that contain the MLflow train run).
        epochs : list[int], optional
            If provided, only artefacts whose filename encodes an epoch contained in this list
            are retained. Filenames are assumed to contain epoch as the second underscore-separated
            token (e.g. "epoch_4_5.png" -> epoch 4).
        image_numbers : list[int], optional
            If provided, only artefacts whose filename encodes an image number contained in this
            list are retained. Filenames are assumed to contain the image number as the third
            underscore-separated token (e.g. "epoch_4_5.png" -> image_number 5).

        Returns
        -------
        list[dict]
            A list of dictionaries, one per downloaded artefact, with keys:
            - 'filename' (str): artefact path from MLflow
            - 'image' (bytes): raw downloaded bytes
            - 'epoch' (int): parsed epoch number
            - 'image_number' (int): parsed image/sample number

        Notes
        -----
        - Downloads are performed in parallel using joblib (threads).
        - The function assumes artefact filenames follow the pattern containing
        "epoch_<epoch>_<image_number>.<ext>".
        """

        requests.packages.urllib3.disable_warnings()
        art_files, train_run_id = self.list_tuning_artefacts(tune_id)

        if epochs is not None:
            art_files = [X for X in art_files if int(X.split("_")[1]) in epochs]
        if image_numbers is not None:
            art_files = [X for X in art_files if int(X.split("_")[2].split(".")[0]) in image_numbers]

        print(f"Downloading {len(art_files)} artefacts...")

        ans = list(
            track(
                Parallel(n_jobs=10, prefer="threads")(
                    delayed(self.get_training_image)(fn, train_run_id) for fn in art_files
                ),
                total=len(art_files),
            )
        )

        print("Downloaded all artefacts")
        img_dict = [
            {
                "filename": art_files[X],
                "image": ans[X],
                "epoch": int(art_files[X].split("_")[1]),
                "image_number": int(art_files[X].split("_")[2].split(".")[0]),
            }
            for X in range(0, len(art_files))
        ]

        return img_dict

    ##############################################
    #  Templates/Tasks
    ##############################################
    def list_tune_templates(self, output: str = "json"):
        """
        Lists tune templates studio.

        Args:
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary containing the list of tune templates in the studio
        """
        response = self.http_get(f"{self.api_version}/tune-templates", output=output, data_field="results")
        return response

    def create_task(self, data: TaskIn, output: str = "json"):
        """
        Creates a new task using the provided data.

        Args:
            data (TaskIn): The data required to create a new task.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: The response from the server containing the details of the newly created task.
        """
        response = self.http_post(f"{self.api_version}/tune-templates", data=data, output=output)
        return response

    def get_task(self, task_id: str, output: str = "json"):
        """
        Retrieves a task by its ID.

        Args:
            task_id (str): The ID of the task to retrieve.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: The response from the server containing the task details.
        """
        response = self.http_get(f"{self.api_version}/tune-templates/{task_id}", output=output, data_field="results")
        return response

    def delete_task(self, task_id, output: str = "json"):
        """
        Deletes a task with the given task_id.

        Args:
            task_id (str): The unique identifier of the task to be deleted.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: Message of successfully deleted task.

        """
        response = self.http_delete(f"{self.api_version}/tune-templates/{task_id}", output=output)
        return response

    def get_task_template(self, task_id: str, output: str = "text"):
        """
        Retrieves the task template yaml for the selected task

        Args:
            task_id (str): The ID of the task to retrieve.
            output (str, optional): The format of the response. Can either be "cell", "text" or "file".

        Returns:
            dict: The response from the server containing the task template yaml.
        """
        response = self.http_get(
            f"{self.api_version}/tune-templates/{task_id}/template", output="json", data_field="results"
        )
        if output == "text":
            return response["reason"]
        elif output == "cell":
            create_new_cell(f"ty = '''{response['reason']}''' ")
        elif output == "file":
            with open(task_id + ".yaml", "w") as fp:
                fp.write(response["reason"])

    def update_task(self, task_id: str, file_path: str, output: str = "json"):
        """
        Updates a task's content with a yaml file config

        Args:
            task_id (str): The ID of the task to upload.
            file_path (str): The path to the file containing the new template.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: Message of successful task upload
        """

        response = self.http_put_file(
            f"{self.api_version}/tune-templates/{task_id}/template", file_path=file_path, output=output
        )
        return response

    def update_task_schema(self, task_id: str, task_schema: Any, output: str = "json"):
        """
        Update the JSONSchema of a task.

        Args:
            task_id (str): The ID of the task to update.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: Message of successful task update
        """

        response = self.http_put(f"{self.api_version}/tune-templates/{task_id}/schema", data=task_schema, output=output)
        return response

    def get_task_param_defaults(self, task_id: str):
        """
        Retrieves the default parameter values for a given task.

        Args:
            task_id (str): The unique identifier of the task.

        Returns:
            dict: A dictionary containing the default parameter values for the task.
                The keys are the parameter names and the values are the default values.
        """
        task_meta = self.get_task(task_id)
        defaults_dict = {}
        for k in task_meta["model_params"]["properties"].keys():
            if "properties" in task_meta["model_params"]["properties"][k]:
                defaults_dict[k] = task_meta["model_params"]["properties"][k]["default"]
        return defaults_dict

    def check_task_content(self, task_id: str, dataset_id: str, base_model_id: Any, output: str = "text"):
        """
        Checks that the the task renders correctly

        Args:
            task_id (str): The ID of the task to check.
            output (str, optional): The format of the returned template. Can be "text", "cell", or "file". Defaults to "text".

        Returns:
            dict: Message of task content
        """
        params = {"dataset_id": dataset_id, "base_model": base_model_id}
        response = self.http_get(
            f"{self.api_version}/tune-templates/{task_id}/test-render", params=params, output="json"
        )
        if output == "text":
            return response["reason"]
        elif output == "cell":
            create_new_cell(f"ty = '''{response['reason']}''' ")
        elif output == "file":
            with open(task_id + ".yaml", "w") as fp:
                fp.write(response["reason"])

    def render_template(self, task_id: str, dataset_id: str, output: str = "text"):
        """
        Checks that the the user defined task renders correctly.

        Args:
            task_id (str): The ID of the task to check.
            dataset_id (str): The ID of the dataset associated with the task.
            output (str, optional): The format of the returned template. Can be "text", "cell", or "file". Defaults to "text".

        Returns:
            dict: The rendered template in the specified output format.
        """
        t_params = {"dataset_id": dataset_id}
        response = self.http_get(
            f"{self.api_version}/tune-templates/{task_id}/test-render-user-defined-task", params=t_params, output="json"
        )
        if output == "text":
            return response["reason"]
        elif output == "cell":
            create_new_cell(f"ty = '''{response['reason']}''' ")
        elif output == "file":
            with open(task_id + ".yaml", "w") as fp:
                fp.write(response["reason"])

    ##############################################
    #  Datasets
    ##############################################

    def list_datasets(self, output: str = "json"):
        """
        Lists all datasets available in the studio.

        Parameters:
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary containing a list of datasets found in the dataset factory
        """
        response = self.http_get(f"{self.api_version}/datasets", output=output, data_field="results")
        return response

    def pre_scan_dataset(self, data: PreScanDatasetIn, output: str = "json"):
        """
        Scans a new dataset - checks accessibility of the dataset URL, ensures corresponding data and label files are present, and extracts bands and their descriptions from the dataset.

        Args:
            data (PreScanDatasetIn): Link to the dataset to scan

        Returns:
            dict: A dictionary containing the scan results.
        """
        payload = json.loads(PreScanDatasetIn(**data).model_dump_json())
        response = self.http_post(f"{self.api_version}/datasets/pre-scan", data=payload, output=output)
        return response

    def get_sample_images(self, dataset_id: str, output: str = "json"):
        """
        Retrieves a sample of images from a specified dataset.

        Args:
            dataset_id (str): The unique identifier of the dataset.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: A dictionary containing the sample data in the requested format.
        """
        response = self.http_get(f"{self.api_version}/datasets/{dataset_id}/sample", output=output)
        return response

    def update_dataset(self, dataset_id: str, data: DatasetUpdateIn, output: str = "json"):
        """
        Update a dataset metadata in the database

        Args:
            dataset_id (str): The unique identifier of the dataset to be updated.
            data (DatasetUpdateIn): A dictionary containing the data to update for the dataset.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary of the updated dataset.
        """
        payload = json.loads(DatasetUpdateIn(**data).model_dump_json())
        response = self.http_patch(f"{self.api_version}/datasets/{dataset_id}", data=payload, output=output)
        return response

    def get_dataset(self, dataset_id: str, output: str = "json"):
        """
        Retrieves a dataset from the studio.

        Parameters:
            dataset_id (str): The unique identifier of the dataset to retrieve.
            output (str, optional): The format of the response. Default is "json".

        Returns:
            dict: Information about the dataset found.
        """
        response = self.http_get(f"{self.api_version}/datasets/{dataset_id}", output=output)
        return response

    def delete_dataset(self, dataset_id: str, output: str = "json"):
        """
        Deletes a dataset with the given ID.

        Args:
            dataset_id (str): The ID of the dataset to delete.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary with a message after dataset is deleted
        """
        response = self.http_delete(f"{self.api_version}/datasets/{dataset_id}", output=output)
        return response

    def onboard_dataset(self, data: DatasetOnboardIn, output: str = "json"):
        """
        Onboards a new dataset to the Geospatial studio.

        Args:
            data (DatasetOnboardIn): The dataset information to be onboarded.
            output (str, optional): The desired output format. Defaults to "json".

        Returns:
            dict: A dictionary containing information about the onboarded dataset.
        """
        payload = json.loads(DatasetOnboardIn(**data).model_dump_json())
        response = self.http_post(f"{self.api_version}/datasets/onboard", data=payload, output=output)
        return response

    ##############################################
    #   Base model
    ##############################################
    def list_base_models(self, output: str = "json"):
        """
        Lists all available base foundation models.

        Parameters:
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary containing a list of base foundation models available in the studio
        """
        response = self.http_get(f"{self.api_version}/base-models", output=output, data_field="results")
        return response

    def create_base_model(self, data: BaseModelsIn, output: str = "json"):
        """
        Create a base foundation model in the Studio.

        Parameters:
            output (str, optional): The format of the response. Defaults to "json".
            data (BaseModelsIn): Parameters for creating the base model.

        Returns:
            dict: A dictionary containing a list of base foundation models available in the studio
        """
        response = self.http_post(f"{self.api_version}/base-models", data=data, output=output, data_field="results")
        return response

    def get_base_model(self, base_id: str, output: str = "json"):
        """
        Get base foundation model by id.

        Parameters:
            base_id (str): Base model ID
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: The Found base model
        """
        response = self.http_get(f"{self.api_version}/base-models/{base_id}", output=output, data_field="results")
        return response

    def update_base_model_params(self, base_id: str, data: BaseModelParamsIn, output: str = "json"):
        """
        Update base foundation model params.

        Parameters:
            base_id (str): Base model ID.
            data (BaseModelParamsIn): Base model params to update.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: Updates Base model params
        """
        response = self.http_patch(
            f"{self.api_version}/base-models/{base_id}/model-params", data=data, output=output, data_field="results"
        )
        return response

    ##############################################
    #   Polling
    ##############################################
    def poll_onboard_dataset_until_finished(self, dataset_id, poll_frequency=10):
        """
        Polls the status of an onboard dataset until it finishes processing.
        Defaults to a minimum of 5seconds poll frequency.

        Args:
            dataset_id (str): The unique identifier of the dataset being onboarded.
            poll_frequency (int, optional): The time interval in seconds between polls. Defaults to 5 seconds.

        Returns:
            dict: The final status of the dataset, either "Succeeded" or "Failed".
        """
        # Default to a minimum of 10 seconds poll frequency.
        poll_frequency = 10 if poll_frequency < 10 else poll_frequency
        finished = False

        while finished is False:
            r = self.get_dataset(dataset_id)
            status = r["status"]
            time_taken = (
                datetime.now(timezone.utc)
                - datetime.strptime(r["created_at"], "%Y-%m-%dT%H:%M:%S.%f%z").replace(tzinfo=timezone.utc)
            ).seconds

            if status == "Succeeded":
                print(status + " - " + str(time_taken) + " seconds")
                finished = True
                return r

            elif status == "Failed":
                print(status + " - " + str(time_taken) + " seconds")
                finished = True
                return r

            else:
                print(status + " - " + str(time_taken) + " seconds", end="\r")

            sleep(poll_frequency)

    def poll_finetuning_until_finished(self, tune_id, poll_frequency=10):
        """
        Polls the status of a tune until it finishes or fails.

        Args:
            tune_id (str): The unique identifier of the tune to poll.
            poll_frequency (int, optional): The time interval in seconds between polls. Defaults to 5 seconds.

        Returns:
            dict: The final status of the tune, including details such as the number of epochs and any error messages if the tune failed.
        """
        # Default to a minimum of 10 seconds poll frequency.
        poll_frequency = 10 if poll_frequency < 10 else poll_frequency
        finished = False

        while finished is False:
            r = self.get_tune(tune_id)
            status = r["status"]
            time_taken = (
                datetime.now(timezone.utc)
                - datetime.strptime(r["created_at"], "%Y-%m-%dT%H:%M:%S.%fZ").replace(tzinfo=timezone.utc)
            ).seconds

            try:
                m = self.get_tune_metrics(tune_id)
                m_epochs = m.get("epochs")
            except Exception:
                m_epochs = "Unknown"

            if status == "Finished":
                print(status + " - Epoch: " + str(m_epochs) + " - " + str(time_taken) + " seconds")
                finished = True
                return r

            elif status == "Failed":
                print(status + " - Epoch: " + str(m_epochs) + " - " + str(time_taken) + " seconds")
                print("Download the logs from the link below:")
                print(r["logs_presigned_url"])
                finished = True
                return r

            else:
                print(status + " - Epoch: " + str(m_epochs) + " - " + str(time_taken) + " seconds", end="\r")

            sleep(poll_frequency)
