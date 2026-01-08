# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import importlib
import pkgutil
from pathlib import Path

from . import v2
from .base_client import BaseClient


class Client(BaseClient):
    """
    A client for interacting with the Geospatial Studio APIs.

    Example usage:
        ```python
        from geostudio import Client
        gfm_client = Client(api_key_file="/.geostudio_apikey")
        gfm_client.list_apikeys()
        ```
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.load_classes(*args, **kwargs)

    def load_classes(self, *args, **kwargs):
        """Dynamically load all classes from subpackages of geostudio.backends.v2"""
        package_path = Path(v2.__file__).parent
        package_name = v2.__name__

        for _, subpkg_name, is_pkg in pkgutil.iter_modules([str(package_path)]):
            if not is_pkg:
                continue

            module_name = f"{package_name}.{subpkg_name}.client"
            module = importlib.import_module(module_name)

            if not hasattr(module, "Client"):
                raise ImportError(f"No Client class found in {module_name}")

            module_class = getattr(module, "Client")
            instance = module_class(*args, **kwargs)

            setattr(self, subpkg_name, instance)

            for method_name, attr in module_class.__dict__.items():
                if method_name.startswith("_"):
                    continue
                if isinstance(attr, property):
                    continue
                method = getattr(instance, method_name)
                if callable(method):
                    # bound_method = types.MethodType(method, self)
                    if hasattr(self, method_name):
                        raise AttributeError(f"Method conflict: {method_name} already exists")
                    setattr(self, method_name, method)

    # ---- API key management
    def list_apikeys(self, output: str = "json"):
        """
        Retrieves a list of API keys associated with the current user.

        Args:
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A dictionary containing the list of API keys. The format depends on the 'output' parameter.
        """
        response = self.http_get(f"{self.api_version}/auth/api-keys", output=output, data_field="results")
        return response

    def create_apikey(self, data: object = {}, output: str = "json"):
        """
        Creates a new API key.

        Args:
            data (dict, optional): A dictionary containing the data to be sent in the request body.
                Defaults to an empty dictionary.
            output (str, optional): The desired output format. Can be either "json" or "xml".
                Defaults to "json".

        Returns:
            dict: The created API key item

        Raises:
            HTTPException: If user already has 2 API keys registered.
        """
        response = self.http_post(f"{self.api_version}/auth/api-keys", data=data, output=output, data_field="results")
        return response

    def activate_apikey(self, apikey_id: str, data={"active": True}, output: str = "json"):
        """
        Activate and deactivate an API Key.

        Args:
            apikey_id (str): The ID of the API key to activate/deactivate.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A message of successful activation/deactivation.
        """
        response = self.http_patch(
            f"{self.api_version}/auth/api-keys?apikey_id={apikey_id}", data=data, output=output, data_field="results"
        )
        return response

    def delete_apikey(self, apikey_id: str, output: str = "json"):
        """
        Deletes an API key by its ID.

        Args:
            apikey_id (str): The ID of the API key to delete.
            output (str, optional): The format of the response. Defaults to "json".

        Returns:
            dict: A message of successful deletion.

        Raises:
            HTTPException: If the API Key does not exist.
        """
        response = self.http_delete(
            f"{self.api_version}/auth/api-keys?apikey_id={apikey_id}", output=output, data_field="results"
        )
        return response
