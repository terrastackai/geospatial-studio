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
  <td>geospatial-studio-pipelines</td>
  <td>
    <a href="https://github.com/terrastackai/geospatial-studio-pipelines">https://github.com/terrastackai/geospatial-studio-pipelines</a>
  </td>
  <td>
    <ul>
     <li> Inference pipeline components
     <li> Pipeline orchestration wrapper
     <li> Instructions and templates for creating new templates
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

## 💻🏢 Getting Started (cluster deployment)

*If you want detailed description 📚 of the deployment process on an external cluster [see here 📚](./deployment-docs/detailed_deployment_cluster.md).*

The Geospatial Studio is primarily developed to be deployed on a Red Hat OpenShift or Kubernetes cluster, with access to NVIDIA GPU resources (for tuning and inference).  This repository containers the Helm chart and scripts for full scale deployment.

To deploy in cluster:

#### Prerequisites:
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above) 
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor
* [s3 storage class](https://cloud.ibm.com/docs/openshift?topic=openshift-storage_cos_install) - e.g. ibm-object-s3fs or equivalent to install s3 storage in the cluster
* [s3 compatible storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-provision) - e.g. IBM Cloud COS to set up cloud object storage

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
3. Deploy the geospatial studio:
```shell
./deploy_studio_cluster.sh
```

*Deployment is interactive and can take ~10 minutes (or longer) depending available download speed for container images.*

*You can follow the deployment from openshift console or [`k9s`](https://k9scli.io)*

After deployment the UI will pop up on the screen and you can jump to [First steps](#first-steps).


---

## 💻⚙️ Getting Started (local deployment)

*If you want detailed description 📚 of the local deployment process [see here 📚](./deployment-docs/detailed_deployment_local.md).*

Whilst not providing full performance and functionality, the studio can be deployed locally for testing and development purposes.  The instructions below will deploy the main components of the Geospatial Studio in a Kubernetes cluster on the local machine (i.e. your laptop).  This is provisioned through a Lima VM.  

Data for the deployment will be persisted in a local folder `~/studio-data`, you can change the location for this folder by editing the lima deployment configuration, `deployment-scripts/lima/studio.yaml`.  

The automated shell script will deploy the local dependencies (Minio, Keycloak and Postgresql), before generating the deployment configuration for the studio and then deploying the main studio services + pipelines.

To deploy locally:

#### Prerequisites:
* [Lima VM](https://lima-vm.io/docs/installation/) - v1.2.1 (*currently incompatible with v2*)
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above) 
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor


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
5. Deploy the geospatial studio:
```shell
./deploy_studio_local.sh
```

*Deployment can take ~10 minutes (or longer) depending available download speed for container images.*

You can monitor the progress and debug using [`k9s`](https://k9scli.io) or similar tools.
```shell
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
k9s
```
After successful deployment you can jump to [First steps](#first-steps).

---

## 💻⚙️ Getting Started (kind cluster deployment)

Whilst not providing full performance and functionality, the studio can be deployed for testing and development purposes.  The instructions below will deploy the main components of the Geospatial Studio in a Kubernetes cluster on a local or remote machine.  This is provisioned through a [Kind Cluster](https://kind.sigs.k8s.io/).

The automated shell script will deploy dependencies (Minio, Keycloak and Postgresql), before generating the deployment configuration for the studio and then deploying the main studio services + pipelines.

To deploy:

#### Prerequisites:
* [kind](https://kind.sigs.k8s.io/) - tool for running local Kubernetes clusters using Docker container nodes.
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above)
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor


#### Deployment steps
1. Create a kind cluster using the command
    ```shell
    cat << EOF | kind create cluster --name=studio --config=-
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
    - role: worker
    EOF
    ```

2. Set up the kubectl context:
    ```shell
    kubectl cluster-info --context kind-studio
    ```

3. Install Python dependencies:
   ```shell
   pip install -r requirements.txt
   ```

4. Deploy the geospatial studio:
   ```shell
   ./deploy_studio_nvkind.sh
   ```

*Deployment can take ~10 minutes (or longer) depending available download speed for container images.*

You can monitor the progress and debug using [`k9s`](https://k9scli.io) or similar tools.
```shell
k9s
```
After successful deployment you can jump to [First steps](#first-steps).

---

## 💻⚙️ Getting Started (nvkind cluster deployment)

This section targets cases where you have a host machine (local or remote) that has access to NVIDIA GPUs and leverage [`nvkind`](https://github.com/NVIDIA/nvkind/blob/f1a690fa3f4b0dcb41eb8d6acdda05accf045187/README.md) to create and manage `kind` kubernetes clusters with access to GPUs.

The automated shell script will deploy dependencies (Minio, Keycloak and Postgresql), before generating the deployment configuration for the studio and then deploying the main studio services + pipelines.

To deploy:

#### Prerequisites:
* [nvkind](https://github.com/NVIDIA/nvkind/blob/f1a690fa3f4b0dcb41eb8d6acdda05accf045187/README.md) - tool to create and manage kind clusters with access to GPUs
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above)
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor


#### Deployment steps
1. Navigate to [`nvkind`](https://github.com/NVIDIA/nvkind/blob/f1a690fa3f4b0dcb41eb8d6acdda05accf045187/README.md) GitHub repository documentation
    - Install all the [listed prerequisites](https://github.com/NVIDIA/nvkind/blob/f1a690fa3f4b0dcb41eb8d6acdda05accf045187/README.md#prerequisites) based on your host machine operating system, and ensure the test commands below produce similar documented output.
        ```shell
        $ nvidia-smi -L
        GPU 0: NVIDIA L4 (UUID: GPU-3e71c48d-90c0-f46f-195b-4150320f9910)
        ```

        ```shell
        $ docker run --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all ubuntu:20.04 nvidia-smi -L
        GPU 0: NVIDIA L4 (UUID: GPU-3e71c48d-90c0-f46f-195b-4150320f9910)
        ```

    - Run the [setup](https://github.com/NVIDIA/nvkind/blob/f1a690fa3f4b0dcb41eb8d6acdda05accf045187/README.md#setup) commands documented, and ensure the test commands below produce similar documented output.
       ```shell
       $ docker run -v /dev/null:/var/run/nvidia-container-devices/all ubuntu:20.04 nvidia-smi -L
       GPU 0: NVIDIA L4 (UUID: GPU-3e71c48d-90c0-f46f-195b-4150320f9910)
       ```

    - [Install nvkind](https://github.com/NVIDIA/nvkind/blob/f1a690fa3f4b0dcb41eb8d6acdda05accf045187/README.md#install-nvkind) using the commands below.
       ```shell
       go install github.com/NVIDIA/nvkind/cmd/nvkind@latest
       ```

    - [Build](https://github.com/NVIDIA/nvkind/blob/f1a690fa3f4b0dcb41eb8d6acdda05accf045187/README.md#quickstart) nvkind with the command below
        ```shell
        make
        ```

    - Create a `nvkind` cluster using the command below
        ```shell
        cat << EOF | nvkind cluster create --name=studio --config-template= -
        kind: Cluster
        apiVersion: kind.x-k8s.io/v1alpha4
        nodes:
        - role: control-plane
        - role: worker
          extraMounts:
            - hostPath: /dev/null
              containerPath: /var/run/nvidia-container-devices/all
        EOF
        ```

    - Set up the kubectl context:
        ```shell
        kubectl cluster-info --context kind-studio
        ```

    - Install NVIDIA gpu--operator in the cluster:
        ```shell
        helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update && helm install --wait --generate-name -n gpu-operator --create-namespace nvidia/gpu-operator --version=v25.10.0
        ```

2. Install Python dependencies:
  ```shell
  pip install -r requirements.txt
  ```

3. Deploy the geospatial studio:
```shell
./deploy_studio_nvkind.sh
```

*Deployment can take ~10 minutes (or longer) depending available download speed for container images.*

You can monitor the progress and debug using [`k9s`](https://k9scli.io) or similar tools.
```shell
k9s
```
After successful deployment you can jump to [First steps](#first-steps).

| After deployment: | |
|---|---|
| Access the Studio UI | [https://localhost:4180](https://localhost:4180) |
| Access the Studio API | [https://localhost:4181](https://localhost:4181) |
| Authenticate Studio | username: `testuser` password: `testpass123` |
| Access Geoserver | [https://localhost:3000](https://localhost:3000) |
| Access Keycloak | [https://localhost:8080](https://localhost:8080) |
| Access Minio | Console: [https://localhost:9001](https://localhost:9001)      API: [https://localhost:9000](https://localhost:9000) |
| Authenticate Minio | username: `minioadmin` password: `minioadmin` |

If you need to restart any of the port-forwards you can use the following commands:
```shell
kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/minio 9001:9001 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/minio 9000:9000 >> studio-pf.log 2>&1 &
```

## First steps
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

**Onboard an existing inference output (useful for loading examples)**
1. Onboard one of the `inferences`.  This will start a pipeline to pull the data and set it up in the platform.  You should now be able to browser to the inferences page in the UI and view the example/s you have added.
```shell
python docs/geospatial-studio-docs/docs/populate-studio/populate-studio.py inferences
# select "AGB Data - Karen, Nairobi,kenya"
```

**Onboard an existing tuned models and run inference**
1. We will onboard a tuned model from a URL.  This is initiated by an API call, which will trigger the onboarding process, starting download in the backend.  Once the download is completed, it should appear with completed status in the UI models/tunes page.
First we ensure we have a tuning task `templates`.

Onboard the tuning task `templates`.  These are the outline configurations to make basic tuning tasks easier for users.

```shell
python docs/geospatial-studio-docs/docs/populate-studio/populate-studio.py templates
# select  1. Segmentation - Generic template v1 and v2 models: Segmentation
```

```shell
python docs/geospatial-studio-docs/docs/populate-studio/populate-studio.py tunes
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

3. You can follow the progress of the inference run in the UI in the inference page.  The files will be created in a new folder inside `~/studio-data/studio-inference-pvc/`.

**Tuning a model from a dataset**

*Note: Currently, for local deployments with access to non-NVIDIA GPUs (i.e. Mac), you will need to run the fine-tuning outside of the local cluster, and the resulting model can be onboarded back to the local cluster for inference.  This will be addressed in future, and is not an issue for cluster deployments with accessible GPUs.*

1. First onboard a tuning dataset. This can be done through the UI or the API, for now select and onboard a dataset using the below command.  This will trigger a backend task to download, validate and sort the dataset ready for use.  The dataset will appear in the UI datasets page, initally as pending, but will complete and change status after a few minutes.
```shell
python docs/geospatial-studio-docs/docs/populate-studio/populate-studio.py datasets
# select "Wildfire burn scars"
```

2. Onboard the backbone model/s from which we will fine-tune.
```shell
python docs/geospatial-studio-docs/docs/populate-studio/populate-studio.py backbones
```

3. Onboard the tuning task `templates`.  These are the outline configurations to make basic tuning tasks easier for users.
```shell
python docs/geospatial-studio-docs/docs/populate-studio/populate-studio.py templates
```

4. Now we can prepare the tuning task.  In a cluster deployed studio instance a user will prepare and submit their tuning task in one step, however, for local deployments, due to GPU accessibility within VMs (especially on Mac), we will use the studio to create the tuning config file and then run it outside the studio with TerraTorch.
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




<!-- ---

##  Documentation
Detailed deployment documentation

---

## 🛠 Deployment Details
This is a repository containing Helm Parent and Subcharts for Geospatial Studio Platform. The files in this directory are used to deploy geospatial studio infrastructure for inference and tuning on a Red Hat Openshift Container Platform.

Helm is used to install the services.

### Helm charts

We expose two charts for deploying the studio core services and applications and another chart for deploying studio pipelines

- geospatial-studio parent chart
    - gfm-studio-gateway subchart
    - geofm-ui subchart
    - gfm-mlflow subchart
    - gfm-geoserver subchart
- geospatial-studio-pipelines chart -->



