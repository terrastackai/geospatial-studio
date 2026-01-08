# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os

from dotenv import load_dotenv


class GeoFmSettings:
    """Config object containing URLS for the GeoFM APIs."""

    BASE_STUDIO_UI_URL = os.getenv("BASE_STUDIO_UI_URL", "")

    # Auth
    ISV_WELL_KNOWN = "https://geostudio.verify.ibm.com/oidc/endpoint/default/.well-known/openid-configuration"
    ISV_ISSUER = "https://geostudio.verify.ibm.com/oidc/endpoint/default"
    ISV_TOKEN_ENDPOINT = "https://geostudio.verify.ibm.com/v1.0/endpoint/default/token"
    ISV_REVOKE_ENPOINT = "https://geostudio.verify.ibm.com/v1.0/endpoint/default/revoke"
    ISV_USER_ENDPOINT = "https://geostudio.verify.ibm.com/v1.0/endpoint/default/userinfo"
    ISV_CLIENT_ID = os.getenv("ISV_CLIENT_ID", None)
    ISV_CLIENT_SECRET = os.getenv("ISV_CLIENT_SECRET", None)

    # new
    GEOFM_API_TOKEN = os.getenv("GEOFM_API_TOKEN", None)
    GEOSTUDIO_API_KEY = os.getenv("GEOSTUDIO_API_KEY", None)

    # merged gateway APIs
    BASE_GATEWAY_API_URL = os.getenv("BASE_GATEWAY_API_URL", "")
    GATEWAY_API_VERSION = os.getenv("GATEWAY_API_VERSION", "v2")
    DATA_ADVISOR_PRE_DAYS = os.getenv("DATA_ADVISOR_PRE_DAYS", 3)
    DATA_ADVISOR_POST_DAYS = os.getenv("DATA_ADVISOR_PRE_DAYS", 3)
    DATA_ADVISOR_MAXCC = os.getenv("DATA_ADVISOR_MAXCC", 90.0)


def get_settings():
    load_dotenv()
    return GeoFmSettings()


settings = get_settings()
