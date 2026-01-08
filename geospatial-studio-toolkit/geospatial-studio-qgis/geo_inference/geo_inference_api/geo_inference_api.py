# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


# -*- coding: utf-8 -*-

import json

import requests
import urllib3
from qgis.core import Qgis, QgsMessageLog

from .inference_request_builder import InferenceRequestBuilder

# Disable SSL certificate warnings for development APIs
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class GeoInferenceApi:
    """
    Handles all communication with the GeoInference API.
    """

    def __init__(self, base_url: str, inf_url: str):
        self.base_url = base_url
        self.api_key = ""
        self.auth_type = "X-Api-Key"
        self.inf_url = inf_url
        self.builder = InferenceRequestBuilder()

    def set_auth_credentials(self, api_key: str, auth_type: str):
        """Sets the API key and authentication type for subsequent requests."""
        self.api_key = api_key
        self.auth_type = auth_type
        QgsMessageLog.logMessage(
            f"API credentials set. Auth Type: {self.auth_type}",
            "GeoInferenceApi",
            Qgis.Info,
        )

    def list_inferences(self):
        """
        Fetches and returns the list of inferences from the API.
        Returns a tuple (success: bool, data: list or str).
        """
        if not self.api_key:
            return False, "API key not set. Please enter an API key first."

        headers = {"Content-Type": "application/json"}
        headers["X-Api-Key"] = self.api_key

        url = f"{self.base_url}?limit=100&skip=0"

        try:
            response = requests.get(url, headers=headers, timeout=30, verify=False)
            QgsMessageLog.logMessage(
                f"API List Inferences Response Status: {response.status_code}",
                "GeoInferenceApi",
                Qgis.Info,
            )
            QgsMessageLog.logMessage(
                f"API List Inferences Response Text: {response.text[:500]}...",
                "GeoInferenceApi",
                Qgis.Info,
            )

            if response.status_code == 200:
                data = response.json()
                if isinstance(data, dict) and "results" in data:
                    return True, data["results"]
            else:
                try:
                    detail = response.json().get("detail", response.text)
                    if isinstance(detail, list):
                        messages = [err.get("msg", str(err)) for err in detail if isinstance(err, dict)]
                        error_detail = "; ".join(messages) if messages else str(detail)
                    else:
                        error_detail = str(detail)
                except json.JSONDecodeError:
                    error_detail = response.text

                return False, f"API Error {response.status_code}: {error_detail}"
        except requests.exceptions.RequestException as e:
            QgsMessageLog.logMessage(f"API request error: {str(e)}", "GeoInferenceApi", Qgis.Warning)
            return False, f"Connection Error: {str(e)}"
        except json.JSONDecodeError as e:
            QgsMessageLog.logMessage(f"JSON parse error: {str(e)}", "GeoInferenceApi", Qgis.Warning)
            return (
                False,
                f"Response Parsing Error:{str(e)}.Raw response:{response.text[:200]}",
            )
        except Exception as e:
            QgsMessageLog.logMessage(
                f"Unexpected error when listing inferences: {str(e)}",
                "GeoInferenceApi",
                Qgis.Warning,
            )
            return False, f"Unexpected Error: {str(e)}"

    def create_inference_request(
        self,
        bbox,
        model_id=None,
        start_date=None,
        end_date=None,
        description="QGIS Plugin Inference",
        location="Selected Area",
    ):
        """
        create inference request with bounding box from qgis

        Args:
        bbox (list): [west, south, east, north] coordinates
        description (str): Description of the inference
        location (str): Location description

        Returns:
            dict: API request body
        """
        builder = InferenceRequestBuilder()
        return (
            builder.with_bbox(bbox)
            .with_description(description)
            .with_location(location)
            .with_temporal_domain(start_date, end_date)
            .with_model_id(model_id)
            .build()
        )

    def submit_inference_request(
        self,
        bbox,
        model_id,
        start_date,
        end_date,
        description="",
        location="Selected Area",
    ):
        """
        Submit inference request to API

        Args:
            bbox (list): [west, south, east, north] coordinates from QGIS
            description (str): Description of the inference
            location (str): Location description

        Returns:
            tuple: (success: bool, response_data: dict or error_message: str)
        """
        try:
            urllib3.disable_warnings(urllib3.exceptions.InsecurePlatformWarning)
            # Validate bbox
            if not bbox or len(bbox) != 4:
                return (
                    False,
                    "Invalid bounding box. Expected [west, south, east, north]",
                )

            # Validate API key
            if not self.api_key:
                return False, "API key not set. Please enter your API key first."

            request_body = self.create_inference_request(
                bbox,
                model_id,
                start_date,
                end_date,
                description,
                location,
            )

            # Log the request
            QgsMessageLog.logMessage(
                f"Submitting inference request to: {self.base_url}",
                "GeoInference",
                Qgis.Info,
            )
            QgsMessageLog.logMessage(
                f"Request body: {json.dumps(request_body, indent=2)}",
                "GeoInference",
                Qgis.Info,
            )

            # Prepare headers
            headers = {"Content-Type": "application/json", "Accept": "application/json"}
            headers["X-Api-Key"] = self.api_key
            # Make the API request
            response = requests.post(
                self.base_url,
                json=request_body,
                headers=headers,
                timeout=30,
                verify=False,
            )
            # Log response
            QgsMessageLog.logMessage(
                f"API Response Status: {response.status_code}",
                "GeoInference",
                Qgis.Info,
            )
            QgsMessageLog.logMessage(
                f"API Response Headers: {dict(response.headers)}",
                "GeoInference",
                Qgis.Info,
            )

            # Handle response
            if response.status_code == 201:
                try:
                    response_data = response.json()
                    QgsMessageLog.logMessage(
                        f"API Response Data: {json.dumps(response_data, indent=2)}",
                        "GeoInference",
                        Qgis.Info,
                    )
                    return True, response_data
                except json.JSONDecodeError:
                    return False, f"Invalid JSON response: {response.text}"

            elif response.status_code == 422:
                error_msg = f"Validation Error {response.status_code}:{response.text}"
                QgsMessageLog.logMessage(error_msg, "GeoInference", Qgis.Critical)
                return False, error_msg
            else:
                error_msg = f"API request failed with status {response.status_code}:"
                f" {response.text}"
                QgsMessageLog.logMessage(error_msg, "GeoInference", Qgis.Critical)
                return False, error_msg

        except Exception as e:
            error_msg = f"Unexpected error during API request: {str(e)}"
            QgsMessageLog.logMessage(error_msg, "GeoInference", Qgis.Critical)
            return False, error_msg

    def list_models(self):
        """Fetch list of available models from API"""
        if not self.api_key:
            return False, "API key not set."

        headers = {"Content-Type": "application/json", "X-Api-Key": self.api_key}

        models_url = f"{self.inf_url}/v2/models"

        try:
            response = requests.get(models_url, headers=headers, timeout=30, verify=False)

            if response.status_code == 200:
                data = response.json()
                # remove sand box model
                filttered_data = [
                    model for model in data["results"] if model.get("display_name") != "geofm-sandbox-models"
                ]

                data["results"] = filttered_data
                return True, data["results"]
            else:
                return False, f"API Error {response.status_code}: {response.text}"

        except Exception as e:
            return False, f"Connection Error: {str(e)}"

    def get_task_outputs(self, inference_id):
        """Get task outputs from v2 API for a given inference ID."""
        if not self.api_key:
            return False, "API key not set"

        headers = {"Content-Type": "application/json", "X-Api-Key": self.api_key}

        try:
            # Get tasks for the inference
            tasks_url = f"{self.inf_url}/v2/inference/{inference_id}/tasks"
            response = requests.get(tasks_url, headers=headers, timeout=30, verify=False)
            response.raise_for_status()

            tasks_data = response.json()
            task_outputs = []

            # Get task IDs from the response
            task_ids = []
            if isinstance(tasks_data, dict) and "tasks" in tasks_data:
                task_ids = [task.get("task_id") for task in tasks_data["tasks"] if task.get("task_id")]
                QgsMessageLog.logMessage(f"tasks:{task_ids}", "GeoInferenceApi", Qgis.Info)
            elif isinstance(tasks_data, list):
                task_ids = [task.get("task_id") for task in tasks_data if task.get("task_id")]
            QgsMessageLog.logMessage(
                f"Found {len(task_ids)} task IDs: {task_ids}",
                "GeoInferenceApi",
                Qgis.Info,
            )

            # Get output for each task
            for task_id in task_ids:
                try:
                    output_url = f"{self.inf_url}/v2/tasks/{task_id}/output"
                    output_response = requests.get(output_url, headers=headers, timeout=30, verify=False)
                    output_response.raise_for_status()

                    output_data = output_response.json()

                    # Extract presigned URL from output data
                    presigned_url = output_data.get("output_url")

                    if presigned_url:
                        task_outputs.append({"task_id": task_id, "presigned_url": presigned_url})

                except Exception as e:
                    QgsMessageLog.logMessage(
                        f"Error getting output for task {task_id}: {e}",
                        "GeoInferenceApi",
                        Qgis.Warning,
                    )
                    continue

            return True, task_outputs

        except Exception as e:
            QgsMessageLog.logMessage(f"Error getting task outputs: {e}", "GeoInferenceApi", Qgis.Critical)
            return False, f"Error getting task outputs: {str(e)}"
