
#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""
run_labs.py - Runs all 4 Geospatial Studio workshop labs using the geostudio Python SDK.

Labs executed:
  Lab 1 - Getting Started: Connect to Studio, verify platform status
  Lab 2 - Onboarding Examples: Submit AGB Karen pre-computed inference example
  Lab 3 - Upload Model Checkpoints & Run Inference: Upload flood model, run inference
  Lab 4 - Burn Scars Workflow: Register backbone, onboard dataset, fine-tune, run inference

Verification of each step is done via the SDK (list/get calls) and results are
written as structured markdown to the GitHub Actions step summary.

Usage:
    python run_labs.py \
        --api-key <STUDIO_API_KEY> \
        --studio-url <UI_ROUTE_URL> \
        [--notebooks-dir <path>] \
        [--skip-lab4-training] \
        [--skip-lab4-dataset]

    --notebooks-dir defaults to populate-studio/payloads/ (sibling of this script).
    JSON config files required: backbone-Prithvi_EO_V2_300M.json, dataset-burn_scars.json,
    template-seg.json (in payloads/templates/), tune-prithvi-eo-flood.json.

Environment variables (alternative to flags):
    STUDIO_API_KEY      - API key for authentication
    BASE_STUDIO_UI_URL  - Studio UI base URL (e.g. https://localhost:4180)

Run locally (from the geospatial-studio/ directory after deploying with deploy_studio_k8s.sh):
    source .studio-api-key
    python populate-studio/run_labs.py \
        --api-key "${STUDIO_API_KEY}" \
        --studio-url "https://localhost:4180" \
        --skip-lab4-training

    To also skip the dataset onboarding step (faster, no S3 download):
    python populate-studio/run_labs.py \
        --api-key "${STUDIO_API_KEY}" \
        --studio-url "https://localhost:4180" \
        --skip-lab4-dataset
"""

import argparse
import concurrent.futures
import json
import os
import subprocess
import sys
import time
import urllib3
from pathlib import Path

# Force line-buffered stdout so every print() appears immediately in
# GitHub Actions logs (avoids the default block-buffering when stdout
# is not a TTY).
import io as _io
if isinstance(sys.stdout, _io.TextIOWrapper):
    sys.stdout.reconfigure(line_buffering=True)

# Suppress SSL warnings for local/kind deployments
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

SEPARATOR = "=" * 70


def banner(title: str) -> None:
    print(f"\n{SEPARATOR}")
    print(f"  {title}")
    print(f"{SEPARATOR}\n")


def step(msg: str) -> None:
    print(f"  ▶  {msg}")


def ok(msg: str) -> None:
    print(f"  ✅ {msg}")


def warn(msg: str) -> None:
    print(f"  ⚠️  {msg}")


def fail(msg: str) -> None:
    print(f"  ❌ {msg}")


def write_github_summary(content: str) -> None:
    """Append markdown content to the GitHub Actions step summary."""
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a") as fh:
            fh.write(content + "\n")


def _status_icon(status: str) -> str:
    """Return a markdown icon for a given resource status string."""
    s = (status or "").upper()
    if "COMPLETED" in s or s in ("FINISHED", "SUCCEEDED", "READY"):
        return "✅"
    if "FAILED" in s or "ERROR" in s:
        return "❌"
    if "RUNNING" in s or "PENDING" in s or "PROCESSING" in s:
        return "🔄"
    return "⚠️"


def embed_inference_summary(title: str, client, inference_id: str) -> None:
    """
    Fetch the latest inference state via the SDK and write a markdown card
    to the GitHub Actions step summary.
    """
    if not inference_id:
        write_github_summary(f"\n### 🔍 {title}\n\n_No inference ID available._\n")
        return
    try:
        inf = client.get_inference(inference_id=inference_id)
        status = inf.get("status", "UNKNOWN")
        icon = _status_icon(status)
        location = inf.get("location", "N/A")
        description = inf.get("description", "N/A")
        created_at = inf.get("created_at", "N/A")
        model_name = inf.get("model_display_name", "N/A")
        md = (
            f"\n### 🔍 {title}\n\n"
            f"| Field | Value |\n"
            f"|-------|-------|\n"
            f"| Inference ID | `{inference_id}` |\n"
            f"| Status | {icon} `{status}` |\n"
            f"| Model | `{model_name}` |\n"
            f"| Location | {location} |\n"
            f"| Description | {description} |\n"
            f"| Created | {created_at} |\n\n"
        )
        write_github_summary(md)
        ok(f"Inference summary written: {title} [{status}]")
    except Exception as exc:
        warn(f"Could not fetch inference {inference_id} for summary: {exc}")
        write_github_summary(
            f"\n### 🔍 {title}\n\n"
            f"_Could not fetch inference `{inference_id}`: {exc}_\n"
        )


def embed_tune_summary(title: str, client, tune_id: str) -> None:
    """
    Fetch the latest tune/model state via the SDK and write a markdown card
    to the GitHub Actions step summary.
    """
    if not tune_id:
        write_github_summary(f"\n### 🤖 {title}\n\n_No tune ID available._\n")
        return
    try:
        tune = client.get_tune(tune_id)
        status = tune.get("status", "UNKNOWN")
        icon = _status_icon(status)
        name = tune.get("name", "N/A")
        created_at = tune.get("created_at", "N/A")
        md = (
            f"\n### 🤖 {title}\n\n"
            f"| Field | Value |\n"
            f"|-------|-------|\n"
            f"| Tune ID | `{tune_id}` |\n"
            f"| Name | `{name}` |\n"
            f"| Status | {icon} `{status}` |\n"
            f"| Created | {created_at} |\n\n"
        )
        write_github_summary(md)
        ok(f"Tune summary written: {title} [{status}]")
    except Exception as exc:
        warn(f"Could not fetch tune {tune_id} for summary: {exc}")
        write_github_summary(
            f"\n### 🤖 {title}\n\n"
            f"_Could not fetch tune `{tune_id}`: {exc}_\n"
        )


def embed_dataset_summary(title: str, client, dataset_id: str) -> None:
    """
    Fetch the latest dataset state via the SDK and write a markdown card
    to the GitHub Actions step summary.
    """
    if not dataset_id:
        write_github_summary(f"\n### 📦 {title}\n\n_No dataset ID available._\n")
        return
    try:
        ds = client.get_dataset(dataset_id)
        status = ds.get("status", "UNKNOWN")
        icon = _status_icon(status)
        name = ds.get("dataset_name", ds.get("name", "N/A"))
        created_at = ds.get("created_at", "N/A")
        md = (
            f"\n### 📦 {title}\n\n"
            f"| Field | Value |\n"
            f"|-------|-------|\n"
            f"| Dataset ID | `{dataset_id}` |\n"
            f"| Name | `{name}` |\n"
            f"| Status | {icon} `{status}` |\n"
            f"| Created | {created_at} |\n\n"
        )
        write_github_summary(md)
        ok(f"Dataset summary written: {title} [{status}]")
    except Exception as exc:
        warn(f"Could not fetch dataset {dataset_id} for summary: {exc}")
        write_github_summary(
            f"\n### 📦 {title}\n\n"
            f"_Could not fetch dataset `{dataset_id}`: {exc}_\n"
        )


# ---------------------------------------------------------------------------
# SDK client factory
# ---------------------------------------------------------------------------

def build_client(api_key: str, studio_url: str):
    """
    Build and return a geostudio Client instance.
    Sets the required environment variables before importing the SDK so that
    the settings singleton picks them up correctly.
    """
    os.environ["GEOSTUDIO_API_KEY"] = api_key
    os.environ["BASE_STUDIO_UI_URL"] = studio_url.rstrip("/") + "/"

    # Import here so env vars are set first
    from geostudio import Client  # noqa: PLC0415

    client = Client(api_key=api_key)
    return client


# ---------------------------------------------------------------------------
# Polling helpers with timeout + k8s diagnostics
# ---------------------------------------------------------------------------

# Default max wall-clock seconds to wait for any single polling operation.
# Inference typically finishes in 2-5 min; fine-tuning in 30-90 min.
# These are generous upper bounds to catch truly stuck jobs.
POLL_TIMEOUT_INFERENCE_S = int(os.environ.get("POLL_TIMEOUT_INFERENCE_S", "600"))   # 10 min
POLL_TIMEOUT_FINETUNE_S  = int(os.environ.get("POLL_TIMEOUT_FINETUNE_S",  "5400"))  # 90 min
POLL_TIMEOUT_DATASET_S   = int(os.environ.get("POLL_TIMEOUT_DATASET_S",   "1800"))  # 30 min

# Kubernetes namespace where Studio workloads run (matches OC_PROJECT in CI)
K8S_NAMESPACE = os.environ.get("K8S_NAMESPACE", "default")


def dump_k8s_diagnostics(job_hint: str = "") -> None:
    """
    Run kubectl commands to surface pod/job state when a poll times out.
    Prints output directly so it appears in CI logs.
    job_hint: an ID string (inference_id, tune_id, dataset_id) used to
              narrow the pod search via grep.
    """
    ns = K8S_NAMESPACE
    warn(f"⏱  Poll timed out – dumping k8s diagnostics (namespace={ns}, hint={job_hint!r})")

    def _run(cmd: list) -> str:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            return (r.stdout + r.stderr).strip()
        except Exception as e:
            return f"(error running {' '.join(cmd)}: {e})"

    # 1. All pods overview
    pods_out = _run(["kubectl", "get", "pods", "-n", ns, "-o", "wide"])
    print(f"\n--- kubectl get pods -n {ns} ---\n{pods_out}\n")

    # 2. Node resource usage (OOM detection)
    top_out = _run(["kubectl", "top", "nodes"])
    print(f"--- kubectl top nodes ---\n{top_out}\n")

    top_pods = _run(["kubectl", "top", "pods", "-n", ns])
    print(f"--- kubectl top pods -n {ns} ---\n{top_pods}\n")

    # 3. Find pods related to the job hint (by name substring)
    hint_pods: list[str] = []
    if job_hint:
        for line in pods_out.splitlines():
            if job_hint.lower() in line.lower() or "terratorch" in line.lower() or "inference" in line.lower():
                pod_name = line.split()[0] if line.split() else ""
                if pod_name:
                    hint_pods.append(pod_name)

    # Also grab any pods in non-Running/Completed state
    for line in pods_out.splitlines():
        cols = line.split()
        if len(cols) >= 3:
            pod_name, _ready, pod_status = cols[0], cols[1], cols[2]
            if pod_status not in ("Running", "Completed", "NAME") and pod_name not in hint_pods:
                hint_pods.append(pod_name)

    # 4. Describe + logs for each relevant pod
    for pod in hint_pods[:6]:  # cap at 6 pods to avoid log flood
        desc = _run(["kubectl", "describe", "pod", pod, "-n", ns])
        print(f"\n--- kubectl describe pod {pod} -n {ns} ---\n{desc}\n")
        logs = _run(["kubectl", "logs", pod, "-n", ns, "--tail=100", "--all-containers=true"])
        print(f"--- kubectl logs {pod} -n {ns} (last 100 lines) ---\n{logs}\n")

    # 5. Recent events (catches OOMKilled, FailedScheduling, etc.)
    events = _run(["kubectl", "get", "events", "-n", ns, "--sort-by=.lastTimestamp"])
    print(f"--- kubectl get events -n {ns} ---\n{events}\n")


def poll_with_timeout(fn, *, label: str, job_hint: str = "", timeout_s: int) -> dict:
    """
    Run *fn* (a zero-argument callable that wraps an SDK poll call) in a
    background thread.  If it does not complete within *timeout_s* seconds,
    dump k8s diagnostics and raise a TimeoutError so the caller can handle it.

    Returns whatever *fn* returns on success.
    """
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
        future = executor.submit(fn)
        try:
            return future.result(timeout=timeout_s)
        except concurrent.futures.TimeoutError:
            dump_k8s_diagnostics(job_hint=job_hint)
            raise TimeoutError(
                f"{label} did not finish within {timeout_s}s "
                f"(job_hint={job_hint!r}). "
                "See k8s diagnostics above for root cause."
            )


# ---------------------------------------------------------------------------
# Lab 1 – Getting Started
# ---------------------------------------------------------------------------

def run_lab1(client, studio_url: str) -> dict:
    """
    Lab 1: Connect to Studio and verify platform status.
    Returns a dict with counts of datasets, tunes, inferences.
    """
    banner("LAB 1 – Getting Started with IBM Geospatial Studio")

    results = {}

    # --- List datasets ---
    step("Listing datasets...")
    try:
        resp = client.list_datasets()
        datasets = resp.get("results", [])
        total = resp.get("total_records", 0)
        results["datasets"] = total
        ok(f"Datasets in catalog: {total}")
        if total == 0:
            step("Fresh deployment – no datasets yet (expected)")
    except Exception as exc:
        warn(f"list_datasets failed: {exc}")
        results["datasets"] = 0

    # --- List tunes ---
    step("Listing fine-tuned models (tunes)...")
    try:
        resp = client.list_tunes()
        tunes = resp.get("results", [])
        total = resp.get("total_records", 0)
        results["tunes"] = total
        ok(f"Fine-tuned models: {total}")
    except Exception as exc:
        warn(f"list_tunes failed: {exc}")
        results["tunes"] = 0

    # --- List inferences ---
    step("Listing inference requests...")
    try:
        resp = client.list_inferences()
        inferences = resp.get("results", [])
        total = resp.get("total_records", 0)
        results["inferences"] = total
        ok(f"Inference requests: {total}")
    except Exception as exc:
        warn(f"list_inferences failed: {exc}")
        results["inferences"] = 0

    # --- List base models ---
    step("Listing base/backbone models...")
    try:
        resp = client.list_base_models()
        base_models = resp.get("results", [])
        total = resp.get("total_records", 0)
        results["base_models"] = total
        ok(f"Base models: {total}")
    except Exception as exc:
        warn(f"list_base_models failed: {exc}")
        results["base_models"] = 0

    write_github_summary(
        f"\n## 🧪 Lab 1 – Getting Started\n\n"
        f"| Resource | Count |\n"
        f"|----------|-------|\n"
        f"| Datasets | {results.get('datasets', 0)} |\n"
        f"| Fine-tuned Models | {results.get('tunes', 0)} |\n"
        f"| Inference Requests | {results.get('inferences', 0)} |\n"
        f"| Base Models | {results.get('base_models', 0)} |\n\n"
        f"✅ Lab 1 completed – SDK connected successfully\n"
    )

    ok("Lab 1 complete!")
    return results


# ---------------------------------------------------------------------------
# Lab 2 – Onboarding Pre-computed Examples
# ---------------------------------------------------------------------------

def run_lab2(client, studio_url: str) -> dict:
    """
    Lab 2: Onboard the AGB Karen pre-computed inference example.
    Returns dict with inference_id and final status.
    """
    banner("LAB 2 – Onboarding Pre-computed Examples (AGB Karen)")

    agb_karen_payload = {
        "fine_tuning_id": "sandbox",
        "model_display_name": "add-layer-sandbox-model",
        "description": "Above Ground Biomass (AGB) Estimation",
        "location": "Karen, Nairobi, Kenya",
        "spatial_domain": {
            "urls": [
                "https://geospatial-studio-example-data.s3.us-east.cloud-object-storage.appdomain.cloud"
                "/test-add-layer/d5c33eb4-635d-4070-b72c-d57351ab2586_hls-agb_rgb.zip",
                "https://geospatial-studio-example-data.s3.us-east.cloud-object-storage.appdomain.cloud"
                "/test-add-layer/d5c33eb4-635d-4070-b72c-d57351ab2586_hls-agb_pred_postprocessed.zip",
            ]
        },
        "temporal_domain": [],
        "geoserver_push": [
            {
                "workspace": "geofm",
                "layer_name": "karen_agb_rgb",
                "display_name": "2024 Karen AGB RGB",
                "filepath_key": "original_input_image",
                "file_suffix": "",
                "z_index": 0,
                "visible_by_default": "True",
                "geoserver_style": {
                    "rgb": [
                        {"minValue": 0, "maxValue": 255, "channel": 1, "label": "RedChannel"},
                        {"minValue": 0, "maxValue": 255, "channel": 2, "label": "GreenChannel"},
                        {"minValue": 0, "maxValue": 255, "channel": 3, "label": "BlueChannel"},
                    ]
                },
            },
            {
                "workspace": "geofm",
                "layer_name": "karen_agb_pred",
                "display_name": "2024 Karen AGB Prediction",
                "filepath_key": "original_input_image",
                "file_suffix": "",
                "z_index": 1,
                "visible_by_default": "True",
                "geoserver_style": {
                    "regression": [
                        {"color": "#d0ffc9", "quantity": "0", "opacity": 1, "label": "0 MgC/ha"},
                        {"color": "#2dba18", "quantity": "300", "opacity": 1, "label": "300 MgC/ha"},
                    ]
                },
            },
        ],
        "demo": {"demo": True, "section_name": "My Examples"},
    }

    step("Submitting AGB Karen inference example...")
    try:
        response = client.submit_inference(data=agb_karen_payload)
        inference_id = response["id"]
        ok(f"Inference submitted – ID: {inference_id}")
    except Exception as exc:
        fail(f"submit_inference failed: {exc}")
        write_github_summary(
            "\n## 🧪 Lab 2 – Onboarding Examples\n\n❌ Failed to submit inference\n"
        )
        return {"inference_id": None, "status": "FAILED"}

    # --- Poll until finished ---
    step("Polling inference status (this takes 2-5 minutes)...")
    try:
        final = poll_with_timeout(
            lambda: client.poll_inference_until_finished(inference_id=inference_id, poll_frequency=15),
            label="Lab 2 inference",
            job_hint=str(inference_id),
            timeout_s=POLL_TIMEOUT_INFERENCE_S,
        )
        status = final.get("status", "UNKNOWN")
        ok(f"Inference finished with status: {status}")
    except Exception as exc:
        warn(f"Polling error: {exc}")
        try:
            final = client.get_inference(inference_id=inference_id)
            status = final.get("status", "UNKNOWN")
        except Exception:
            status = "UNKNOWN"

    # --- SDK verification: embed inference state in summary ---
    step("Verifying inference via SDK...")
    embed_inference_summary("Lab 2 – AGB Karen Inference Result", client, inference_id)

    write_github_summary(
        f"\n## 🧪 Lab 2 – Onboarding Pre-computed Examples\n\n"
        f"- **Inference ID**: `{inference_id}`\n"
        f"- **Location**: Karen, Nairobi, Kenya\n"
        f"- **Description**: Above Ground Biomass (AGB) Estimation\n"
        f"- **Final Status**: `{status}`\n\n"
        f"{'✅ Lab 2 completed successfully' if 'COMPLETED' in status else '⚠️ Lab 2 finished with status: ' + status}\n"
    )

    ok("Lab 2 complete!")
    return {"inference_id": inference_id, "status": status}


# ---------------------------------------------------------------------------
# Lab 3 – Upload Model Checkpoints and Run Inference
# ---------------------------------------------------------------------------

def run_lab3(client, studio_url: str, notebooks_dir: str) -> dict:
    """
    Lab 3: Create segmentation task template, upload flood model checkpoint,
    run inference on Assam flood event.
    Returns dict with tune_id, template_id, inference_id.
    """
    banner("LAB 3 – Upload Model Checkpoints and Run Inference")

    results = {}

    # --- Step 1: Create segmentation task template ---
    step("Loading segmentation task template...")
    template_path = os.path.join(notebooks_dir, "templates", "template-seg.json")
    try:
        with open(template_path, "r") as fh:
            segmentation_template = json.load(fh)
        ok(f"Loaded template from {template_path}")
    except FileNotFoundError:
        fail(f"template-seg.json not found at {template_path}")
        return {"tune_id": None, "template_id": None, "inference_id": None}

    step("Creating segmentation task template in Studio...")
    tune_template_id = None
    try:
        template_response = client.create_task(segmentation_template)
        tune_template_id = template_response["id"]
        results["template_id"] = tune_template_id
        ok(f"Task template created – ID: {tune_template_id}")
    except Exception as exc:
        warn(f"create_task failed (may already exist): {exc}")
        try:
            templates = client.list_tune_templates()
            existing = [
                t for t in templates.get("results", [])
                if t.get("name") == segmentation_template.get("name")
            ]
            if existing:
                tune_template_id = existing[0]["id"]
                results["template_id"] = tune_template_id
                ok(f"Using existing template – ID: {tune_template_id}")
            else:
                fail("Could not create or find segmentation template")
                return {"tune_id": None, "template_id": None, "inference_id": None}
        except Exception as exc2:
            fail(f"Could not list templates: {exc2}")
            return {"tune_id": None, "template_id": None, "inference_id": None}

    # --- Step 2: Upload flood model checkpoint ---
    step("Loading flood model checkpoint configuration...")
    checkpoint_path = os.path.join(notebooks_dir, "tunes", "tune-prithvi-eo-flood.json")
    try:
        with open(checkpoint_path, "r") as fh:
            flood_checkpoint = json.load(fh)
        ok(f"Loaded checkpoint config from {checkpoint_path}")
    except FileNotFoundError:
        fail(f"tune-prithvi-eo-flood.json not found at {checkpoint_path}")
        return {"tune_id": None, "template_id": tune_template_id, "inference_id": None}

    step("Uploading flood detection model checkpoint (1-2 minutes)...")
    tune_id = None
    try:
        tune_response = client.upload_completed_tunes(flood_checkpoint)
        tune_id = tune_response["tune_id"]
        results["tune_id"] = tune_id
        ok(f"Model checkpoint uploaded – Tune ID: {tune_id}")
    except Exception as exc:
        fail(f"upload_completed_tunes failed: {exc}")
        return {"tune_id": None, "template_id": tune_template_id, "inference_id": None}

    # --- Poll until model is ready ---
    step("Waiting for model to be ready...")
    try:
        poll_with_timeout(
            lambda: client.poll_finetuning_until_finished(tune_id=tune_id, poll_frequency=15),
            label="Lab 3 model ready",
            job_hint=str(tune_id),
            timeout_s=POLL_TIMEOUT_INFERENCE_S,
        )
        ok("Model is ready for inference!")
    except Exception as exc:
        warn(f"Polling error: {exc}")

    # --- SDK verification: embed tune state in summary ---
    step("Verifying model upload via SDK...")
    embed_tune_summary("Lab 3 – Flood Model Upload", client, tune_id)

    # --- Step 3: Run inference ---
    step("Submitting flood detection inference (Assam, India)...")
    # Note: fine_tuning_id is NOT included in the body – it is already
    # encoded in the URL path (/v2/tunes/{tune_id}/try-out).
    # TryOutTuneInput has no fine_tuning_id field; including it causes a 400.
    #
    # The server requires geoserver_push and model_input_data_spec to be present
    # either in the request body or in tune_meta.train_options. For uploaded
    # checkpoints these may not be stored in train_options, so we pass them
    # explicitly from the checkpoint config that was used to upload the tune.
    inference_payload = {
        "model_display_name": "flood-detection-demo",
        "location": "Dakhin Petbaha, Raha, Nagaon, Assam, India",
        "description": "Flood detection in Assam using Sentinel-2",
        "spatial_domain": {
            "bbox": [[92.703396, 26.247896, 92.748087, 26.267903]],
            "urls": [],
            "tiles": [],
            "polygons": [],
        },
        "temporal_domain": ["2024-07-25_2024-07-28"],
        "model_input_data_spec": flood_checkpoint.get("model_input_data_spec"),
        "geoserver_push": flood_checkpoint.get("geoserver_push"),
        "post_processing": flood_checkpoint.get("post_processing"),
    }

    inference_id = None
    try:
        inference_response = client.try_out_tune(tune_id=tune_id, data=inference_payload)
        inference_id = inference_response.get("inference_id", inference_response.get("id"))
        results["inference_id"] = inference_id
        ok(f"Inference submitted – ID: {inference_id}")
    except Exception as exc:
        warn(f"try_out_tune failed: {exc}")
        results["inference_id"] = None

    # --- Poll inference if we have an ID ---
    if inference_id:
        step("Polling flood inference status...")
        try:
            final = poll_with_timeout(
                lambda: client.poll_inference_until_finished(
                    inference_id=inference_id, poll_frequency=15
                ),
                label="Lab 3 flood inference",
                job_hint=str(inference_id),
                timeout_s=POLL_TIMEOUT_INFERENCE_S,
            )
            inf_status = final.get("status", "UNKNOWN")
            ok(f"Flood inference finished: {inf_status}")
            results["inference_status"] = inf_status
        except Exception as exc:
            warn(f"Inference polling error: {exc}")
            results["inference_status"] = "UNKNOWN"

        # SDK verification: embed inference state in summary
        step("Verifying flood inference via SDK...")
        embed_inference_summary("Lab 3 – Flood Detection Inference", client, inference_id)

    write_github_summary(
        f"\n## 🧪 Lab 3 – Upload Model Checkpoints & Run Inference\n\n"
        f"- **Template ID**: `{results.get('template_id', 'N/A')}`\n"
        f"- **Tune ID (Flood Model)**: `{results.get('tune_id', 'N/A')}`\n"
        f"- **Inference ID**: `{results.get('inference_id', 'N/A')}`\n"
        f"- **Inference Status**: `{results.get('inference_status', 'N/A')}`\n\n"
        f"✅ Lab 3 completed\n"
    )

    ok("Lab 3 complete!")
    return results


# ---------------------------------------------------------------------------
# Lab 4 – Burn Scars End-to-End Workflow
# ---------------------------------------------------------------------------

def run_lab4(
    client,
    studio_url: str,
    notebooks_dir: str,
    skip_training: bool = False,
    skip_dataset: bool = False,
) -> dict:
    """
    Lab 4: Full end-to-end burn scars workflow.
      1. Register Prithvi-EO-V2-300M backbone
      2. Onboard burn scars training dataset (skipped if skip_dataset=True)
      3. Create segmentation task template
      4. Submit fine-tuning job (skipped if skip_training=True)
      5. Poll training until finished
      6. Run inference on Park Fire 2024

    Returns dict with all IDs and statuses.
    """
    banner("LAB 4 – Burn Scars End-to-End Workflow")

    results = {}

    # ---- Step 1: Register backbone model ----
    step("Loading Prithvi-EO-V2-300M backbone configuration...")
    backbone_path = os.path.join(notebooks_dir, "backbones", "backbone-Prithvi_EO_V2_300M.json")
    try:
        with open(backbone_path, "r") as fh:
            backbone = json.load(fh)
        ok(f"Loaded backbone config from {backbone_path}")
    except FileNotFoundError:
        fail(f"backbone-Prithvi_EO_V2_300M.json not found at {backbone_path}")
        return results

    step("Registering Prithvi-EO-V2-300M foundation model...")
    base_model_id = None
    try:
        backbone_response = client.create_base_model(backbone)
        base_model_id = backbone_response["id"]
        results["base_model_id"] = base_model_id
        ok(f"Foundation model registered – ID: {base_model_id}")
    except Exception as exc:
        warn(f"create_base_model failed (may already exist): {exc}")
        try:
            base_models = client.list_base_models()
            existing = [
                m for m in base_models.get("results", [])
                if m.get("name") == backbone.get("name")
            ]
            if existing:
                base_model_id = existing[0]["id"]
                results["base_model_id"] = base_model_id
                ok(f"Using existing backbone – ID: {base_model_id}")
            else:
                fail("Could not create or find backbone model")
                return results
        except Exception as exc2:
            fail(f"Could not list base models: {exc2}")
            return results

    # ---- Step 2: Onboard burn scars dataset ----
    dataset_id = None
    if skip_dataset:
        warn("Skipping dataset onboarding (--skip-lab4-dataset flag set)")
        warn("Note: fine-tuning step will be skipped too without a dataset_id")
    else:
        step("Loading burn scars dataset configuration...")
        dataset_path = os.path.join(notebooks_dir, "datasets", "dataset-burn_scars.json")
        try:
            with open(dataset_path, "r") as fh:
                wild_fire_dataset = json.load(fh)
            ok(f"Loaded dataset config from {dataset_path}")
        except FileNotFoundError:
            fail(f"dataset-burn_scars.json not found at {dataset_path}")
            return results

        step("Onboarding burn scars training dataset (may take several minutes)...")
        try:
            onboard_response = client.onboard_dataset(data=wild_fire_dataset)
            dataset_id = onboard_response["dataset_id"]
            results["dataset_id"] = dataset_id
            ok(f"Dataset onboarding initiated – ID: {dataset_id}")
        except Exception as exc:
            warn(f"onboard_dataset failed (may already exist): {exc}")
            try:
                datasets = client.list_datasets()
                existing = [
                    d for d in datasets.get("results", [])
                    if d.get("dataset_name") == wild_fire_dataset.get("dataset_name")
                ]
                if existing:
                    dataset_id = existing[0]["id"]
                    results["dataset_id"] = dataset_id
                    ok(f"Using existing dataset – ID: {dataset_id}")
                else:
                    fail("Could not create or find burn scars dataset")
                    return results
            except Exception as exc2:
                fail(f"Could not list datasets: {exc2}")
                return results

        # Poll dataset onboarding
        if dataset_id:
            step("Polling dataset onboarding status...")
            try:
                final_ds = poll_with_timeout(
                    lambda: client.poll_onboard_dataset_until_finished(
                        dataset_id=dataset_id, poll_frequency=15
                    ),
                    label="Lab 4 dataset onboarding",
                    job_hint=str(dataset_id),
                    timeout_s=POLL_TIMEOUT_DATASET_S,
                )
                ds_status = final_ds.get("status", "UNKNOWN")
                results["dataset_status"] = ds_status
                ok(f"Dataset onboarding finished: {ds_status}")
            except Exception as exc:
                warn(f"Dataset polling error: {exc}")
                results["dataset_status"] = "UNKNOWN"

            # SDK verification: embed dataset state in summary
            step("Verifying dataset via SDK...")
            embed_dataset_summary("Lab 4 – Burn Scars Dataset", client, dataset_id)

    # ---- Step 3: Create segmentation task template ----
    step("Loading segmentation task template...")
    template_path = os.path.join(notebooks_dir, "templates", "template-seg.json")
    tune_template_id = None
    try:
        with open(template_path, "r") as fh:
            segmentation_template = json.load(fh)
        ok(f"Loaded template from {template_path}")
    except FileNotFoundError:
        fail(f"template-seg.json not found at {template_path}")
        return results

    step("Creating segmentation task template...")
    try:
        template_response = client.create_task(segmentation_template)
        tune_template_id = template_response["id"]
        results["template_id"] = tune_template_id
        ok(f"Task template created – ID: {tune_template_id}")
    except Exception as exc:
        warn(f"create_task failed (may already exist): {exc}")
        try:
            templates = client.list_tune_templates()
            existing = [
                t for t in templates.get("results", [])
                if t.get("name") == segmentation_template.get("name")
            ]
            if existing:
                tune_template_id = existing[0]["id"]
                results["template_id"] = tune_template_id
                ok(f"Using existing template – ID: {tune_template_id}")
        except Exception:
            pass

    if not tune_template_id:
        fail("No task template available – cannot submit fine-tuning job")
        return results

    # ---- Step 4: Submit fine-tuning job ----
    tune_id = None
    # Skip training if explicitly requested OR if dataset was skipped (no dataset_id to train on)
    _skip_reason = (
        "--skip-lab4-training flag set" if skip_training
        else "--skip-lab4-dataset flag set (no dataset_id)" if not dataset_id
        else None
    )
    if _skip_reason:
        warn(f"Skipping fine-tuning ({_skip_reason})")
        warn("Note: inference step will be skipped too without a tune_id")
        write_github_summary(
            "\n## 🧪 Lab 4 – Burn Scars Workflow\n\n"
            f"- **Base Model ID**: `{base_model_id}`\n"
            f"- **Dataset ID**: `{dataset_id or 'N/A (skipped)'}`\n"
            f"- **Dataset Status**: `{results.get('dataset_status', 'N/A')}`\n"
            f"- **Template ID**: `{tune_template_id}`\n"
            f"- **Fine-tuning**: Skipped ({_skip_reason})\n\n"
            f"⚠️ Lab 4 partially completed (training skipped)\n"
        )
        return results

    step("Submitting burn scars fine-tuning job...")
    tune_payload = {
        "name": "burn-scars-demo",
        "description": "Segmentation model for wildfire burn scar detection",
        "dataset_id": dataset_id,
        "base_model_id": base_model_id,
        "tune_template_id": tune_template_id,
    }

    try:
        tune_submitted = client.submit_tune(tune_payload, output="json")
        tune_id = tune_submitted["tune_id"]
        results["tune_id"] = tune_id
        ok(f"Fine-tuning job submitted – Tune ID: {tune_id}")
        step("Training will take 30-90 minutes depending on GPU availability")
    except Exception as exc:
        fail(f"submit_tune failed: {exc}")
        write_github_summary(
            "\n## 🧪 Lab 4 – Burn Scars Workflow\n\n"
            f"- **Base Model ID**: `{base_model_id}`\n"
            f"- **Dataset ID**: `{dataset_id}`\n"
            f"- **Template ID**: `{tune_template_id}`\n"
            f"- **Fine-tuning**: ❌ Failed to submit\n\n"
            f"❌ Lab 4 failed at fine-tuning submission\n"
        )
        return results

    # ---- Step 5: Poll training ----
    step("Polling fine-tuning progress (30-90 minutes)...")
    try:
        poll_with_timeout(
            lambda: client.poll_finetuning_until_finished(tune_id=tune_id, poll_frequency=30),
            label="Lab 4 fine-tuning",
            job_hint=str(tune_id),
            timeout_s=POLL_TIMEOUT_FINETUNE_S,
        )
        ok("Fine-tuning completed!")
        results["tune_status"] = "Finished"
    except Exception as exc:
        warn(f"Fine-tuning polling error: {exc}")
        try:
            tune_info = client.get_tune(tune_id)
            results["tune_status"] = tune_info.get("status", "UNKNOWN")
        except Exception:
            results["tune_status"] = "UNKNOWN"

    # SDK verification: embed tune state in summary
    step("Verifying fine-tuning via SDK...")
    embed_tune_summary("Lab 4 – Burn Scars Fine-Tuning", client, tune_id)

    # ---- Step 6: Run inference on Park Fire 2024 ----
    step("Submitting burn scar inference (Park Fire, California, Aug 2024)...")
    inference_payload = {
        "model_display_name": "burn-scars-demo",
        "location": "Red Bluff, California, United States",
        "description": "Park Fire Aug 2024",
        "spatial_domain": {
            "bbox": [],
            "urls": [
                "https://geospatial-studio-example-data.s3.us-east.cloud-object-storage.appdomain.cloud"
                "/examples-for-inference/park_fire_scaled.tif"
            ],
            "tiles": [],
            "polygons": [],
        },
        "temporal_domain": ["2024-08-12"],
        "pipeline_steps": [
            {"status": "READY", "process_id": "url-connector", "step_number": 0},
            {"status": "WAITING", "process_id": "terratorch-inference", "step_number": 1},
            {"status": "WAITING", "process_id": "postprocess-generic", "step_number": 2},
            {"status": "WAITING", "process_id": "push-to-geoserver", "step_number": 3},
        ],
        "post_processing": {
            "cloud_masking": "False",
            "ocean_masking": "False",
            "snow_ice_masking": None,
            "permanent_water_masking": "False",
        },
        "model_input_data_spec": [
            {
                "bands": [
                    {"index": "0", "RGB_band": "B", "band_name": "Blue", "scaling_factor": "0.0001"},
                    {"index": "1", "RGB_band": "G", "band_name": "Green", "scaling_factor": "0.0001"},
                    {"index": "2", "RGB_band": "R", "band_name": "Red", "scaling_factor": "0.0001"},
                    {"index": "3", "band_name": "NIR_Narrow", "scaling_factor": "0.0001"},
                    {"index": "4", "band_name": "SWIR1", "scaling_factor": "0.0001"},
                    {"index": "5", "band_name": "SWIR2", "scaling_factor": "0.0001"},
                ],
                "connector": "sentinelhub",
                "collection": "hls_l30",
                "file_suffix": "_merged.tif",
                "modality_tag": "HLS_L30",
            }
        ],
        "geoserver_push": [
            {
                "z_index": 0,
                "workspace": "geofm",
                "layer_name": "input_rgb",
                "file_suffix": "",
                "display_name": "Input image (RGB)",
                "filepath_key": "model_input_original_image_rgb",
                "geoserver_style": {
                    "rgb": [
                        {"label": "RedChannel", "channel": 1, "maxValue": 255, "minValue": 0},
                        {"label": "GreenChannel", "channel": 2, "maxValue": 255, "minValue": 0},
                        {"label": "BlueChannel", "channel": 3, "maxValue": 255, "minValue": 0},
                    ]
                },
                "visible_by_default": "True",
            },
            {
                "z_index": 1,
                "workspace": "geofm",
                "layer_name": "pred",
                "file_suffix": "",
                "display_name": "Model prediction",
                "filepath_key": "model_output_image",
                "geoserver_style": {
                    "segmentation": [
                        {"color": "#000000", "label": "ignore", "opacity": 0, "quantity": "-1"},
                        {"color": "#000000", "label": "no-data", "opacity": 0, "quantity": "0"},
                        {"color": "#ab4f4f", "label": "fire-scar", "opacity": 1, "quantity": "1"},
                    ]
                },
                "visible_by_default": "True",
            },
        ],
    }

    inference_id = None
    try:
        inference_response = client.try_out_tune(tune_id=tune_id, data=inference_payload)
        inference_id = inference_response.get("inference_id", inference_response.get("id"))
        results["inference_id"] = inference_id
        ok(f"Inference submitted – ID: {inference_id}")
    except Exception as exc:
        warn(f"try_out_tune failed: {exc}")

    # Poll inference
    if inference_id:
        step("Polling burn scar inference status...")
        try:
            final_inf = poll_with_timeout(
                lambda: client.poll_inference_until_finished(
                    inference_id=inference_id, poll_frequency=15
                ),
                label="Lab 4 burn scar inference",
                job_hint=str(inference_id),
                timeout_s=POLL_TIMEOUT_INFERENCE_S,
            )
            inf_status = final_inf.get("status", "UNKNOWN")
            results["inference_status"] = inf_status
            ok(f"Burn scar inference finished: {inf_status}")
        except Exception as exc:
            warn(f"Inference polling error: {exc}")
            results["inference_status"] = "UNKNOWN"

        # SDK verification: embed inference state in summary
        step("Verifying burn scar inference via SDK...")
        embed_inference_summary("Lab 4 – Burn Scar Detection (Park Fire 2024)", client, inference_id)

    write_github_summary(
        f"\n## 🧪 Lab 4 – Burn Scars End-to-End Workflow\n\n"
        f"| Step | ID | Status |\n"
        f"|------|----|--------|\n"
        f"| Foundation Model | `{base_model_id}` | ✅ Registered |\n"
        f"| Training Dataset | `{dataset_id}` | `{results.get('dataset_status', 'N/A')}` |\n"
        f"| Task Template | `{tune_template_id}` | ✅ Created |\n"
        f"| Fine-tuning Job | `{tune_id}` | `{results.get('tune_status', 'N/A')}` |\n"
        f"| Inference | `{inference_id}` | `{results.get('inference_status', 'N/A')}` |\n\n"
        f"✅ Lab 4 completed\n"
    )

    ok("Lab 4 complete!")
    return results


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run all 4 Geospatial Studio workshop labs using the geostudio SDK"
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("STUDIO_API_KEY", ""),
        help="Studio API key (or set STUDIO_API_KEY env var)",
    )
    parser.add_argument(
        "--studio-url",
        default=os.environ.get("BASE_STUDIO_UI_URL", "https://localhost:4180"),
        help="Studio UI base URL",
    )
    parser.add_argument(
        "--notebooks-dir",
        default=os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "payloads",
        ),
        help="Path to the directory containing JSON config files for labs "
             "(defaults to populate-studio/payloads/ within this repo)",
    )
    parser.add_argument(
        "--skip-lab4-training",
        action="store_true",
        default=False,
        help="Skip the fine-tuning step in Lab 4 (useful when no GPU is available)",
    )
    parser.add_argument(
        "--skip-lab4-dataset",
        action="store_true",
        default=False,
        help="Skip the dataset onboarding step in Lab 4 (also skips fine-tuning; "
             "useful when S3 access or bandwidth is limited)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    # Validate required args
    if not args.api_key:
        fail("No API key provided. Use --api-key or set STUDIO_API_KEY env var.")
        return 1

    if not args.studio_url:
        fail("No Studio URL provided. Use --studio-url or set BASE_STUDIO_UI_URL env var.")
        return 1

    # Resolve notebooks dir
    notebooks_dir = str(Path(args.notebooks_dir).resolve())

    banner("Geospatial Studio – Workshop Labs Runner")
    step(f"Studio URL  : {args.studio_url}")
    step(f"Notebooks   : {notebooks_dir}")
    step(f"Skip Lab4 Training: {args.skip_lab4_training}")
    step(f"Skip Lab4 Dataset:  {args.skip_lab4_dataset}")

    # Write summary header
    write_github_summary(
        "# 🌍 Geospatial Studio – Workshop Labs Results\n\n"
        f"**Studio URL**: `{args.studio_url}`  \n"
        f"**Run Date**: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}  \n\n"
        "---\n"
    )

    # Build SDK client
    step("Initializing geostudio SDK client...")
    try:

        client = build_client(api_key=args.api_key, studio_url=args.studio_url)
        ok("SDK client initialized")
    except Exception as exc:
        fail(f"Failed to initialize SDK client: {exc}")
        return 1

    # -------------------------------------------------------------------------
    # Run labs
    # -------------------------------------------------------------------------
    overall_success = True

    # Lab 1 – Getting Started
    try:
        run_lab1(
            client=client,
            studio_url=args.studio_url,
        )
    except Exception as exc:
        fail(f"Lab 1 encountered an unexpected error: {exc}")
        overall_success = False

    # Lab 2 – Onboarding Pre-computed Examples
    try:
        lab2_result = run_lab2(
            client=client,
            studio_url=args.studio_url,
        )
        if lab2_result.get("status") == "FAILED":
            overall_success = False
    except Exception as exc:
        fail(f"Lab 2 encountered an unexpected error: {exc}")
        overall_success = False

    # Lab 3 – Upload Model Checkpoints & Run Inference
    try:
        lab3_result = run_lab3(
            client=client,
            studio_url=args.studio_url,
            notebooks_dir=notebooks_dir,
        )
        if lab3_result.get("tune_id") is None or lab3_result.get("inference_id") is None:
            warn("Lab 3 completed with partial results")
    except Exception as exc:
        fail(f"Lab 3 encountered an unexpected error: {exc}")
        overall_success = False

    # Lab 4 – Burn Scars End-to-End Workflow
    try:
        run_lab4(
            client=client,
            studio_url=args.studio_url,
            notebooks_dir=notebooks_dir,
            skip_training=args.skip_lab4_training,
            skip_dataset=args.skip_lab4_dataset,
        )
    except Exception as exc:
        fail(f"Lab 4 encountered an unexpected error: {exc}")
        overall_success = False

    # -------------------------------------------------------------------------
    # Final summary
    # -------------------------------------------------------------------------
    banner("All Labs Complete")
    if overall_success:
        ok("All labs finished successfully!")
        write_github_summary("\n---\n\n✅ **All 4 labs completed successfully.**\n")
    else:
        warn("One or more labs encountered errors – check output above.")
        write_github_summary("\n---\n\n⚠️ **Some labs encountered errors. Review the log above.**\n")

    return 0 if overall_success else 1


if __name__ == "__main__":
    sys.exit(main())
