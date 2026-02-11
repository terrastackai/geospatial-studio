![Geospatial Studio banner](./docs/images/banner.png)

# 🌍 Geospatial Exploration and Orchestration Studio

<table>
<tr>
  <td><strong>License</strong></td>
  <td>
    <img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" />
  </td>
</tr>
<tr>
  <td><strong>TerraStackAI</strong></td>
  <td>
    <img src="https://img.shields.io/badge/TerraTorch-a3b18a" />
    <img src="https://img.shields.io/badge/TerraKit-588157" />
    <img src="https://img.shields.io/badge/Iterate-3a5a40" />
  </td>
</tr>
<tr>
  <td><strong>Built With</strong></td>
  <td>
    <img src="https://img.shields.io/badge/Python-3.11-blue.svg?logo=python&logoColor=white" />
    <img src="https://img.shields.io/badge/code%20style-black-000000.svg" />
    <img src=https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white />

  </td>
</tr>
<tr>
  <td><strong>Deployment</strong></td>
  <td>
    <img src="https://img.shields.io/badge/Helm-0F1689?style=flat&logo=helm" />
    <img src="https://img.shields.io/badge/-Red_Hat_OpenShift-EE0000?logo=redhatopenshift&logoColor=white" />
    <img src="https://img.shields.io/badge/kubernetes-326CE5?&logo=kubernetes&logoColor=white" />
    <img src="https://img.shields.io/badge/Auth-OAuth_2.0-purple" />
    <img src="https://img.shields.io/badge/PostgreSQL-316192?logo=postgresql&logoColor=white" />
    <img src="https://img.shields.io/badge/Keycloak-111921?logo=keycloak&logoColor=white" />
    <img src="https://img.shields.io/badge/-MinIO-C72E49?logo=minio&logoColor=white" />
  </td>
</tr>
</table>

[![Studio Documentation](https://img.shields.io/badge/Studio_Documentation-526CFE?style=for-the-badge&logo=MaterialForMkDocs&logoColor=white)](https://terrastackai.github.io/geospatial-studio)

---

## 🚀 Overview

The **Geospatial Exploration and Orchestration Studio** is an integrated platform for **fine-tuning, inference, and orchestration of geospatial AI models**.  It combines a **no-code UI**, **low-code SDK**, and APIs to make working with geospatial data and AI accessible to everyone, from researchers to developers.  

The platform supports **on-prem or cloud deployment** using **Red Hat OpenShift** or **Kubernetes**, enabling scalable pipelines for data preparation, model training, and inference.

By leveraging tools like **TerraTorch**, **TerraKit**, and **Iterate**, the Geospatial Studio accelerates insights from complex geospatial datasets for a diverse range of applications. 🌱

The studio is builds upon the broader ecosystem utilising [TerraTorch](https://github.com/terrastackai/terratorch) for model fine-tuning and inference, and leveraging [TerraKit](https://github.com/terrastackai/terrakit) for geospatial data search, query and processing.

![Geospatial Studio UI Screenshots](./docs/images/ui-screenshots.png)

---

## 🏗 Architecture

The Geospatial Studio is made up of a gateway API which provides access to all the backend services (fine-tuning, dataset onboarding/preparation, model management, inference pipelines).  The code for the most of these core elements are found in the following repositories: 

<table>
<tr>
  <td>geospatial-studio (this repo)</td>
  <td>
    <a href="https://github.com/terrastackai/geospatial-studio">https://github.com/terrastackai/geospatial-studio</a>
  </td>
  <td>
    <ul>
     <li> Helm chart for core deployment
     <li> Helm chart for pipelines deployment
     <li> Deployment instructions and scripts
    </ul>
  </td>
</tr>
<tr>
  <td>geospatial-studio-core</td>
  <td>
    <a href="https://github.com/terrastackai/geospatial-studio-core">https://github.com/terrastackai/geospatial-studio-core</a>
  </td>
  <td>
    <ul>
     <li> Studio Gateway API
     <li> Tuning image build scripts
     <li> Inference image build scripts
     <li> Automated model deployment scripts
    </ul>  
  </td>
</tr>
<tr>
  <td>geospatial-studio-ui</td>
  <td>
    <a href="https://github.com/terrastackai/geospatial-studio-ui">https://github.com/terrastackai/geospatial-studio-ui</a>
  </td>
  <td>
    <ul>
     <li> Geospatial Studio web-based UI
    </ul>
  </td>
</tr>
<tr>
  <td>geospatial-studio-toolkit</td>
  <td>
    <a href="https://github.com/terrastackai/geospatial-studio-toolkit">https://github.com/terrastackai/geospatial-studio-toolkit</a>
  </td>
  <td>
    <ul>
     <li> Python SDK
     <li> Jupyter notebook examples
     <li> QGIS plugin
    </ul>
  </td>
</tr>
</table>

When deployed the studio will consist of the gateway api (which can trigger onboarding, fine-tuning and inference tasks), UI, deployed inference pipeline components, backend Postgresql database, MLflow and Geoserver.  These are supported by an OAuth2 authenticator and S3-compatible object storage (both usually external).  The architecture is shown in the diagram below.

![Geospatial Studio banner](./docs/images/architecture.png)

---

## 💻🏢 Getting Started (OCP Cluster Deployment)

#### Prerequisites:
* Provisioned ocp cluster
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above) 
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor
* [Optional] [s3 compatible cloud object storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-provision) - e.g. IBM Cloud COS to set up cloud object storage

*If you want detailed description 📚 of the deployment process on an external cluster [see here 📚](./docs/geospatial-studio-docs/docs/detailed_deployment_cluster.md).*

The Geospatial Studio is primarily developed to be deployed on a Red Hat OpenShift, with access to NVIDIA GPU resources (for tuning and inference).

The automated shell script will deploy dependencies (Minio, Keycloak and Postgresql), before generating the deployment configuration for the studio and then deploying the main studio services + pipelines.

To deploy in an openshift cluster:

#### Deployment steps
1. Install Python dependencies:
```shell
pip install -r requirements.txt
```
2. Set up the kubectl context or login to OpenShift:
For OpenShift use the script below to login after supplying the token and server. These can be obtained from the OpenShift console.
```shell
oc login --token=<cluster-token> --server=<cluster-server>
```
3. [Optional] If you have limited network bandwidth, you can pre-pull the container images using the script below, [see details here](./deployment-scripts/images-pre-puller/README-image-prepuller.md):
```shell
NAMESPACE=<my-namespace> ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh
```

4. Deploy the geospatial studio:
```shell
./deploy_studio_ocp.sh
```

*Deployment is interactive and can take ~10 minutes (or longer) depending available download speed for container images.*

*You can follow the deployment from openshift console or [`k9s`](https://k9scli.io)*

After deployment the UI will pop up on the screen and you can jump to [First steps](#first-steps).


---

## 💻⚙️ Getting Started (Local Deployment)

#### Prerequisites:
* [Lima VM](https://lima-vm.io/docs/installation/) - v1.2.1 (*currently incompatible with v2*)
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above)
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor

*If you want detailed description 📚 of the local deployment process [see here 📚](./docs/geospatial-studio-docs/docs/detailed_deployment_local.md).*

Whilst not providing full performance and functionality, the studio can be deployed locally for testing and development purposes.  The instructions below will deploy the main components of the Geospatial Studio in a Kubernetes cluster on the local machine (i.e. your laptop).  This is provisioned through a Lima VM.  

Data for the deployment will be persisted in a local folder `~/studio-data`, you can change the location for this folder by editing the lima deployment configuration, `deployment-scripts/lima/studio.yaml`.  

The automated shell script will deploy the local dependencies (Minio, Keycloak and Postgresql), before generating the deployment configuration for the studio and then deploying the main studio services + pipelines.

To deploy locally:

#### Deployment steps
1. Install [Lima VM](https://github.com/lima-vm/lima).
2. Install Python dependencies:
  ```shell
  pip install -r requirements.txt
  ```
3. Start the Lima VM cluster:

  For macOS >= 13.0, ARM use command below. For macOS >= 13.0, AMD consider using [VZ](https://lima-vm.io/docs/config/vmtype/vz/) without Rosetta, or use the QEMU as configured in `deployment-scripts/lima/studio-linux.yaml`
  ```shell
  limactl start --name=studio deployment-scripts/lima/studio.yaml
  ```

  For Linux use command below. It leverages [QEMU](https://lima-vm.io/docs/config/vmtype/qemu/) and QEMU install will be required.
  ```shell
  limactl start --name=studio deployment-scripts/lima/studio-linux.yaml
  ```
4. Set up the kubectl context:
```shell
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
```
5. [Optional] If you have limited network bandwidth, you can pre-pull the container images using the script below, [see details here](./deployment-scripts/images-pre-puller/README-image-prepuller.md):
```shell
NAMESPACE=default ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh
```
6. Deploy the geospatial studio:
```shell
./deploy_studio_lima.sh
```

*Deployment can take ~10 minutes (or longer) depending available download speed for container images.*

You can monitor the progress and debug using [`k9s`](https://k9scli.io) or similar tools.
```shell
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
k9s
```
After successful deployment you can jump to [First steps](#first-steps).

---

## 💻⚙️ Getting Started (K8s Cluster Deployment)

#### Prerequisites:
* Provisioned k8s cluster - kind cluster, nvkind cluster, minikube, or any other k8s cluster.
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above) 
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor
* [Optional] [s3 compatible cloud object storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-provision) - e.g. IBM Cloud COS to set up cloud object storage

*If you want detailed description 📚 of the deployment process on an external cluster [see here 📚](./docs/geospatial-studio-docs/docs/detailed_deployment_k8s.md).*

*For Kind cluster deployments without GPUs, follow specific instructions [see here 📚](./docs/geospatial-studio-docs/docs/kind_cluster_deployment.md).*

*For Kind cluster deployments with GPUs i.e NVKind cluster, follow specific instructions [see here 📚](./docs/geospatial-studio-docs/docs/nvkind_cluster_deployment.md).*

The Geospatial Studio is developed to be deployed on Kubernetes cluster as well, with access to NVIDIA GPU resources (for tuning and inference). The deployment process is similar to the OpenShift deployment process, but with some differences.

The automated shell script will deploy dependencies (Minio, Keycloak and Postgresql), before generating the deployment configuration for the studio and then deploying the main studio services + pipelines.

To deploy in a k8s cluster:

#### Deployment steps
1. Install Python dependencies:
```shell
pip install -r requirements.txt
```
2. Set up the kubectl context for your cluster
3. [Optional] If you have limited network bandwidth, you can pre-pull the container images using the script below, [see details here](./deployment-scripts/images-pre-puller/README-image-prepuller.md):
```shell
NAMESPACE=<my-namespace> ./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh
```

4. Deploy the geospatial studio:
```shell
./deploy_studio_k8s.sh
```

*Deployment is interactive and can take ~10 minutes (or longer) depending available download speed for container images.*

*You can follow the deployment on [`k9s`](https://k9scli.io)*

After deployment the UI will pop up on the screen and you can jump to [First steps](#first-steps).


## First steps

| After deployment: | |
|---|---|
| Access the Studio UI | [https://localhost:4180](https://localhost:4180) |
| Access the Studio API | [https://localhost:4181](https://localhost:4181) |
| Authenticate Studio | username: `testuser` password: `testpass123` |
| Access Geoserver | [http://localhost:3000/geoserver](http://localhost:3000/geoserver) |
| Authenticate Geoserver | username: `admin` password: `geoserver` |
| Access MLflow | [http://localhost:5000](http://localhost:5000) |
| Access Keycloak | [http://localhost:8080](http://localhost:8080) |
| Authenticate Keycloak  | username: `admin` password: `admin` |
| Access Minio | Console: [https://localhost:9001](https://localhost:9001)      API: [https://localhost:9000](https://localhost:9000) |
| Authenticate Minio | username: `minioadmin` password: `minioadmin` |

If you need to restart any of the port-forwards you can use the following commands:
```shell
kubectl port-forward -n $OC_PROJECT svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/minio 9001:9001 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/minio 9000:9000 >> studio-pf.log 2>&1 &
```

Now you have a clean deployment of the studio and it is time to start using it.  The steps below will enable you to onboard some initial artefacts, before trying out the functionality.

1. Navigate to the UI front page and create an api key.  Click on the `Manage your API keys` link. This should pop-up a window where you can generate, access and delete your api keys.

![Location of API key link](docs/images/sdk-auth.png)

2. Copy your new api key to an env in your terminal:
```shell
export STUDIO_API_KEY="<your api key from the UI>"
```

3. Copy the UI url to an env in your terminal:
```shell
export UI_ROUTE_URL="https://localhost:4180"
```

4. Onboard the `sandbox-model`s, these are placeholder models (pipelines) for onboarding existing inferences or testing tuned models.
```shell
./deployment-scripts/add-sandbox-models.sh
```

At this point you can opt to continue getting started with the studio with the steps below by running them in terminal, or you can opt to use [this jupyter notebook](./populate-studio/getting-started-notebook.ipynb), leveraging studio sdk to get started.  

> The notebook is a good way to get started with the studio sdk and see how it works.  The notebook is located in the `./populate-studio/getting-started-notebook.ipynb` directory of this repo.

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

2. After tune above completes, we can trigger an inference run.  This can be run through the UI, SDK or API (as here), where you tell which spatial and temporal domain over which to run inference.  You need to get the `tune_id` for the above tune (from the tune submission response or from the models/tunes page in the UI) and paste it into the command below. Here we show an expanded payload for submitting the inference to demonstrate how you can override the different configurations for your specific usecase.

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
    ```shell
    Add api call to upload tune
    ```

7. Now we can use it for inference.
    ```shell
    Add api call to run try out inference
    ```
