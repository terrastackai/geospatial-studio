
# First Steps After Deployment

## Overview

Congratulations! 🎉 Your Geospatial Studio is now running locally. This guide will help you access and explore the various components of the platform.

The studio deployment includes several services that work together to provide geospatial processing capabilities. Each service has its own web interface and purpose.

---

## Accessing the Services

### Core Studio Components

| Service | URL | Purpose |
|---------|-----|---------|
| **Studio UI** | [https://localhost:4180](https://localhost:4180) | Main web interface for the Geospatial Studio |
| **Studio API** | [https://localhost:4181](https://localhost:4181) | REST API for programmatic access |
| **GeoServer** | [https://localhost:3000/geoserver](https://localhost:3000/geoserver) | Geospatial data server and map rendering |
| **MLflow** | [https://localhost:5000](https://localhost:5000) | Machine learning experiment tracking |

### Infrastructure Services

| Service | URL | Purpose |
|---------|-----|---------|
| **Keycloak** | [https://localhost:8080](https://localhost:8080) | Authentication and user management |
| **MinIO Console** | [https://localhost:9001](https://localhost:9001) | Object storage web interface |
| **MinIO API** | [https://localhost:9000](https://localhost:9000) | Object storage API endpoint |

---

## Default Credentials

!!! warning "Security Notice"
    These are **default credentials for local development only**. Never use these credentials in production environments.

### Studio Authentication

Access the Studio UI at [https://localhost:4180](https://localhost:4180)
```
Username: testuser
Password: testpass123
```

### GeoServer Authentication

Access GeoServer at [https://localhost:3000/geoserver](https://localhost:3000/geoserver)
```
Username: admin
Password: geoserver
```

### MinIO Authentication

Access MinIO Console at [https://localhost:9001](https://localhost:9001)
```
Username: minioadmin
Password: minioadmin
```

---

## Initial Setup - API Key Configuration

Before you can use the Studio API or SDK, you need to generate an API key. This key authenticates your requests to the Studio backend.

### Step 1: Log In to the Studio UI

1. Navigate to [https://localhost:4180](https://localhost:4180)
2. Log in with default credentials:
   - Username: `testuser`
   - Password: `testpass123`

---

### Step 2: Generate an API Key

1. On the Studio UI homepage, locate and click the **"Manage your API keys"** link
2. A popup window will appear where you can:
   - Generate new API keys
   - View existing keys
   - Delete old keys

![Location of API key link](../images/sdk-auth.png)

3. Click **"Generate New Key"** (or similar button)
4. **Copy the generated API key immediately** - you won't be able to see it again!

!!! warning "Save Your API Key"
    Store your API key securely. Once you close the popup, you won't be able to retrieve the same key again. If you lose it, you'll need to generate a new one.

---

### Step 3: Configure Your Environment

Set up environment variables for easy access to the Studio API:
```bash
# Set your API key
export STUDIO_API_KEY="<your api key from the UI>"

# Set the UI/API URL
export UI_ROUTE_URL="https://localhost:4180"
```

**Example:**
```bash
export STUDIO_API_KEY="sk_1234567890abcdef1234567890abcdef"
export UI_ROUTE_URL="https://localhost:4180"
```

!!! tip "Make It Permanent"
    To avoid setting these variables every time, add them to your shell profile:
```bash
    # For bash
    echo 'export STUDIO_API_KEY="your-key-here"' >> ~/.bashrc
    echo 'export UI_ROUTE_URL="https://localhost:4180"' >> ~/.bashrc
    source ~/.bashrc
    
    # For zsh
    echo 'export STUDIO_API_KEY="your-key-here"' >> ~/.zshrc
    echo 'export UI_ROUTE_URL="https://localhost:4180"' >> ~/.zshrc
    source ~/.zshrc
```

---

### Step 4: Verify Your Setup

Test that your API key works:
```bash
# Using curl
curl -X GET "${UI_ROUTE_URL}/api/v1/health" \
  -H "Authorization: Bearer ${STUDIO_API_KEY}" \
  -H "accept: application/json"
```

**Expected response:**
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

---

## Port Forwarding Management

### What is Port Forwarding?

Port forwarding allows you to access services running inside the Kubernetes cluster from your local machine. The deployment script automatically sets up port forwards for all services.

### Checking Active Port Forwards
```bash
# List all kubectl port-forward processes
ps aux | grep "port-forward"

# Check if ports are in use
lsof -i :4180  # Studio UI
lsof -i :4181  # Studio API
lsof -i :3000  # GeoServer
lsof -i :5000  # MLflow
lsof -i :8080  # Keycloak
lsof -i :9001  # MinIO Console
lsof -i :9000  # MinIO API
```

### Restarting Port Forwards

If you need to restart any port forwards (e.g., after disconnection), use these commands:
```bash
# Keycloak (Authentication)
kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &

# PostgreSQL Database
kubectl port-forward -n default svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &

# GeoServer (Map Server)
kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &

# Studio UI (Frontend)
kubectl port-forward -n default deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &

# Studio API Gateway
kubectl port-forward -n default deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &

# MLflow (ML Tracking)
kubectl port-forward -n default deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &

# MinIO Console
kubectl port-forward -n default svc/minio 9001:9001 >> studio-pf.log 2>&1 &

# MinIO API
kubectl port-forward -n default svc/minio 9000:9000 >> studio-pf.log 2>&1 &
```

??? info "Understanding the Port Forward Command"
```bash
    kubectl port-forward -n default svc/minio 9001:9001 >> studio-pf.log 2>&1 &
```
    
    - `kubectl port-forward` - Creates the port forward
    - `-n default` - Uses the 'default' namespace
    - `svc/minio` - Targets the MinIO service
    - `9001:9001` - Maps local port 9001 to service port 9001
    - `>> studio-pf.log` - Appends output to log file
    - `2>&1` - Redirects errors to the log file
    - `&` - Runs the command in the background

### Restart All Port Forwards

To restart all port forwards at once:
```bash
# Create a script to restart all port forwards
cat > restart-portforwards.sh << 'EOF'
#!/bin/bash

echo "Stopping existing port forwards..."
pkill -f "kubectl port-forward"

echo "Starting port forwards..."
kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/minio 9001:9001 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/minio 9000:9000 >> studio-pf.log 2>&1 &

echo "Port forwards restarted. Check studio-pf.log for details."
EOF

chmod +x restart-portforwards.sh
./restart-portforwards.sh
```

### Stop All Port Forwards

When you're done working:
```bash
# Stop all port forwards
pkill -f "kubectl port-forward"
```
---

## Next Steps - Start Using the Studio


4. Onboard the `sandbox-model`s, these are placeholder models (pipelines) for onboarding existing inferences or testing tuned models.
```shell
./deployment-scripts/add-sandbox-models.sh
```

**Onboard an existing inference output (useful for loading examples)**
1. Onboard one of the `inferences`.  This will start a pipeline to pull the data and set it up in the platform.  You should now be able to browser to the inferences page in the UI and view the example/s you have added.
   ```shell
   python populate-studio/populate-studio.py inferences
   # select "AGB Data - Karen, Nairobi,kenya"
   ```

**Onboard an existing tuned models and run inference**
1. We will onboard a tuned model from a URL.  This is initiated by an API call, which will trigger the onboarding process, starting download in the backend.  Once the download is completed, it should appear with completed status in the UI models/tunes page.
First we ensure we have a tuning task `templates`.      
Onboard the tuning task `templates`.  These are the outline configurations to make basic tuning tasks easier for users.

   ```shell
   python populate-studio/populate-studio.py templates
   # select  1. Segmentation - Generic template v1 and v2 models: Segmentation
   ```

   ```shell
   python populate-studio/populate-studio.py tunes
   # select "prithvi-eo-flood - prithvi-eo-flood"
   ```

2. Now we can trigger an inference run.  This can be run through the UI or API (as here), where you tell which spatial and temporal domain over which to run inference.  You need to get the `tune_id` for the onboarded tune (from the onboarding response or from the models/tunes page in the UI) and paste it into the command below.
    ```bash
    tune_id="<paste tune_id here>"

    payload='{
        "model_display_name": "geofm-sandbox-models",
        "location": "Dakhin Petbaha, Raha, Nagaon, Assam, India",
        "description": "Flood Assam local with sentinel aws",
        "spatial_domain": {
          "bbox": [
            [
              92.703396,26.247896,92.748087,26.267903
            ]
          ],
          "urls": [],
          "tiles": [],
          "polygons": []
        },
        "temporal_domain": [
          "2024-07-25_2024-07-28"
        ]
      }'

    echo $payload | curl -X POST "${UI_ROUTE_URL}/studio-gateway/v2/tunes/${tune_id}/try-out" \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --insecure \
      --data @-
    ```

3. You can follow the progress of the inference run in the UI in the inference page.  The files will be created and can be accessed via the [Minio ui](https://localhost:9001).

**Tuning a model from a dataset**

1. First onboard a tuning dataset. This can be done through the UI or the API, for now select and onboard a dataset using the below command.  This will trigger a backend task to download, validate and sort the dataset ready for use.  The dataset will appear in the UI datasets page, initally as pending, but will complete and change status after a few minutes.
    ```shell
    python populate-studio/populate-studio.py datasets
    # select "Wildfire burn scars"
    ```

2. Onboard the backbone model/s from which we will fine-tune.
    ```shell
    python populate-studio/populate-studio.py backbones
    # select "Prithvi_EO_V2_300M"
    ```

3. Onboard the tuning task `templates` if you have not done it.  These are the outline configurations to make basic tuning tasks easier for users.
    ```shell
    python populate-studio/populate-studio.py templates
    # select  1. Segmentation - Generic template v1 and v2 models: Segmentation
    ```

*Note: Currently, for local deployments with access to non-NVIDIA GPUs (i.e. Mac), you will need to run the fine-tuning outside of the local cluster, and the resulting model can be onboarded back to the local cluster for inference.  This will be addressed in future, and is not an issue for cluster deployments with accessible GPUs. For this case jusp to [**Tuning a model from a dataset using Mac GPUs**](#tuning-a-model-from-a-dataset-using-mac-gpus)*

#### Tuning a model from a dataset in a cluster deployments with accessible GPUs

1. Now we can trigger a fine tuning job, using the payload and script below. First replace the values of keys `dataset_id`, `base_model_id`, and `tune_template_id` with the ids generated after onboarding 1, 2, and 3 above respectively. After submission, you can monitor the training in [MLflow ui](https://localhost:5000).

??? note "Click to view fine-tuning payload"
    ```shell
    payload='{
      "name": "burn-scars-demo",
      "description": "Segmentation",
      "dataset_id": "<dataset id here>",
      "base_model_id": "<backbone model id here>",
      "tune_template_id": "<tune template id here>",
      "train_options": {
        "model_input_data_spec": [
          {
            "bands": [
              {
                "index": "0",
                "band_name": "Blue",
                "scaling_factor": "0.0001",
                "RGB_band": "B"
              },
              {
                "index": "1",
                "band_name": "Green",
                "scaling_factor": "0.0001",
                "RGB_band": "G"
              },
              {
                "index": "2",
                "band_name": "Red",
                "scaling_factor": "0.0001",
                "RGB_band": "R"
              },
              {
                "index": "3",
                "band_name": "NIR_Narrow",
                "scaling_factor": "0.0001"
              },
              {
                "index": "4",
                "band_name": "SWIR1",
                "scaling_factor": "0.0001"
              },
              {
                "index": "5",
                "band_name": "SWIR2",
                "scaling_factor": "0.0001"
              }
            ],
            "connector": "sentinelhub",
            "collection": "hls_l30",
            "file_suffix": "_merged.tif",
            "modality_tag": "HLS_L30"
          }
        ],
        "label_categories": [
          {
            "id": "-1",
            "name": "Ignore",
            "color": "#000000",
            "opacity": 0,
            "weight": null
          },
          {
            "id": "0",
            "name": "No data",
            "color": "#000000",
            "opacity": 0,
            "weight": null
          },
          {
            "id": "1",
            "name": "Fire Scar",
            "color": "#ab4f4f",
            "opacity": 1,
            "weight": null
          }
        ]
      },
      "model_parameters": {
        "data": {
          "check_stackability": "false"
        },
        "runner": {
          "max_epochs": "5"
        }
      }
    }'

    echo $payload | curl -X POST "${UI_ROUTE_URL}/studio-gateway/v2/submit-tune" \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --insecure \
      --data @-
    ```

1. After tune above completes, we can trigger an inference run.  This can be run through the UI, SDK or API (as here), where you tell which spatial and temporal domain over which to run inference.  You need to get the `tune_id` for the above tune (from the tune submission response or from the models/tunes page in the UI) and paste it into the command below. Here we show an expanded payload for submitting the inference to demonstrate how you can override the different configurations for your specific usecase.

??? note "Click to view inference payload"
    ```bash
    tune_id="<paste tune_id here>"

    payload='{
    "model_display_name": "geofm-sandbox-models",
    "location": "Red Bluff, California, United States",
    "description": "Park Fire Aug 2024",
    "spatial_domain": {
      "bbox": [],
      "urls": [
        "https://geospatial-studio-example-data.s3.us-east.cloud-object-storage.appdomain.cloud/examples-for-inference/park_fire_scaled.tif"
      ],
      "tiles": [],
      "polygons": []
    },
    "temporal_domain": [
      "2024-08-12"
    ],
    "pipeline_steps": [
      {
        "status": "READY",
        "process_id": "url-connector",
        "step_number": 0
      },
      {
        "status": "WAITING",
        "process_id": "terratorch-inference",
        "step_number": 1
      },
      {
        "status": "WAITING",
        "process_id": "postprocess-generic",
        "step_number": 2
      },
      {
        "status": "WAITING",
        "process_id": "push-to-geoserver",
        "step_number": 3
      }
    ],
    "post_processing": {
      "cloud_masking": "False",
      "ocean_masking": "False",
      "snow_ice_masking": null,
      "permanent_water_masking": "False"
    },
    "model_input_data_spec": [
      {
        "bands": [
          {
            "index": "0",
            "RGB_band": "B",
            "band_name": "Blue",
            "scaling_factor": "0.0001"
          },
          {
            "index": "1",
            "RGB_band": "G",
            "band_name": "Green",
            "scaling_factor": "0.0001"
          },
          {
            "index": "2",
            "RGB_band": "R",
            "band_name": "Red",
            "scaling_factor": "0.0001"
          },
          {
            "index": "3",
            "band_name": "NIR_Narrow",
            "scaling_factor": "0.0001"
          },
          {
            "index": "4",
            "band_name": "SWIR1",
            "scaling_factor": "0.0001"
          },
          {
            "index": "5",
            "band_name": "SWIR2",
            "scaling_factor": "0.0001"
          }
        ],
        "connector": "sentinelhub",
        "collection": "hls_l30",
        "file_suffix": "_merged.tif",
        "modality_tag": "HLS_L30"
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
            {
              "label": "RedChannel",
              "channel": 1,
              "maxValue": 255,
              "minValue": 0
            },
            {
              "label": "GreenChannel",
              "channel": 2,
              "maxValue": 255,
              "minValue": 0
            },
            {
              "label": "BlueChannel",
              "channel": 3,
              "maxValue": 255,
              "minValue": 0
            }
          ]
        },
        "visible_by_default": "True"
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
            {
              "color": "#000000",
              "label": "ignore",
              "opacity": 0,
              "quantity": "-1"
            },
            {
              "color": "#000000",
              "label": "no-data",
              "opacity": 0,
              "quantity": "0"
            },
            {
              "color": "#ab4f4f",
              "label": "fire-scar",
              "opacity": 1,
              "quantity": "1"
            }
          ]
        },
        "visible_by_default": "True"
      }
     ]
    }'

    echo $payload | curl -X POST "${UI_ROUTE_URL}/studio-gateway/v2/tunes/${tune_id}/try-out" \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --insecure \
      --data @-
    ```

3. You can follow the progress of the inference run in the UI in the inference page.  The files will be created and can be accessed via the [Minio ui](https://localhost:9001).

#### Tuning a model from a dataset using Mac GPUs

1. Now we can prepare the tuning task.  In a cluster deployed studio instance a user will prepare and submit their tuning task in one step, however, for local deployments, due to GPU accessibility within VMs (especially on Mac), we will use the studio to create the tuning config file and then run it outside the studio with TerraTorch.
    ```shell
    #Need to create a script to call the dry-run api, get the config to file and update paths.
    payload='{
      "name": "burn-scars-demo",
      "description": "Segmentation",
      "dataset_id": "<dataset id here>",
      "base_model_id": "<backbone model id here>",
      "tune_template_id": "<tune template id here>",
      "model_parameters": {
        "runner": {
          "max_epochs": "10"
        },
        "optimizer": {
          "lr": 6e-05,
          "type": "AdamW"
        }
      }
    }'

    echo $payload | curl -X POST "${UI_ROUTE_URL}/studio-gateway/v2/submit-tune/dry-run" \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --insecure \
      --data @- >> config.yaml

    ./deployment-scripts/localize_config.sh config.yaml
    ```

5. Run the tuning task:
    ```shell
    terratorch fit -c config.yaml
    ```

6. Upload the tune back to the studio.  In this case we do it from the local config and checkpoint files.  Once its complete, you should see the it in the UI under the tunes/models page.

**Get the notebook:**
[View Notebook](https://github.com/terrastackai/geospatial-studio/blob/docs/test-local-installation-notebook/populate-studio/getting-started-notebook.ipynb){ .md-button .md-button--primary }

