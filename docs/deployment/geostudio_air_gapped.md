# Geostudio airgapped

# Part 1 — Deployment-Time Dependencies -- Fiona
  1. Container Images — Every image pulled at deploy time from external registries, both geostudio quay images and other dependencies-- what you started with yesterday
  2. Helm Chart Repositories - external Helm repos fetched during deployment, e.g redis chart
  3. Geoserver deployment, some configurations are downloaded from the internet

# Part 2 — Runtime External Calls -- Beldine
## Navigation
1. Inference page

    1.1 UI Basemap Tiles — OpenStreetMap / Mapbox - Base layers from OpenStreetMaps are downloaded from internet - what I started looking into yesterday and today

    1.2 Geocoding - search feature, inference coordinates search

2. Dataset preview page - base map

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


## End-to-end walkthrough
### 1. Dataset onboarding - example datasets downloaded from the internet

### 2. Fine-tuning: base models are downloaded from hugging face

Step 1: Edit deployment values:
```yaml
export HF_HOME_VALUE=/tmp/huggingface
export TRANSFORMERS_CACHE_VALUE=/tmp/huggingface
export HF_HUB_OFFLINE_VALUE=1 # set to 1
export TRANSFORMERS_OFFLINE_VALUE=1 # set to 1
```

Step 2: Download all base model weights that you need and transfer them to air-gapped environment:
```
pip install huggingface_hub

huggingface-cli download ibm-esa-geospatial/TerraMind-1.0-tiny \
  --include "*.pt" \
  --local-dir ./gfm_models/terramind_v1_tiny
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
      image: busybox
      command: ["sh", "-c", "echo ready && sleep 3600"]
      volumeMounts:
        - name: backbone-models
          mountPath: /terratorch/gfm_models
  volumes:
    - name: backbone-models
      persistentVolumeClaim:
        claimName: gfm-ft-models-pvc
EOF

# kubectl delete pod model-loader -n default # Delete helper pod after step 4
```

Step 4: Create the expected subdirectory structure on the PVC
```sh
kubectl exec -n default model-loader -- sh -c "
  mkdir -p /terratorch/gfm_models/terramind_v1_tiny &&
  echo done
"
```

Step 4: Copy models to expected path
```
kubectl cp ./gfm_models/terramind_v1_tiny/terramind_v1_tiny.pt \
  default/model-loader:/terratorch/gfm_models/terramind_v1_tiny/terramind_v1_tiny.pt
```

Step 5: Verify
```
kubectl exec -n default model-loader -- find /terratorch/gfm_models -type f -name "*.pt" | sort
```

Step 6: Try out

### 3. Inference: 

3.1 Satellite Data Acquisition (Terrakit Connectors) - bypass with internal url connector calls?

3.2 Foundation Model Downloads — HuggingFace ; The vLLM-based inference service container downloads geospatial foundation models from HuggingFace Hub on first startup

