# Geostudio airgapped

# Part 1 — Deployment-Time Dependencies [Coming soon]
  1. Container Images — Every image pulled at deploy time from external registries, both geostudio quay images and other dependencies
  2. Helm Chart Repositories - external Helm repos fetched during deployment, e.g redis chart
  3. Geoserver deployment, some configurations are downloaded from the internet

<br></br>

# Part 2 — Runtime External Calls

## Navigation - Base map layers
1. Inference page

    1.1 UI Basemap Tiles — OpenStreetMap / Mapbox - Base layers from OpenStreetMaps are downloaded from internet
    
    1.2 Geocoding - search feature, inference coordinates search

2. Dataset preview page

Step 1: Download the Natural Earth GeoTIFF (internet-connected machine)
```sh
curl -L -o NE2_HR_LC_SR_W.zip \
  "https://naciscdn.org/naturalearth/10m/raster/NE2_HR_LC_SR_W.zip"

unzip NE2_HR_LC_SR_W.zip
```

Step 2: Identify the GeoServer pod and set variables
```sh
export OC_PROJECT=default
export GS_USER=admin
export GS_PASS=geoserver

GS_POD=$(kubectl get pod -n $OC_PROJECT \
  -l app.kubernetes.io/name=gfm-geoserver \
  -o jsonpath='{.items[0].metadata.name}')

echo "GeoServer pod: $GS_POD"
```

Step 3:  Create a data directory on the PVC and copy the GeoTIFF in
```sh
# Create the folder inside GeoServer's persistent data directory
kubectl exec -n $OC_PROJECT $GS_POD -- \
  mkdir -p /opt/geoserver_data/data/basemap

# Copy the file — this lands on the PVC, survives pod restarts
kubectl cp NE2_HR_LC_SR_W.tif \
  $OC_PROJECT/$GS_POD:/opt/geoserver_data/data/basemap/NE2_HR_LC_SR_W.tif
```

Step 4: Create the basemap workspace
```sh
curl -s -u $GS_USER:$GS_PASS -X POST \
  http://localhost:3000/geoserver/rest/workspaces \
  -H "Content-Type: application/json" \
  -d '{"workspace": {"name": "basemap"}}'
```

Step 5: Create the coverage store pointing at the GeoTIFF
```sh
curl -s -u $GS_USER:$GS_PASS -X POST \
  "http://localhost:3000/geoserver/rest/workspaces/basemap/coveragestores" \
  -H "Content-Type: application/json" \
  -d '{
    "coverageStore": {
      "name": "world",
      "workspace": "basemap",
      "type": "GeoTIFF",
      "enabled": true,
      "url": "file:data/basemap/NE2_HR_LC_SR_W.tif"
    }
  }'
```

Step 6: Publish the coverage as the basemap:world layer
```sh
curl -s -u $GS_USER:$GS_PASS -X POST \
  "http://localhost:3000/geoserver/rest/workspaces/basemap/coveragestores/world/coverages" \
  -H "Content-Type: application/json" \
  -d '{
    "coverage": {
      "name": "world",
      "title": "Natural Earth Basemap",
      "nativeName": "NE2_HR_LC_SR_W",
      "srs": "EPSG:4326",
      "enabled": true
    }
  }'
```

Step 7: Verify the layer serves a map image
```sh
curl -s -u $GS_USER:$GS_PASS \
  "http://localhost:3000/geoserver/basemap/wms?\
SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap\
&LAYERS=basemap:world&BBOX=-180,-90,180,90\
&WIDTH=512&HEIGHT=256&SRS=EPSG:4326&FORMAT=image/png" \
  -o /tmp/basemap-test.png

open /tmp/basemap-test.png
```

Step 8: Patch the UI source
Refer to: [https://github.com/terrastackai/geospatial-studio-core/pull/65](https://github.com/terrastackai/geospatial-studio-core/pull/65)

<br></br>

## Fine-tuning and Inference
### Run-time container images

**Step 1:** List of images required:

The Studio gateway deployment needs the following container images at runtime. You need to make these available to your local image registry before deployment if they're not already present:

- Dataset onboarding job: `quay.io/geospatial-studio/geostudio-pipelines:latest`
- Fine-tuning job: `quay.io/geospatial-studio/terratorch:latest`
- HPO tuning job: `quay.io/geospatial-studio/gfmstudio-hpo:latest`
- Init container image: `docker.io/library/busybox:latest`
- Clean-up cron jobs: `docker.io/bitnamilegacy/kubectl:latest`

**Step 2:** Update deployment values with references to your images

In your workspace `values-deploy.yaml` file (When prompted using the automated deployment scripts), update references to these runtime images to reference the images in your registry in the following sections:
```yaml
gfm-studio-gateway.images.dataset_pipeline
gfm-studio-gateway.images.ftuning_runtime
gfm-studio-gateway.images.tt_hpoTune
gfm-studio-gateway.images.ftuning_init_container
gfm-studio-gateway.images.cleanup_cronjob
```

<br></br>

### Fine-tuning: base models are downloaded from hugging face

Step 1: Edit deployment values:

When running the automates deployment scripts `deploy_studio_k8s.sh` or `deploy_studio_lima.sh`, select `true` when prompted `Enable offline / air-gapped mode (GEOSTUDIO_OFFLINE):` and these values will be updated for you

```yaml
export GEOSTUDIO_OFFLINE=true # set to true
export HF_HOME_VALUE=/terratorch/gfm_models
export TRANSFORMERS_CACHE_VALUE=/terratorch/gfm_models
export HF_HUB_OFFLINE_VALUE=1 # set to 1
export TRANSFORMERS_OFFLINE_VALUE=1 # set to 1
FTUNING_IMAGE_PULL_POLICY_VALUE=IfNotPresent # set to IfNotPresent
```

Step 2: On an internet-connected machine, download all base model weights that you need and copy them to the air-gapped environment
```
pip install huggingface_hub

export HF_HOME=/some/dir

hf download ibm-esa-geospatial/TerraMind-1.0-tiny \
    TerraMind_v1_tiny.pt

scp -r $HF_HOME user@<transfer-host-ip>:/some/dir
```

Step 3: Create temporary helper pod to copy downloaded models to mounted pvc
```
kubectl apply -n default -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: model-loader
  labels:
    app: model-loader
spec:
  restartPolicy: Never
  containers:
    - name: loader
      image: docker.io/library/busybox:latest
      imagePullPolicy: IfNotPresent
      command: ["sh", "-c", "echo ready && sleep 3600"]
      volumeMounts:
        - name: backbone-models
          mountPath: /terratorch/gfm_models
  volumes:
    - name: backbone-models
      persistentVolumeClaim:
        claimName: gfm-ft-models-pvc
EOF
```

Step 4: Copy all downloaded models to the PVC

Copy backbone models downloaded to the HF_HOME_VALUE you set earlier if different from the default (default directory is /terratorch/gfm_models)

`kubectl cp` places a directory *inside* the destination if it already exists, so copy the contents using the `/.` suffix to merge directly into `/terratorch/gfm_models`:
```sh
kubectl cp /some/dir/. \
  default/model-loader:/terratorch/gfm_models
```

Step 5: Verify
```
kubectl exec -n default model-loader -- find /terratorch/gfm_models -type f -name "*.pt" | sort
```

Step 6: Try out

Terramind Tiny notebook: [https://terrastackai.github.io/geospatial-studio-toolkit/examples/e2e-walkthroughs/GeospatialStudio-Walkthrough-Flooding_Terramind_Tiny/](https://terrastackai.github.io/geospatial-studio-toolkit/examples/e2e-walkthroughs/GeospatialStudio-Walkthrough-Flooding_Terramind_Tiny/)


Step 7: List of all the base model image provided in the studio:

| Studio Name | HuggingFace repo |
|---|---|
| `Prithvi_EO_V1_100M` | [ibm-nasa-geospatial/Prithvi-EO-1.0](https://huggingface.co/ibm-nasa-geospatial/Prithvi-EO-1.0) |
| `Prithvi_EO_V2_300M` | [ibm-nasa-geospatial/Prithvi-EO-2.0-300M](https://huggingface.co/ibm-nasa-geospatial/Prithvi-EO-2.0-300M) |
| `Prithvi_EO_V2_600M_TL` | [ibm-nasa-geospatial/Prithvi-EO-2.0-600M-TL](https://huggingface.co/ibm-nasa-geospatial/Prithvi-EO-2.0-600M-TL) |
| `terramind_v1_tiny` | [ibm-esa-geospatial/TerraMind-1.0-tiny](https://huggingface.co/ibm-esa-geospatial/TerraMind-1.0-tiny) |
| `terramind_v1_base` | [ibm-esa-geospatial/TerraMind-1.0-base](https://huggingface.co/ibm-esa-geospatial/TerraMind-1.0-base) |
| `terramind_v1_large` | [ibm-esa-geospatial/TerraMind-1.0-large](https://huggingface.co/ibm-esa-geospatial/TerraMind-1.0-large) |
| `clay_v1_base` | [made-with-clay/Clay](https://huggingface.co/made-with-clay/Clay) |
| `timm_resnet18/34/50/101/152` | |
| `timm_convnext_large/xlarge` | |

### Inference: 

3.1 Satellite Data Acquisition (Terrakit Connectors) - bypass with internal url connector calls?

3.2 Foundation Model Downloads — HuggingFace ; The vLLM-based inference service container downloads geospatial foundation models from HuggingFace Hub on first startup


### Clean up
Delete temporary pod created earlier
```sh
kubectl delete pod model-loader -n default

```

