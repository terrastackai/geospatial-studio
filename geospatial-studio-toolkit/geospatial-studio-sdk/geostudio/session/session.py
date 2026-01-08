# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import functools

import requests

from .auth import ISVAuth
from .config import GeoFmSettings


def gfm_session(
    client_id: str = GeoFmSettings.ISV_CLIENT_ID,
    client_secret: str = GeoFmSettings.ISV_CLIENT_SECRET,
    well_known_url: str = GeoFmSettings.ISV_WELL_KNOWN,
    userinfo_endpoint: str = GeoFmSettings.ISV_USER_ENDPOINT,
    grant_type: str = "authorization_code",
    access_token: str = None,
    api_key: str = None,
    api_key_file: str = None,
    timeout: int = 900,
    max_retry: int = 0,
) -> requests.Session:
    """
    Creates and configures a requests.Session object for interacting with the GeoFm API.

    Args:
        client_id (str): The client ID for authentication. Default is :py:attr:`geostudio.config.GeoFmSettings.ISV_CLIENT_ID`.
        client_secret (str): The client secret for authentication. Default is :py:attr:`geostudio.config.GeoFmSettings.ISV_CLIENT_SECRET`.
        well_known_url (str): The well-known URL for OpenID Connect discovery. Default is :py:attr:`geostudio.config.GeoFmSettings.ISV_WELL_KNOWN`.
        userinfo_endpoint (str): The userinfo endpoint for OpenID Connect. Default is :py:attr:`geostudio.config.GeoFmSettings.ISV_USER_ENDPOINT`.
        grant_type (str): The grant type for OAuth2 authentication. Default is "authorization_code".
        access_token (str): The access token for authentication. If provided, this takes precedence over client_id and client_secret.
        api_key (str): The API key for authentication. If provided, this takes precedence over access_token and client_id/client_secret.
        api_key_file (str): The file path to the API key. If provided, this takes precedence over api_key.
        timeout (int): The timeout for requests in seconds. Default is 900.
        max_retry (int): The maximum number of retries for failed requests. Default is 0 (no retries).

    Returns:
        requests.Session: A configured requests.Session object for interacting with the GeoFm API.
    """
    if access_token:
        request_headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {access_token}",
            "x-request-origin": "python-sdk/",
        }

    elif api_key:
        request_headers = {
            "Content-Type": "application/json",
            "X-API-Key": f"{api_key}",
            "x-request-origin": "python-sdk/",
        }

    elif api_key_file:
        with open(api_key_file) as fp:
            api_key = str(fp.readline()).rstrip()

        request_headers = {
            "Content-Type": "application/json",
            "X-API-Key": f"{api_key}",
            "x-request-origin": "python-sdk/",
        }
    else:
        # Authentication Provider
        isv_provider_sdk = ISVAuth(
            client_id=client_id,
            client_secret=client_secret,
            well_known_url=well_known_url,
            userinfo_endpoint=userinfo_endpoint,
            grant_type=grant_type,
        )
        access_token = isv_provider_sdk.authenticate()

        request_headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {access_token}",
            "x-request-origin": "python-sdk/",
        }

    session = requests.Session()
    retries = requests.adapters.Retry(total=max_retry or False, backoff_factor=1, status_forcelist=[502, 503, 504])
    session.mount("https://", requests.adapters.HTTPAdapter(max_retries=retries))
    session.request = functools.partial(session.request, timeout=timeout)

    session.headers.update(request_headers)
    session.verify = False
    return session
