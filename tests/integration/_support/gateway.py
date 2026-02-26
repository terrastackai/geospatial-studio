# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import os
from typing import Any, Dict, Optional
from urllib.parse import urljoin

import requests
from dotenv import find_dotenv, load_dotenv
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class GatewayApiClient:
    def __init__(
        self,
        base_url: str,
        api_key: Optional[str] = None,
        timeout: int = 60,
        verify: Optional[bool | str] = None,
        proxies: Optional[Dict[str, str]] = None,
    ):

        self.base_url = base_url.rstrip("/") + "/"
        self.timeout = timeout
        self.verify = (
            verify if verify is not None else (os.getenv("REQUESTS_CA_BUNDLE") or True)
        )
        self.proxies = proxies

        self.session = requests.Session()
        retry = Retry(
            total=5,
            backoff_factor=0.3,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=frozenset(("GET", "POST", "PATCH", "DELETE")),
        )
        adapter = HTTPAdapter(max_retries=retry)
        self.session.mount("https://", adapter)
        self.session.mount("http://", adapter)

        self.session.headers.update({"Accept": "application/json"})

        # Always use API key
        if api_key:
            key = api_key.strip().strip('"').strip("'")
            if key.endswith("\r"):  # guard against CRLF from copied envs
                key = key[:-1]
            self.session.headers.update({"X-Api-Key": key})

    def _url(self, path: str) -> str:
        return urljoin(self.base_url, path.lstrip("/"))

    # Gateway methods
    def get(self, path: str, **kwargs) -> requests.Response:
        return self.session.get(
            self._url(path),
            timeout=self.timeout,
            verify=self.verify,
            proxies=self.proxies,
            **kwargs,
        )

    def post(self, path: str, json: Any | None = None, **kwargs) -> requests.Response:
        headers = {**self.session.headers, "Content-Type": "application/json"}
        return self.session.post(
            self._url(path),
            headers=headers,
            json=json or {},
            timeout=self.timeout,
            verify=self.verify,
            proxies=self.proxies,
            **kwargs,
        )

    def put(self, path: str, json: Any | None = None, **kwargs) -> requests.Response:
        user_headers = kwargs.pop("headers", None) or {}
        files = kwargs.pop("files", None)

        headers = {**self.session.headers, **user_headers}

        if files is not None:
            # multipart/form-data PUT
            return self.session.put(
                self._url(path),
                headers=headers,
                files=files,
                data=kwargs.pop("data", {}),
                timeout=self.timeout,
                verify=self.verify,
                proxies=self.proxies,
                **kwargs,
            )
        else:
            # JSON PUT
            headers.setdefault("Content-Type", "application/json")
            return self.session.put(
                self._url(path),
                headers=headers,
                json=json or {},
                timeout=self.timeout,
                verify=self.verify,
                proxies=self.proxies,
                **kwargs,
            )

    def patch(self, path: str, json: Any | None = None, **kwargs) -> requests.Response:
        headers = {**self.session.headers, "Content-Type": "application/json"}
        return self.session.patch(
            self._url(path),
            headers=headers,
            json=json or {},
            timeout=self.timeout,
            verify=self.verify,
            proxies=self.proxies,
            **kwargs,
        )

    def delete(self, path: str, **kwargs) -> requests.Response:
        return self.session.delete(
            self._url(path),
            timeout=self.timeout,
            verify=self.verify,
            proxies=self.proxies,
            **kwargs,
        )

    @classmethod
    def from_env(cls) -> "GatewayApiClient":
        load_dotenv(find_dotenv(usecwd=True))
        base = os.environ["BASE_GATEWAY_URL"]
        api_key = os.environ["API_KEY"]  # uses the key *value* (pak-...), not the id
        verify = os.getenv("REQUESTS_CA_BUNDLE") or True
        return cls(base_url=base, api_key=api_key, verify=verify)
