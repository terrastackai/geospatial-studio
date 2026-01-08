# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import functools

import requests


class ISVAuth:
    """
    Handles authentication with an Identity Service Provider (ISV).
    """

    def __init__(
        self,
        client_id: str = None,
        client_secret: str = None,
        well_known_url: str = None,
        userinfo_endpoint: str = None,
        grant_type: str = "authorization_code",
    ):
        """

        Initializes an OpenID Connect client.

        Args:
            client_id (str, optional): The client identifier for the application. Defaults to None.
            client_secret (str, optional): The client secret for the application. Defaults to None.
            well_known_url (str, optional): The URL of the OpenID provider's configuration endpoint. Defaults to None.
            userinfo_endpoint (str, optional): The URL of the OpenID provider's userinfo endpoint. Defaults to None.
            grant_type (str, optional): The type of OAuth grant to use. Defaults to "authorization_code".
        """
        self.client_id = client_id
        self.client_secret = client_secret
        self.well_known_url = well_known_url
        self.userinfo_endpoint = userinfo_endpoint
        self.grant_type = grant_type

    def _extract_code(self, input_string):
        """
        Extracts the authorization code from the input string.

        Args:
            input_string (str): The input string containing the authorization code.

        Returns:
            str: The extracted authorization code.
        """
        if "=" in input_string:
            query_params = input_string.split("=")[1]
            code = query_params.split("&")[0]
        else:
            code = input_string

        return code

    def authenticate(self, code=None, redirect_uri=None):
        """
        Authenticates with the ISV and returns the user's access token.

        Args:
            code (str, optional): The authorization code. Defaults to None.
            redirect_uri (str, optional): The redirect URI. Defaults to None.

        Returns:
            str: The user's access token.
        """
        # return user_info
        access_token = ""
        if self.grant_type == "client_credentials":
            payload = {
                "grant_type": self.grant_type,
                "client_id": self.api_config.ISV_CLIENT_ID,
                "client_secret": self.api_config.ISV_CLIENT_SECRET,
                "scope": "openid",
            }
            response = requests.post(self.api_config.ISV_TOKEN_ENDPOINT, data=payload)
            response.raise_for_status()
            access_token = response.json()["id_token"]
            print("\nUsing `client_credentials` grant_type for Auth ...\n\n")

        else:
            redirect_uri = "http://localhost:3000"
            authorization_url = self.get_authorization_url(redirect_uri=redirect_uri)

            print("Click and obtain the code from the url -> ", authorization_url)
            code = self._extract_code(input("Code > "))
            print(f"Your code is: {code}")

            access_token = self.exchange_code_for_token(code, redirect_uri)
            print("\nUsing `authorization_code` grant_type for Auth ...\n\n")

        return access_token

    def get_authorization_url(self, redirect_uri):
        """
        Returns the authorization URL for the ISV.

        Args:
            redirect_uri (str): The redirect URI.

        Returns:
            str: The authorization URL.
        """
        # Construct the authorization URL
        authorization_url = self.get_auth_config(self.well_known_url)["authorization_endpoint"]
        authorization_params = {
            "client_id": self.client_id,
            "response_type": "code",
            "redirect_uri": redirect_uri,
            "scope": "openid",
        }
        authorization_url = f"{authorization_url}?{requests.compat.urlencode(authorization_params)}"

        return authorization_url

    def exchange_code_for_token(self, code, redirect_uri):
        """
        Exchanges an authorization code for an access token.

        Args:
            code (str): The authorization code.
            redirect_uri (str): The redirect URI.

        Returns:
            str: The access token.
        """
        # Make a POST request to the token endpoint to exchange the authorization code for an access token
        token_endpoint = self.get_auth_config(self.well_known_url)["token_endpoint"]
        token_params = {
            "grant_type": self.grant_type,
            "code": code,
            "redirect_uri": redirect_uri,
            "client_id": self.client_id,
            "client_secret": self.client_secret,
        }
        response = requests.post(token_endpoint, data=token_params)
        response.raise_for_status()
        token_data = response.json()

        access_token = token_data["access_token"]
        print(access_token)
        return access_token

    def get_user_info(self, access_token):
        """
        Fetches user information from the ISV's userinfo endpoint.

        Args:
            access_token (str): The user's access token.

        Returns:
            dict: The user information.
        """
        # Make a GET request to the userinfo endpoint to fetch user information
        headers = {"Authorization": f"Bearer {access_token}"}
        response = requests.get(self.userinfo_endpoint, headers=headers)
        response.raise_for_status()
        user_info = response.json()

        return user_info

    @functools.lru_cache
    def get_auth_config(self, well_known_url: str):
        """
        Fetches OAuth configuration from the ISV's well-known endpoint.

        Args:
            well_known_url (str): The URL of the ISV's well-known endpoint.

        Returns:
            dict: The OAuth configuration.
        """
        # Make a GET request to the well-known URL to fetch OAuth configuration
        response = requests.get(well_known_url)
        response.raise_for_status()
        return response.json()
