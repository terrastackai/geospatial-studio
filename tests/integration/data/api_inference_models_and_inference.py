"""
Example payloads for integration tests.
Each payload is a Python dict, instead of JSON files.
"""

# Base valid model payload
SANDBOX_MODEL = {
    "display_name": "integration-test-sandbox-model",
    "description": "[Integration Test 175933_01we_10oct_25] Early-access test model made available for demonstration or limited user evaluation. These models may include incomplete features or evolving performance characteristics and are intended for feedback and experimentation before full deployment.",
    "pipeline_steps": [
        {"status": "READY", "process_id": "url-connector", "step_number": 0},
        {"status": "WAITING", "process_id": "push-to-geoserver", "step_number": 1},
    ],
    "geoserver_push": [],
    "model_input_data_spec": [
        {
            "bands": [],
            "connector": "sentinelhub",
            "collection": "hls_s30",
            "file_suffix": "S2Hand",
        }
    ],
    "postprocessing_options": {},
    "sharable": False,
    "model_onboarding_config": {
        "fine_tuned_model_id": "",
        "model_configs_url": "",
        "model_checkpoint_url": "",
    },
    "latest": True,
    "version": 1.0,
}

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
}
