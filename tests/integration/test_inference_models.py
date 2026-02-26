# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


import logging
import os

import pytest

from .data import api_inference_models_and_inference as payloads
from .utils import redacted_response_text

log = logging.getLogger("gateway_tests")
log.setLevel(logging.INFO)

pytestmark = pytest.mark.integration


# ====================== Helper Functions ========================
def env_eval(name: str, default: str = "") -> bool:
    val = os.getenv(name, default).strip().lower()
    return val in {"1", "true", "yes", "y", "on"}


# ====================== Fixtures ================================
@pytest.fixture()
def amo_tests_activate():
    if not env_eval("ALLOW_AMO_TESTS"):
        msg = "\nSet ALLOW_AMO_TESTS=1 to run AMO tasks"
        log.info(msg)
        pytest.skip(msg)


@pytest.fixture()
def create_model(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _create_model(model_payload):

        # PAYLOAD
        payload = model_payload

        # QUERY
        r = gateway.post("/v2/models", json=model_payload)
        log.info(
            "POST /v2/models \nPayload:\n%s \nResponse (redacted)(%s):\n%s",
            payload,
            r.status_code,
            redacted_response_text(r),
        )
        assert r.status_code == 201
        body = r.json()
        model_id = body.get("id")
        assert model_id
        return body

    return _create_model


@pytest.fixture()
def list_models(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _list_models(**overrides):

        # PARAMS
        params = {"limit": 25, "skip": 0, **overrides}

        # QUERY
        r = gateway.get("/v2/models", params=params)
        log.info(
            "GET /v2/models -> (%s)\nPARAMS\n%s \nResponse (redacted)(%s)",
            r.status_code,
            params,
            redacted_response_text(r),
        )
        assert r.status_code == 200
        body = r.json()
        assert isinstance(body, dict), type(body)
        assert "results" in body and isinstance(body["results"], list)
        return body

    return _list_models


@pytest.fixture()
def deploy_model_with_amo(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _deploy_model_with_amo(model_id, **overrides):

        # PARAMS
        # model_id
        params = {
            "fine_tuned_model_id": model_id,
            "model_configs_url": "",  # Need url
            "model_checkpoint_url": "",  # Need url
            **overrides,
        }

        # QUERY
        r = gateway.post(f"/v2/models/{model_id}/deploy", params=params)
        log.info(
            "POST /v2/models/%s/deploy -> (%s)\nPARAMS\n%s \nResponse (redacted)(%s)",
            model_id,
            r.status_code,
            params,
            redacted_response_text(r),
        )

        body = r.json()
        assert isinstance(body, dict), type(body)
        return body, r

    return _deploy_model_with_amo


@pytest.fixture()
def update_model(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _update_model(model_id: str, *, replace: bool = False, **overrides):

        # PARAMS
        # model_id

        # PAYLOAD
        defaults = {
            "display_name": "",
            "description": "string",
            "model_url": "https://example.com/",
            "pipeline_steps": [{"additionalProp1": {}}],
            "geoserver_push": [{"additionalProp1": {}}],
            "model_input_data_spec": [{"additionalProp1": {}}],
            "postprocessing_options": {"additionalProp1": {}},
            "sharable": True,
            "model_onboarding_config": {
                "fine_tuned_model_id": "string",
                "model_configs_url": "string",
                "model_checkpoint_url": "string",
            },
            "latest": True,
            **overrides,
        }
        payload = overrides if replace else {**defaults, **overrides}

        # QUERY
        r = gateway.patch(f"/v2/models/{model_id}", json=payload)
        log.info(
            "PATCH /v2/models/%s -> (%s)\nPayload\n%s \nResponse (redacted)(%s)",
            model_id,
            r.status_code,
            payload,
            redacted_response_text(r),
        )

        body = r.json()
        assert isinstance(body, dict), type(body)
        return body, r

    return _update_model


@pytest.fixture()
def get_model(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _get_model(model_id):

        # PARAMS
        # model_id

        # QUERY
        r = gateway.get(f"/v2/models/{model_id}")
        log.info(
            "GET /v2/models/%s -> (%s)\nResponse (redacted)(%s)",
            model_id,
            r.status_code,
            redacted_response_text(r),
        )

        body = r.json()
        assert isinstance(body, dict), type(body)
        return body, r

    return _get_model


@pytest.fixture()
def delete_model(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _delete_model(model_id):

        # PARAMS
        # model_id

        # QUERY
        r = gateway.delete(f"/v2/models/{model_id}")
        log.info(
            "\nDELETE /v2/models/%s -> (%s)\nResponse (redacted)(%s)",
            model_id,
            r.status_code,
            redacted_response_text(r),
        )
        return r

    return _delete_model


@pytest.fixture()
def retrieve_amo_task(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _retrieve_amo_task(model_id):

        # PARAMS
        # model_id

        # QUERY
        r = gateway.get(f"/v2/amo-tasks/{model_id}")
        log.info(
            "\nGET /v2/amo-tasks/%s -> (%s)\nResponse (redacted)(%s)",
            model_id,
            r.status_code,
            redacted_response_text(r),
        )
        body = r.json()

        return body, r

    return _retrieve_amo_task


@pytest.fixture()
def offboard_inference_model(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _offboard_inference_model(model_id):

        # PARAMS
        # model_id

        # QUERY
        r = gateway.delete(f"/v2/amo-tasks/{model_id}")
        log.info(
            "\nDELETE /v2/amo-tasks/%s -> (%s)\nResponse (redacted)(%s)",
            model_id,
            r.status_code,
            redacted_response_text(r),
        )

        body = r.json()
        assert isinstance(body, dict), type(body)
        return body, r

    return _offboard_inference_model


@pytest.fixture()
def onboard_inference_model(gateway):
    """
    Call /v2/datasets and return the parsed body.
    Each call will hit the endpoint afresh.
    """

    def _onboard_inference_model(*, replace: bool = False, **overrides):

        # PAYLOAD
        DEFAULT_ONBOARD_INFERENCE_MODEL = {
            "model_framework": "terratorch",
            "model_id": "string",
            "model_name": "string",
            "model_configs_url": "https://example.com/",
            "model_checkpoint_url": "https://example.com/",
            "deployment_type": "gpu",
            "resources": {
                "requests": {"cpu": "6", "memory": "16G"},
                "limits": {"cpu": "12", "memory": "32G"},
            },
            "gpu_resources": {
                "requests": {"nvidia.com/gpu": "1"},
                "limits": {"nvidia.com/gpu": "1"},
            },
            "inference_container_image": "",
            **overrides,
        }
        payload = (
            overrides if replace else {**DEFAULT_ONBOARD_INFERENCE_MODEL, **overrides}
        )

        # QUERY
        r = gateway.post("/v2/amo-tasks", json=payload)
        log.info(
            "\nPOST /v2/amo-tasks -> (%s)\nPayload\n%s \nResponse (redacted)(%s)",
            r.status_code,
            payload,
            redacted_response_text(r),
        )

        body = r.json()
        assert isinstance(body, dict), type(body)
        return body, r

    return _onboard_inference_model


# ======================== Tests =================================
# --------[create_model] Tests -----------------------------------
def test_create_model_fixture(create_model, caplog):
    caplog.set_level(logging.INFO, logger="gateway_tests")

    body = create_model(payloads.SANDBOX_MODEL)
    assert "PENDING" == body["status"]


# --------[list_models] Tests ------------------------------------
def test_list_models_fixture(list_models, caplog):
    caplog.set_level(logging.INFO, logger="gateway_tests")
    body = list_models(limit=1)
    assert "total_records" in body
    assert isinstance(body["results"], list)


# --------[deploy_model_with_amo] Tests --------------------------
def test_deploy_model_with_amo_fixture_no_urls(
    deploy_model_with_amo, list_models, caplog
):
    # PARAMS
    list_model_body = list_models()
    model_id = list_model_body["results"][0][
        "id"
    ]  # [TODO] Check different models for errors

    params = {
        "fine_tuned_model_id": model_id,
        "model_configs_url": "",  # Intentional missing url for testing
        "model_checkpoint_url": "",  # Intentional missing url for testing
    }

    caplog.set_level(logging.INFO, logger="gateway_tests")
    body, r = deploy_model_with_amo(model_id, **params)
    assert isinstance(body, dict)
    assert r.status_code == 422
    assert "detail" in body and isinstance(body["detail"], list)
    assert "both model_checkpoint_url" in body["detail"][0]["msg"].lower()
    assert "model_config" in body["detail"][0]["msg"].lower()
    assert "should be" in body["detail"][0]["msg"].lower()


def test_deploy_model_with_amo_fixture_no_urls_and_missing_model_id(
    deploy_model_with_amo, caplog
):
    # PARAMS
    # Sample nonexistent model_id
    model_id = "e436969b-24bf-46e5-ac6f-7d0653da0f14"

    params = {
        "fine_tuned_model_id": model_id,
        "model_configs_url": "",  # Intentional missing url for testing
        "model_checkpoint_url": "",  # Intentional missing url for testing
    }

    caplog.set_level(logging.INFO, logger="gateway_tests")
    body, r = deploy_model_with_amo(model_id, **params)
    assert isinstance(body, dict)
    assert r.status_code == 404
    assert "Model not found" in body["detail"]


# --------[update_model] Tests -----------------------------------
def test_update_model_display_name(name_factory, update_model, list_models, caplog):
    # PARAMS
    list_model_body = list_models()
    model_id = list_model_body["results"][0]["id"]

    caplog.set_level(logging.INFO, logger="gateway_tests")

    # Payload
    display_name = name_factory(base="integration-test")

    payload = {"display_name": display_name}

    body, r = update_model(model_id, replace=True, **payload)
    assert isinstance(body, dict)
    assert r.status_code == 201
    assert display_name == body["display_name"]


def test_update_model_display_name_for_missing_model_id(
    name_factory, update_model, caplog
):
    # PARAMS
    # Sample nonexistent model_id
    model_id = "e436969b-24bf-46e5-ac6f-7d0653da0f14"

    caplog.set_level(logging.INFO, logger="gateway_tests")

    # Payload
    display_name = name_factory(base="integration-test")

    payload = {"display_name": display_name}

    body, r = update_model(model_id, replace=True, **payload)
    assert isinstance(body, dict)
    assert r.status_code == 404
    assert "Model not found" == body["detail"]


# --------[get_model] Tests --------------------------------------
def test_get_model_(get_model, list_models, caplog):
    caplog.set_level(logging.INFO, logger="gateway_tests")

    # PARAMS
    list_model_body = list_models()
    model_id = list_model_body["results"][0]["id"]

    body, r = get_model(model_id)
    assert isinstance(body, dict)
    assert r.status_code == 200


def test_get_model_with_nonexisting_model_id(get_model, caplog):
    caplog.set_level(logging.INFO, logger="gateway_tests")

    # PARAMS
    # Sample nonexistent model_id
    model_id = "e436969b-24bf-46e5-ac6f-7d0653da0f14"

    body, r = get_model(model_id)
    assert isinstance(body, dict)
    assert r.status_code == 404
    assert "Model not found" == body["detail"]


# --------[delete_model] Tests -----------------------------------
def test_delete_model_create_then_delete(
    name_factory, create_model, delete_model, caplog
):
    caplog.set_level(logging.INFO, logger="gateway_tests")

    create_model_body = create_model(payloads.SANDBOX_MODEL)
    model_id = create_model_body["id"]
    delete_model_r = delete_model(model_id)
    assert delete_model_r.status_code == 204


# --------[retrieve_amo_task](2) Tests ------------------------------
def test_retrieve_amo_task_error(
    amo_tests_activate, retrieve_amo_task, list_models, caplog
):
    caplog.set_level(logging.INFO, logger="gateway_tests")

    # PARAMS
    list_model_body = list_models()
    model_id = list_model_body["results"][0]["id"]

    body, r = retrieve_amo_task(model_id)
    assert r.status_code == 422
    assert "Model ID must not exceed 30 characters." == body["detail"]


def test_retrieve_amo_task_onboard_inference_model_then_retrieve_amo_task(
    amo_tests_activate, name_factory, onboard_inference_model, retrieve_amo_task, caplog
):
    caplog.set_level(logging.INFO, logger="gateway_tests")

    # SETUP
    # ---payload
    model_name = name_factory(base="integration-test")
    model_id = name_factory(base="test")
    model_id_amo_compatible = model_id.replace("_", "-")[:30]
    payload_overrides = {
        "model_name": model_name,
        "model_id": model_id_amo_compatible,  # confusing as model_id has 2 meanings
    }
    # --- fixture query
    body, r = onboard_inference_model(**payload_overrides)

    # FIXTURE QUERY
    body, r = retrieve_amo_task(model_id_amo_compatible)

    # TEST
    assert r.status_code == 200
    assert f"amo-{model_id_amo_compatible}" == body["model_id"]


# --------[offboard_inference_model] Tests -----------------------
def test_onboard_inference_model_onboard_then_offboard_inference_model(
    amo_tests_activate,
    name_factory,
    onboard_inference_model,
    offboard_inference_model,
    caplog,
):
    caplog.set_level(logging.INFO, logger="gateway_tests")

    # SETUP
    # ---payload
    model_name = name_factory(base="integration-test")
    model_id = name_factory(base="test")
    model_id_amo_compatible = model_id.replace("_", "-")[:30]
    payload_overrides = {
        "model_name": model_name,
        "model_id": model_id_amo_compatible,  # confusing as model_id has 2 meanings
    }
    # --- fixture query
    body, r = onboard_inference_model(**payload_overrides)

    # FIXTURE QUERY
    offboard_inference_model_body, offboard_inference_model_r = (
        offboard_inference_model(model_id_amo_compatible)
    )

    # TEST
    assert offboard_inference_model_r.status_code == 200
    assert (
        "Model offboarding request submitted"
        == offboard_inference_model_body["message"]
    )


# --------[onboard_inference_model] Tests ------------------------
def test_onboard_inference_model_(
    amo_tests_activate,
    name_factory,
    onboard_inference_model,
    offboard_inference_model,
    caplog,
):
    caplog.set_level(logging.INFO, logger="gateway_tests")

    # PAYLOAD
    model_name = name_factory(base="integration-test")
    model_id = name_factory(base="test")
    model_id_amo_compatible = model_id.replace("_", "-")[:30]
    payload_overrides = {
        "model_name": model_name,
        "model_id": model_id_amo_compatible,  # confusing as model_id has 2 meanings
    }

    # FIXTURE QUERY
    body, r = onboard_inference_model(**payload_overrides)

    # TEST
    assert r.status_code == 200

    # TEARDOWN
    # FIXTURE QUERY
    offboard_inference_model_body, offboard_inference_model_r = (
        offboard_inference_model(model_id_amo_compatible)
    )

    # TEST
    assert offboard_inference_model_r.status_code == 200
    assert (
        "Model offboarding request submitted"
        == offboard_inference_model_body["message"]
    )
