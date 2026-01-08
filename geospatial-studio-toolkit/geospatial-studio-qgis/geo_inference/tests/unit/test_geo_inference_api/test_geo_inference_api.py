# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


"""Unit tests for GeoInferenceApi"""

import sys
from unittest.mock import Mock, patch

import pytest
import responses


# Mock the inference request builder
class MockInferenceRequestBuilder:
    def __init__(self):
        pass


mock_builder_module = Mock()
mock_builder_module.InferenceRequestBuilder = MockInferenceRequestBuilder
sys.modules["inference_request_builder"] = mock_builder_module

from geo_inference.geo_inference_api import GeoInferenceApi  # noqa:E402


class TestGeoInferenceApi:
    """Tests for GeoInferenceApi"""

    @pytest.fixture
    def base_url(self):
        """Create a fresh APi instance for each test"""
        return "https://test-api.com"

    @pytest.fixture
    def api(self, base_url):
        """Create API instamce  for each test"""
        return GeoInferenceApi(base_url)

    @pytest.fixture
    def api_with_key(self, api):
        """Create API instance with credentials set"""
        api.set_auth_credentials("test-key-123", "X-Api-Key")
        return api

    def test_initialization(self, api, base_url):
        """Test that the API class initializes correctly"""

        assert api.base_url == base_url
        assert api.api_key == ""
        assert api.auth_type == "X-Api-Key"
        assert api.inf_url is not None
        assert api.inference_url is not None

    def test_set_auth_credentials(self, api):
        """Test setting authentication credentials"""

        api.set_auth_credentials("test-key-123", "Bearer")

        assert api.api_key == "test-key-123"
        assert api.auth_type == "Bearer"

    def test_list_inferences_no_api_key(self, api):
        """Test that listing inferences without API key fails"""

        success, result = api.list_inferences()

        assert success is False
        assert "API key not set" in result

    def test_list_models_no_api_key(self, api):
        """Test that listing models without API key fails"""
        success, result = api.list_models()

        assert success is False
        assert "API key not set." in result

    @responses.activate
    def test_list_inferences_success(self, api_with_key, base_url):
        """Test successful inference listing"""
        # Mock HTTP response
        mock_response = {
            "results": [
                {"id": "inf-1", "status": "completed"},
                {"id": "inf-2", "status": "processing"},
            ]
        }

        responses.add(responses.GET, f"{base_url}?saved=False", json=mock_response, status=200)

        success, result = api_with_key.list_inferences()

        assert success is True
        assert len(result) == 2
        assert result[0]["id"] == "inf-1"

    @responses.activate
    def test_list_models_success(self, api_with_key):
        """Test successful model listing"""
        mock_models = {
            "results": [
                {"id": "model-1", "display_name": "Test Model 1"},
                {"id": "model-2", "display_name": "Test Model 2"},
            ]
        }
        models_url = f"{api_with_key.inf_url}/v2/models"
        responses.add(responses.GET, models_url, json=mock_models, status=200)

        success, result = api_with_key.list_models()
        assert success is True
        assert len(result) == 2
        assert result[0]["display_name"] == "Test Model 1"

    @responses.activate
    def test_submit_inference_request_success(self, api_with_key):
        """Test successful inference submission"""
        # Mock the create_inference_request method to return predictable data
        with patch.object(api_with_key, "create_inference_request") as mock_create:
            mock_create.return_value = {
                "bbox": [1.0, 2.0, 3.0, 4.0],
                "model_id": "test-model-123",
                "description": "Test inference",
            }

            # Mock successful API response
            mock_response = {
                "id": "inference-12345",
                "status": "submitted",
                "message": "Inference request accepted",
            }

            responses.add(
                responses.POST,
                api_with_key.inference_url,
                json=mock_response,
                status=201,  # Success status for POST
            )

            # Call the method
            success, result = api_with_key.submit_inference_request(
                bbox=[1.0, 2.0, 3.0, 4.0],
                model_id="test-model-123",
                start_date="2020-01-01",
                end_date="2024-12-31",
                description="Test inference",
                location="Test Location",
            )

            # Verify results
            assert success is True
            assert result["id"] == "inference-12345"
            assert result["status"] == "submitted"

            # Verify create_inference_request was called with correct params
            mock_create.assert_called_once_with(
                [1.0, 2.0, 3.0, 4.0],  # bbox
                "test-model-123",  # model_id
                "2020-01-01",  # start_date
                "2024-12-31",  # end_date
                "Test inference",  # description
                "Test Location",  # location
            )

    def test_submit_inference_request_no_api_key(self, api):
        """Test submission without API key"""
        success, result = api.submit_inference_request(
            bbox=[1.0, 2.0, 3.0, 4.0],
            model_id="test-model",
            start_date="2020-01-01",
            end_date="2024-12-31",
        )

        assert success is False
        assert "API key not set" in result

    @responses.activate
    def test_submit_inference_request_validation_error(self, api_with_key):
        """Test API validation error (422 status)"""
        with patch.object(api_with_key, "create_inference_request") as mock_create:
            mock_create.return_value = {"test": "request_data"}

            # Mock validation error response
            responses.add(
                responses.POST,
                api_with_key.inference_url,
                json={"detail": "Invalid model_id format"},
                status=422,
            )

            success, result = api_with_key.submit_inference_request(
                bbox=[1.0, 2.0, 3.0, 4.0],
                model_id="invalid-model-format",
                start_date="2020-01-01",
                end_date="2024-12-31",
            )

            assert success is False
            assert "Validation Error 422" in result
            assert "Invalid model_id format" in result
