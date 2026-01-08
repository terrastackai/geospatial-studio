# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os

BASE_URL = os.getenv(
    "GEO_INFERENCE_BASE_URL",
    "https://gfm.res.ibm.com/studio-gateway/v2/inference/",
)
INFERENCE_URL = "https://gfm.res.ibm.com/studio-gateway"
GEOSERVER_URL = "https://gfm.res.ibm.com/geofm-geoserver/geoserver/"
