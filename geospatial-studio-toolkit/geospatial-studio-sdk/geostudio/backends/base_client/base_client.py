# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import json
import logging
import os
import re
from enum import Enum
from typing import Any, Dict, Union
from urllib import parse

import pandas as pd
import requests
from dotenv import dotenv_values

from ..config import GeoFmSettings, settings
from ..exceptions import GeoFMException
from ..session import gfm_session


class ResponseFormats(str, Enum):
    """
    An enumeration representing the supported output formats.

    Attributes:
        JSON: "json"
        DATAFRAME: "df"
        RAW: "raw"
    """

    JSON: Dict[str, Any] = "json"
    DATAFRAME: pd.DataFrame = "df"
    RAW: object = "raw"


def formated_output(
    response, output_fmt: str = ResponseFormats.JSON, data_field: str = None
) -> Union[pd.DataFrame | Dict[str, Any | str]]:
    """
    Formats the response data into the specified output format.

    Parameters:
        response (requests.Response): The HTTP response object.
        output_fmt (str, optional): The desired output format. Defaults to ResponseFormats.JSON.
        data_field (str, optional): The specific data field to extract from the response. Defaults to None.

    Returns:
        dict or pd.DataFrame: The formatted response data.

    Raises:
        ValueError: If the specified output format is not supported.
        json.JSONDecodeError: If the response cannot be parsed as JSON.
    """
    supported_formats = [s.value for s in ResponseFormats]
    if output_fmt not in supported_formats:
        raise ValueError(f"Service `{output_fmt}` is not supported. Valid Options: {supported_formats}")

    try:
        resp_data = response.json()
        if resp_data.get(data_field):
            resp_data = resp_data[data_field]
    except json.JSONDecodeError:
        return {"reason": response.text}

    if output_fmt == ResponseFormats.JSON:
        return response.json()
    elif output_fmt == ResponseFormats.DATAFRAME:
        if data_field:
            df = pd.json_normalize(data=resp_data, sep=".", max_level=1)
        else:
            df = pd.json_normalize(data=resp_data, sep=".", max_level=1)
        return df
    elif output_fmt == ResponseFormats.RAW:
        return response


def _check_auth_error(response):
    """
    Checks if the provided HTTP response indicates an authentication error.

    Parameters:
        response (requests.Response): The HTTP response object to be checked.

    Raises:
        GeoFMException: If the response indicates an authentication error.
    """
    ISV_LOGIN_STRING = "login.ibm.com/oidc/sps"
    try:
        response.json()
    except requests.exceptions.JSONDecodeError:
        if ISV_LOGIN_STRING in response.url:
            raise GeoFMException("401 Unauthorized: Access token provided has either expired or is invalid.")


class BaseClient:
    """
    This class provides methods for making HTTP requests to a Geospatial studio APIs.
    """

    @property
    def api_url(self):
        """
        Process both settings.BASE_GATEWAY_API_URL and settings.BASE_STUDIO_UI_URL
        1. For both ensure they end with /
        2. For settings.BASE_STUDIO_UI_URL it should only have one / and if there are others clip the rest of
           the url after the first / e.g. https//myui.com/
        3. For settings.BASE_GATEWAY_API_URL it should have only one / if it does not have 2 / enclosing poxy
           keyword. e.g. /proxy/ e.g. https//myapi.com/ or https//myapi.com/proxy/ otherwise clip the unwanted
           parts of the url
        4. In the function if settings.BASE_STUDIO_UI_URL is present return the processed UI_URL from 2 above
           and only if settings.BASE_GATEWAY_API_URL is present return it after step 3
        """

        # The pattern for matching: (protocol://domain OR domain) followed by an optional slash /
        BASE_URL_PATTERN = r"(.+?//[^/]+|[^/]+)/?"
        UI_REVERSE_PROXY_FOR_APIS = "/studio-gateway"

        if settings.BASE_GATEWAY_API_URL:
            api_url_temp = settings.BASE_GATEWAY_API_URL.rstrip("/") + "/"

            if UI_REVERSE_PROXY_FOR_APIS in api_url_temp:
                clip_index = api_url_temp.find(UI_REVERSE_PROXY_FOR_APIS) + len(UI_REVERSE_PROXY_FOR_APIS)
                api_url_temp = api_url_temp[:clip_index] + "/"
            else:
                match = re.match(BASE_URL_PATTERN, api_url_temp)
                api_url_temp = match.group(0).rstrip("/") + "/" if match else api_url_temp.rstrip("/") + "/"

            settings.BASE_GATEWAY_API_URL = api_url_temp
            return settings.BASE_GATEWAY_API_URL

        if settings.BASE_STUDIO_UI_URL:
            match = re.match(BASE_URL_PATTERN, settings.BASE_STUDIO_UI_URL)
            ui_url_temp = match.group(0).rstrip("/") + "/" if match else settings.BASE_STUDIO_UI_URL.rstrip("/") + "/"

            settings.BASE_STUDIO_UI_URL = ui_url_temp
            settings.BASE_GATEWAY_API_URL = f'{ui_url_temp.rstrip("/")}{UI_REVERSE_PROXY_FOR_APIS}/'
            return settings.BASE_GATEWAY_API_URL

        return None

    @property
    def api_version(self):
        return settings.GATEWAY_API_VERSION

    def __init__(
        self,
        api_config: GeoFmSettings = None,
        session: requests.Session = None,
        api_token: str = None,
        api_key: str = None,
        api_key_file: str = None,
        geostudio_config_file: str = None,
        *args,
        **kwargs,
    ):
        """
        Initializes the GeoFmClient with the provided configuration.

        Args:
            api_config (GeoFmSettings, optional): The configuration settings for the GeoFm API. Defaults to None.
            session (requests.Session, optional): A pre-configured requests session. Defaults to None.
            api_token (str, optional): The API token for authentication. Defaults to None.
            api_key (str, optional): The API key for authentication. Defaults to None.
            api_key_file (str, optional): The path to the file containing the API key. Defaults to None.
            geostudio_config_file (str): The file path to the geostudio config path containing api_key + base_urls.
            *args: Variable length argument list.
            **kwargs: Arbitrary keyword arguments.

        Raises:
            GeoFMException: If no API token, API key, or API key file is provided.

        Attributes:
            api_config (GeoFmSettings): The configuration settings for the GeoFm API.
            session (requests.Session): A pre-configured requests session.
            logger (logging.Logger): The logger instance for logging messages.
        """
        self.api_config = api_config or GeoFmSettings()

        if api_token:
            print("Using api_token")
            api_token = api_token or GeoFmSettings.GEOFM_API_TOKEN
            self.session = gfm_session(access_token=api_token)
        elif api_key:
            print("Using api_key from sdk command")
            self.session = gfm_session(api_key=api_key)
        elif api_key_file:
            if not os.path.isfile(api_key_file):
                raise GeoFMException("Config file does not exist, Please provide a valid config file.")
            print("Using api_key from file")
            self.session = gfm_session(api_key_file=api_key_file)
        elif geostudio_config_file:
            if not os.path.isfile(geostudio_config_file):
                raise GeoFMException("Config file does not exist, Please provide a valid config file.")
            print("Using api key and base urls from geostudio config file")
            geostudio_config_file_values = dotenv_values(geostudio_config_file)
            settings.BASE_GATEWAY_API_URL = geostudio_config_file_values.get("BASE_GATEWAY_API_URL", "")
            settings.BASE_STUDIO_UI_URL = geostudio_config_file_values.get("BASE_STUDIO_UI_URL", "")
            settings.GEOSTUDIO_API_KEY = geostudio_config_file_values.get("GEOSTUDIO_API_KEY", None)
            self.session = gfm_session(api_key=settings.GEOSTUDIO_API_KEY)
        else:
            raise GeoFMException("Missing APIToken. Add `GEOFM_API_TOKEN` to env variables.")

        # else:
        #     self.session = session or gfm_session(
        #         client_id=self.api_config.ISV_CLIENT_ID,
        #         client_secret=self.api_config.ISV_CLIENT_SECRET,
        #         well_known_url=self.api_config.ISV_WELL_KNOWN,
        #         userinfo_endpoint=self.api_config.ISV_USER_ENDPOINT,
        #     )
        self.logger = logging.getLogger()

    # @property
    # def api_url(self):
    #     """
    #     This method should be overridden in subclasses to provide the specific API URL for the service.
    #     """
    #     raise NotImplementedError("Define the api_url.")

    def http_get(self, endpoint, owner=None, params=None, output=None, data_field=None):
        """
        Sends an HTTP GET request to the specified endpoint.

        Parameters:
            endpoint (str): The endpoint to send the GET request to.
            params (dict, optional): Query parameters to include in the GET request.
            output (str, optional): The desired output format.
            data_field (str, optional): The name of the data field to extract from the response.

        Returns:
            object: The response data in the specified format.
        """
        endpoint = parse.urljoin(self.api_url, endpoint)
        # print(endpoint)
        response = self.session.get(endpoint, params=params)
        _check_auth_error(response=response)
        if output == "raw":
            return response
        else:
            return formated_output(response=response, output_fmt=output, data_field=data_field)

    def http_post(self, endpoint, data, files: dict = None, output=None, data_field=None):
        """
        Sends an HTTP POST request to the specified endpoint with the given data.

        Parameters:
            endpoint (str): The API endpoint to send the POST request to.
            data (dict): The data to be sent in the POST request body.
            output (str, optional): The desired output format.
            data_field (str, optional): The key in the response JSON that contains the desired data.

        Returns:
            object: The response data in the specified format.
        """
        endpoint = parse.urljoin(self.api_url, endpoint)
        if files:
            self.session.headers.pop("Content-Type")
            response = self.session.post(endpoint, data=data, files=files)
        else:
            response = self.session.post(
                endpoint,
                data=json.dumps(data),
            )
        _check_auth_error(response=response)
        return formated_output(response=response, output_fmt=output, data_field=data_field)

    def http_put_file(self, endpoint, file_path, output=None, data_field=None):
        """
        Uploads a file to a specified endpoint using a PUT request.

        Parameters:
            endpoint (str): The URL endpoint to send the PUT request to.
            file_path (str): The path to the file to be uploaded.
            output (str, optional): The format of the response output. Default is None.
            data_field (str, optional): The field in the response to extract.

        Returns:
            dict: The response from the server in the specified output format.
        """
        endpoint = parse.urljoin(self.api_url, endpoint)

        with open(file_path, "rb") as file:
            files = {"file": (file_path, file, "application/x-yaml")}
            # Update file_headers to upload multipart/form-data
            # file_headers = {
            #     "User-Agent": "python-requests/2.32.3",
            #     "Accept-Encoding": "gzip, deflate",
            #     "Accept": "*/*",
            #     "Connection": "keep-alive",
            #     # "Content-Type": "application/json",
            #     "X-API-Key": "pak-M3B7oM4wtrC8lCxStRewwrewG3eayFI2",
            #     "x-request-origin": "python-sdk/",
            # }

            if "Content-Type" in self.session.headers:
                self.session.headers.pop("Content-Type")
            response = self.session.put(url=endpoint, files=files)
            # After updating, Return the headers to before adjusting them
            self.session.headers["Content-Type"] = "application/json"

            return formated_output(response=response, output_fmt=output, data_field=data_field)

    def http_put(self, endpoint, data, output=None, data_field=None, file_path=None):
        """
        Sends an HTTP PUT request to the specified endpoint with the provided data.

        Parameters:
            endpoint (str): The URL endpoint to send the PUT request to.
            data (dict or str): The data to be sent in the PUT request body. If a dictionary, it will be converted to JSON.
            output (str, optional): The desired output format.
            data_field (str, optional): The field in the response to extract.
            file_path (str, optional): If the data is a file path, the file will be read and sent as the request body.

        Returns:
            Any: The formatted response data based on the provided output format.
        """

        endpoint = parse.urljoin(self.api_url, endpoint)
        response = self.session.put(endpoint, data=json.dumps(data))
        _check_auth_error(response=response)
        return formated_output(response=response, output_fmt=output, data_field=data_field)

    def http_patch(self, endpoint, data, output=None, data_field=None):
        """
        Sends a PATCH request to the specified endpoint with the provided data.

        Parameters:
            endpoint (str): The URL endpoint to send the PATCH request to.
            data (dict): The data to be sent in the body of the PATCH request.
            output (str, optional): The format of the response.
            data_field (str, optional): The field in the response to extract.

        Returns:
            Any: The formatted response data, or the raw response if no output format is specified.
        """
        endpoint = parse.urljoin(self.api_url, endpoint)
        response = self.session.patch(endpoint, data=json.dumps(data))
        _check_auth_error(response=response)
        return formated_output(response=response, output_fmt=output, data_field=data_field)

    def http_delete(self, endpoint, output=None, data_field=None):
        """
        Sends a DELETE request to the specified endpoint and returns the response.

        Parameters:
            endpoint (str): The URL endpoint to send the DELETE request to.
            output (str, optional): The format of the response.
            data_field (str, optional): The field in the response to extract.

        Returns:
            object: The response from the DELETE request, formatted according to the 'output' parameter.
        """
        endpoint = parse.urljoin(self.api_url, endpoint)
        response = self.session.delete(endpoint)
        _check_auth_error(response=response)
        return formated_output(response=response, output_fmt=output, data_field=data_field)
