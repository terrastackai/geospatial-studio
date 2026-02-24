# Troubleshooting Guide

Common issues and solutions when working with IBM Geospatial Studio.

!!! tip "Deployment-Specific Commands"
    This guide provides commands for both **Local (Lima VM)** and **Cluster (Kubernetes/OpenShift)** deployments. Use the tabs to switch between deployment types where applicable.
    
    - **Local Deployment**: Uses Lima VM running Kubernetes on your laptop/workstation
    - **Cluster Deployment**: Uses production Kubernetes or OpenShift clusters

## 🚀 Deployment Issues

### Services Fail to Start

**Problem:** Services fail to start or pods/containers exit immediately.

**Solutions:**

=== "Local Deployment (Lima VM)"
    1. **Check Lima VM status:**
       ```bash
       limactl list
       limactl shell studio
       ```

    2. **Check pod status in Lima VM:**
       ```bash
       # Set kubeconfig
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       
       # Check pods
       kubectl get pods -n default
       ```

    3. **View pod logs:**
       ```bash
       kubectl logs <pod-name> -n default
       kubectl describe pod <pod-name> -n default
       ```

    4. **Ensure sufficient resources:**
       - Minimum 16GB RAM
       - 100GB free disk space
       - Check Lima VM disk space: `limactl shell studio df -h`

    5. **Restart Lima VM if needed:**
       ```bash
       limactl stop studio
       limactl start studio
       
       # Re-export kubeconfig
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       ```

=== "Cluster Deployment"
    1. **Check pod status:**
       ```bash
       kubectl get pods -n <namespace>
       # Or for OpenShift
       oc get pods -n <namespace>
       ```

    2. **View pod logs:**
       ```bash
       kubectl logs <pod-name> -n <namespace>
       # Or for OpenShift
       oc logs <pod-name> -n <namespace>
       
       # For all containers in a pod
       kubectl logs <pod-name> -n <namespace> --all-containers=true
       ```

    3. **Describe pod for details:**
       ```bash
       kubectl describe pod <pod-name> -n <namespace>
       # Or for OpenShift
       oc describe pod <pod-name> -n <namespace>
       ```

    4. **Check resource quotas:**
       ```bash
       kubectl get resourcequota -n <namespace>
       kubectl describe resourcequota -n <namespace>
       ```

    5. **Verify node resources:**
       ```bash
       kubectl top nodes
       kubectl describe node <node-name>
       ```

    6. **Check for ImagePullBackOff errors:**
       ```bash
       # If pods are stuck pulling images
       kubectl get events -n <namespace> --sort-by='.lastTimestamp'
       
       # Verify image pull secret
       kubectl get secret -n <namespace> | grep image-pull
       ```

### Port Forwarding Issues

**Problem:** Port forwarding fails or disconnects frequently.

**Solutions:**

=== "Local Deployment (Lima VM)"
    1. **Check if port forwarding is active:**
       ```bash
       # List all port-forward processes
       ps aux | grep "port-forward"
       
       # Check studio-pf.log for errors
       tail -f studio-pf.log
       ```

    2. **Restart port forwarding:**
       ```bash
       # Kill existing port-forwards
       pkill -f "kubectl port-forward"
       
       # Set kubeconfig and namespace
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       export OC_PROJECT=default
       
       # Restart all port-forwards
       kubectl port-forward -n $OC_PROJECT svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
       kubectl port-forward -n $OC_PROJECT svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
       kubectl port-forward -n $OC_PROJECT svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
       kubectl port-forward -n $OC_PROJECT deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
       kubectl port-forward -n $OC_PROJECT deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
       kubectl port-forward -n $OC_PROJECT deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
       kubectl port-forward -n $OC_PROJECT svc/minio 9001:9001 >> studio-pf.log 2>&1 &
       kubectl port-forward -n $OC_PROJECT svc/minio 9000:9000 >> studio-pf.log 2>&1 &
       ```

    3. **Check Lima VM network:**
       ```bash
       # Test connectivity to Lima VM
       limactl shell studio
       
       # Inside VM, check services
       kubectl get svc -n default
       ```

=== "Cluster Deployment"
    1. **Check if port forwarding is active:**
       ```bash
       # List all port-forward processes
       ps aux | grep "port-forward"
       
       # Check studio-pf.log for errors
       tail -f studio-pf.log
       ```

    2. **Restart port forwarding:**
       ```bash
       # Kill existing port-forwards
       pkill -f "port-forward"
       
       # Restart required port-forwards
       kubectl port-forward -n <namespace> svc/minio 9000:9000 >> studio-pf.log 2>&1 &
       kubectl port-forward -n <namespace> svc/minio 9001:9001 >> studio-pf.log 2>&1 &
       kubectl port-forward -n <namespace> svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
       kubectl port-forward -n <namespace> svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
       kubectl port-forward -n <namespace> svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
       kubectl port-forward deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
       kubectl port-forward deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
       kubectl port-forward deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
       ```

    3. **Use kubectl proxy as alternative:**
       ```bash
       kubectl proxy --port=8001
       # Access services via proxy
       ```

### Permission Denied Errors

**Problem:** Permission errors when running scripts or accessing files.

**Solutions:**

=== "Local Deployment"
    ```bash
    # Make scripts executable
    chmod +x deploy_studio_k8s.sh
    chmod +x deploy_studio_ocp.sh
    chmod +x deploy_studio_lima.sh
    chmod +x deployment-scripts/*.sh

    # Fix ownership issues
    sudo chown -R $USER:$USER .
    ```

=== "Cluster Deployment"
    1. **Check service account permissions:**
       ```bash
       kubectl get serviceaccount -n <namespace>
       kubectl describe serviceaccount default -n <namespace>
       ```

    2. **Check RBAC permissions:**
       ```bash
       kubectl get rolebinding -n <namespace>
       kubectl describe rolebinding <binding-name> -n <namespace>
       
       # Check cluster-wide permissions
       kubectl get clusterrolebinding | grep <namespace>
       ```

    3. **For OpenShift, check Security Context Constraints (SCC):**
       ```bash
       oc get scc
       oc describe scc anyuid
       
       # Add SCC to service account if needed (requires admin)
       oc adm policy add-scc-to-user anyuid -n <namespace> -z default
       ```

    4. **Check pod security policies:**
       ```bash
       kubectl get psp
       kubectl describe psp <policy-name>
       ```

### Configuration Not Loading

**Problem:** Services can't find configuration or environment variables.

**Solutions:**

=== "Local Deployment (Lima VM)"
    1. **Verify workspace env files exist:**
       ```bash
       # For Lima deployment, check lima workspace
       ls -la workspace/lima/env/.env
       ls -la workspace/lima/env/env.sh
       ```

    2. **Check environment variable format:**
       ```bash
       # Correct format (no spaces around =)
       GEOSTUDIO_API_KEY=your-key-here
       
       # Incorrect format
       GEOSTUDIO_API_KEY = your-key-here
       ```

    3. **Validate environment variables:**
       ```bash
       # Use the validation script
       python deployment-scripts/validate-env-files.py \
         --env-file workspace/lima/env/.env \
         --env-sh-file workspace/lima/env/env.sh
       ```

    4. **Source environment files:**
       ```bash
       source workspace/lima/env/env.sh
       ```

    5. **Verify kubeconfig is set:**
       ```bash
       echo $KUBECONFIG
       # Should be: /Users/<username>/.lima/studio/copied-from-guest/kubeconfig.yaml
       
       # If not set:
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       ```

=== "Cluster Deployment"
    1. **Check ConfigMaps:**
       ```bash
       kubectl get configmap -n <namespace>
       kubectl describe configmap <configmap-name> -n <namespace>
       
       # View ConfigMap content
       kubectl get configmap <configmap-name> -n <namespace> -o yaml
       ```

    2. **Check Secrets:**
       ```bash
       kubectl get secrets -n <namespace>
       kubectl describe secret <secret-name> -n <namespace>
       
       # Decode secret values
       kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.key}' | base64 -d
       ```

    3. **Verify environment variables in pod:**
       ```bash
       kubectl exec <pod-name> -n <namespace> -- env
       
       # Check specific variable
       kubectl exec <pod-name> -n <namespace> -- env | grep STUDIO
       ```

    4. **Update ConfigMap and restart pods:**
       ```bash
       kubectl edit configmap <configmap-name> -n <namespace>
       kubectl rollout restart deployment/<deployment-name> -n <namespace>
       ```

### Storage Issues

**Problem:** PVC not binding or storage errors.

**Solutions:**

=== "Cluster Deployment"
    1. **Check PVC status:**
       ```bash
       kubectl get pvc -n <namespace>
       kubectl describe pvc <pvc-name> -n <namespace>
       ```

    2. **Check storage classes:**
       ```bash
       kubectl get storageclass
       kubectl describe storageclass <storage-class-name>
       
       # Verify COS storage class (for MinIO/S3)
       kubectl get storageclass cos-s3-csi-s3fs-sc
       ```

    3. **Check PV availability:**
       ```bash
       kubectl get pv
       kubectl describe pv <pv-name>
       ```

    4. **Verify IBM Object CSI Driver (for S3 storage):**
       ```bash
       kubectl get pods -n kube-system -l app=cos-s3-csi-controller
       kubectl get pods -n kube-system -l app=cos-s3-csi-driver
       
       # Check driver logs
       kubectl logs -n kube-system -l app=cos-s3-csi-controller
       ```

    5. **Check node labels (for local storage):**
       ```bash
       kubectl get nodes --show-labels
       kubectl label nodes <node-name> topology.kubernetes.io/region=us-east-1
       kubectl label nodes <node-name> topology.kubernetes.io/zone=us-east-1a
       ```

## 🔐 Authentication Issues

### Cannot Generate API Key

**Problem:** API key generation fails in UI.

**Solutions:**

1. **Check if you have existing keys:**
   - Maximum 2 active keys per user
   - Delete old keys before creating new ones

2. **Verify authentication:**
   - Log out and log back in
   - Clear browser cache and cookies

3. **Check backend logs:**

=== "Local Deployment (Lima VM)"
    ```bash
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    kubectl logs -l app=geofm-gateway -n default
    ```

=== "Cluster Deployment"
    ```bash
    kubectl logs -l app=geofm-gateway -n <namespace>
    # Or for OpenShift
    oc logs -l app=geofm-gateway -n <namespace>
    ```

### Keycloak Authentication Fails

**Problem:** Cannot log in or Keycloak returns errors.

**Solutions:**

=== "Local Deployment (Lima VM)"
    1. **Check Keycloak pod:**
       ```bash
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       kubectl get pods -l app=keycloak -n default
       kubectl logs -l app=keycloak -n default
       ```

    2. **Verify Keycloak setup:**
       ```bash
       # Re-run Keycloak setup script
       ./deployment-scripts/setup-keycloak.sh
       ```

    3. **Check port forwarding:**
       ```bash
       # Ensure port-forward is active
       ps aux | grep "port-forward.*keycloak"
       
       # Test endpoint
       curl http://localhost:8080/realms/geostudio
       ```

    4. **Restart Keycloak port-forward if needed:**
       ```bash
       pkill -f "port-forward.*keycloak"
       kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
       ```

=== "Cluster Deployment"
    1. **Check Keycloak pod:**
       ```bash
       kubectl get pods -l app=keycloak -n <namespace>
       kubectl logs -l app=keycloak -n <namespace>
       ```

    2. **Verify Keycloak configuration:**
       ```bash
       # Check if realm exists
       kubectl port-forward -n <namespace> svc/keycloak 8080:8080 &
       curl http://localhost:8080/realms/geostudio
       ```

    3. **Check OAuth environment variables:**
       ```bash
       # Verify in workspace env files
       cat workspace/<deployment-env>/env/env.sh | grep OAUTH
       ```

    4. **For OpenShift, check routes:**
       ```bash
       oc get route keycloak -n <namespace>
       oc describe route keycloak -n <namespace>
       ```

### SDK Authentication Fails

**Problem:** `Client()` initialization fails with authentication error.

**Solutions:**

1. **Verify API key format:**
   ```python
   # Check your .geostudio_config_file
   cat .geostudio_config_file
   ```

2. **Ensure correct URL:**
   ```python
   # Use the correct base URL
   client = Client(
       api_key="your-key",
       base_url="https://localhost:4180"  # Include https://
   )
   ```

3. **Check SSL certificate:**
   ```python
   # For self-signed certificates
   import urllib3
   urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
   
   client = Client(
       api_key="your-key",
       base_url="https://localhost:4180",
       verify_ssl=False
   )
   ```

4. **Verify API key is valid:**
   ```bash
   # Test API key with curl
   curl -k -H "Authorization: Bearer <your-api-key>" https://localhost:4181/health
   ```

## 📊 Data Issues

### MinIO/S3 Connection Fails

**Problem:** Cannot connect to object storage.

**Solutions:**

=== "Local Deployment (Lima VM)"
    1. **Check MinIO pod:**
       ```bash
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       kubectl get pods -l app=minio -n default
       kubectl logs -l app=minio -n default
       ```

    2. **Verify MinIO credentials:**
       ```bash
       # Default credentials
       # Access Key: minioadmin
       # Secret Key: minioadmin
       
       # Check in workspace env
       cat workspace/lima/env/.env | grep -E "access_key_id|secret_access_key"
       ```

    3. **Test MinIO connection:**
       ```bash
       # Ensure port-forward is active
       ps aux | grep "port-forward.*minio"
       
       # Test endpoint
       curl -k https://localhost:9000/minio/health/live
       ```

    4. **Restart MinIO port-forwards if needed:**
       ```bash
       pkill -f "port-forward.*minio"
       kubectl port-forward -n default svc/minio 9000:9000 >> studio-pf.log 2>&1 &
       kubectl port-forward -n default svc/minio 9001:9001 >> studio-pf.log 2>&1 &
       ```

    5. **Verify buckets were created:**
       ```bash
       # Re-run bucket creation script
       python deployment-scripts/create_buckets.py --env-path workspace/lima/env/.env
       ```

=== "Cluster Deployment"
    1. **Check MinIO pod:**
       ```bash
       kubectl get pods -l app=minio -n <namespace>
       kubectl logs -l app=minio -n <namespace>
       ```

    2. **Verify MinIO service:**
       ```bash
       kubectl get svc minio -n <namespace>
       kubectl describe svc minio -n <namespace>
       ```

    3. **Check MinIO TLS secret:**
       ```bash
       kubectl get secret minio-tls-secret -n <namespace>
       kubectl describe secret minio-tls-secret -n <namespace>
       ```

    4. **Test MinIO connectivity:**
       ```bash
       # Port-forward and test
       kubectl port-forward -n <namespace> svc/minio 9000:9000 &
       curl -k https://localhost:9000/minio/health/live
       ```

    5. **Verify buckets were created:**
       ```bash
       # Re-run bucket creation script
       python deployment-scripts/create_buckets.py --env-path workspace/<deployment-env>/env/.env
       ```

### Dataset Onboarding Fails

**Problem:** Dataset upload or onboarding process fails.

**Solutions:**

1. **Check file format:**
   - Must be a ZIP file
   - Contains matching data and label pairs
   - Files have correct suffixes

2. **Verify file structure:**
   ```
   dataset.zip
   ├── tile_001_merged.tif
   ├── tile_001_mask.tif
   ├── tile_002_merged.tif
   └── tile_002_mask.tif
   ```

3. **Check file size limits:**
   - Individual files: < 2GB
   - Total dataset: < 10GB

4. **Validate band configuration:**
   ```python
   # Ensure band count matches your data
   "bands": [
       {"index": "0", "band_name": "Blue", ...},
       {"index": "1", "band_name": "Green", ...},
       # ... must match actual bands in files
   ]
   ```

### Cannot Access Pre-computed Examples

**Problem:** Example datasets not visible in UI or SDK.

**Solutions:**

1. **Check if examples are loaded:**
   ```python
   client.list_datasets()
   ```

2. **Verify backend is running:**

=== "Local Deployment (Lima VM)"
    ```bash
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    kubectl get pods -l app=geofm-gateway -n default
    kubectl logs -l app=geofm-gateway -n default
    ```

=== "Cluster Deployment"
    ```bash
    kubectl get pods -l app=geofm-gateway -n <namespace>
    kubectl logs -l app=geofm-gateway -n <namespace>
    ```

3. **Check database initialization:**

=== "Local Deployment (Lima VM)"
    ```bash
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    kubectl get pods -l app.kubernetes.io/name=postgresql -n default
    kubectl logs -l app.kubernetes.io/name=postgresql -n default
    ```

=== "Cluster Deployment"
    ```bash
    kubectl get pods -l app=postgres -n <namespace>
    kubectl logs -l app=postgres -n <namespace>
    ```

### File Not Found Errors in Notebooks

**Problem:** You see errors like:
```
FileNotFoundError: [Errno 2] No such file or directory: 'template-seg.json'
```

**Solutions:**

**Option 1: Clone the repository (Recommended)**
```bash
git clone https://github.com/terrastackai/geospatial-studio.git
cd geospatial-studio/workshop/docs/notebooks
jupyter notebook
```

**Option 2: Download missing files**

If you downloaded notebooks individually, you need to also download the JSON configuration files:

- **Lab 3 requires:**
  - `template-seg.json`
  - `tune-prithvi-eo-flood.json`

- **Lab 4 requires:**
  - `backbone-Prithvi_EO_V2_300M.json`
  - `dataset-burn_scars.json`
  - `template-seg.json`
Download these files from the [notebooks directory](https://github.com/terrastackai/geospatial-studio/tree/main/workshop/docs/notebooks) and place them in the same directory as your notebook.


**Verify files are in the correct location:**
```bash
# Check current directory
pwd

# List files
ls -la *.json

# Should see the required JSON files
```

## 🤖 Model Training Issues

### Fine-tuning Job Fails

**Problem:** Training job fails or gets stuck.

**Solutions:**

1. **Check GPU availability:**

=== "Local Deployment"
    ```bash
    nvidia-smi  # Should show available GPUs
    ```

=== "Cluster Deployment"
    ```bash
    # Check GPU nodes
    kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
    
    # Check GPU operator
    kubectl get pods -n gpu-operator-resources
    
    # Verify node labels
    kubectl get nodes --show-labels | grep nvidia
    
    # Check GPU resource allocation
    kubectl describe node <node-name> | grep -A 5 "Allocated resources"
    ```

2. **Verify dataset is onboarded:**
   ```python
   dataset = client.get_dataset(dataset_id)
   print(dataset['status'])  # Should be 'COMPLETED'
   ```

3. **Check training parameters:**
   ```python
   # Reduce batch size if OOM errors
   task_params['data']['batch_size'] = 2
   
   # Reduce epochs for testing
   task_params['runner']['max_epochs'] = 1
   ```

4. **Monitor MLflow logs:**

=== "Local Deployment (Lima VM)"
    - Access MLflow UI at `http://localhost:5000`
    - Check experiment logs for errors
    ```bash
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    kubectl logs -l app=geofm-mlflow -n default
    ```
    
    - Ensure MLflow port-forward is active:
    ```bash
    ps aux | grep "port-forward.*mlflow"
    # If not active, restart:
    kubectl port-forward -n default deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
    ```

=== "Cluster Deployment"
    - Access MLflow UI via port-forward or route
    - Check experiment logs
    ```bash
    kubectl logs -l app=geofm-mlflow -n <namespace>
    # Or for OpenShift
    oc logs -l app=geofm-mlflow -n <namespace>
    
    # Access MLflow UI
    kubectl port-forward -n <namespace> svc/geofm-mlflow 5000:5000
    ```

### Out of Memory (OOM) Errors

**Problem:** Training fails with CUDA out of memory.

**Solutions:**

1. **Reduce batch size:**
   ```python
   task_params['data']['batch_size'] = 2  # or 1
   ```

2. **Use gradient accumulation:**
   ```python
   task_params['trainer']['accumulate_grad_batches'] = 4
   ```

3. **Enable mixed precision:**
   ```python
   task_params['trainer']['precision'] = '16-mixed'
   ```

4. **Clear GPU cache:**
   ```python
   import torch
   torch.cuda.empty_cache()
   ```

5. **Check GPU memory:**

=== "Cluster Deployment"
    ```bash
    # Check GPU memory usage on nodes
    kubectl exec -it <training-pod> -n <namespace> -- nvidia-smi
    ```

## 🔄 Inference Issues

### Inference Request Fails

**Problem:** Inference submission returns error.

**Solutions:**

1. **Verify model is deployed:**
   ```python
   models = client.list_tunes()
   print(models)
   ```

2. **Check spatial domain format:**
   ```python
   # Correct bbox format: [min_lon, min_lat, max_lon, max_lat]
   "bbox": [[-121.84, 39.83, -121.64, 40.04]]
   ```

3. **Validate temporal domain:**
   ```python
   # Correct format: YYYY-MM-DD_YYYY-MM-DD
   "temporal_domain": ["2024-08-12_2024-08-13"]
   ```

4. **Check data availability:**
   - Ensure satellite data exists for your date range
   - Try a different date if no data available

### Inference Takes Too Long

**Problem:** Inference job runs for hours without completing.

**Solutions:**

1. **Reduce spatial extent:**
   ```python
   # Use smaller bounding box for testing
   bbox = [-121.80, 39.90, -121.70, 40.00]
   ```

2. **Check task status:**
   ```python
   client.get_inference(inference_id)
   ```

3. **Monitor backend logs:**

=== "Local Deployment (Lima VM)"
    ```bash
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    kubectl logs -l app=inference-service -n default -f
    ```

=== "Cluster Deployment"
    ```bash
    kubectl logs -l app=inference-service -n <namespace> -f
    # Or for OpenShift
    oc logs -l app=inference-service -n <namespace> -f
    ```

### Cannot Download Inference Results

**Problem:** Download links expired or files not found.

**Solutions:**

1. **Check task completion:**
   ```python
   tasks = client.get_inference_tasks(inference_id)
   # Ensure status is 'FINISHED'
   ```

2. **Regenerate download links:**
   ```python
   # Links expire after 24 hours
   client.get_inference_tasks(inference_id)  # Gets fresh links
   ```

3. **Use SDK download widget:**
   ```python
   from geostudio import gswidgets
   gswidgets.fileDownloaderTasks(client=client, task_id=task_id)
   ```

## 🌐 Network Issues

### Cannot Access UI

**Problem:** Cannot reach the Studio UI in browser.

**Solutions:**

=== "Local Deployment (Lima VM)"
    **Problem:** Browser cannot reach `https://localhost:4180`.

    1. **Check Lima VM is running:**
       ```bash
       limactl list
       # Status should be "Running"
       ```

    2. **Check if pods are running:**
       ```bash
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       kubectl get pods -n default
       ```

    3. **Verify port forwarding is active:**
       ```bash
       ps aux | grep "port-forward.*geofm-ui"
       
       # If not active, restart:
       kubectl port-forward -n default deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
       ```

    4. **Test endpoint:**
       ```bash
       curl -k https://localhost:4180
       ```

    5. **Check firewall settings:**
       ```bash
       # macOS
       sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
       
       # Linux
       sudo ufw status
       ```

    6. **Try different browser:**
       - Clear cache and cookies
       - Try incognito/private mode
       - Accept self-signed certificate

    7. **Check Lima VM logs:**
       ```bash
       limactl shell studio
       # Inside VM, check system logs
       journalctl -xe
       ```

=== "Cluster Deployment"
    **Problem:** Cannot reach Studio UI via ingress/route.

    1. **Check ingress/route status:**
       ```bash
       # Kubernetes
       kubectl get ingress -n <namespace>
       kubectl describe ingress geofm-ui -n <namespace>
       
       # OpenShift
       oc get routes -n <namespace>
       oc describe route geofm-ui -n <namespace>
       ```

    2. **Verify DNS resolution:**
       ```bash
       # Get the route URL
       export UI_ROUTE_URL=$(oc get route geofm-ui -o jsonpath='{"https://"}{.spec.host}')
       echo $UI_ROUTE_URL
       
       # Test DNS
       nslookup <hostname>
       dig <hostname>
       ```

    3. **Test internal connectivity:**
       ```bash
       # Port-forward to test
       kubectl port-forward -n <namespace> deployment/geofm-ui 4180:4180 &
       # Then access https://localhost:4180
       ```

    4. **Check ingress controller:**
       ```bash
       # Kubernetes
       kubectl get pods -n ingress-nginx
       kubectl logs -n ingress-nginx <ingress-controller-pod>
       
       # OpenShift (uses built-in router)
       oc get pods -n openshift-ingress
       oc logs -n openshift-ingress <router-pod>
       ```

    5. **Verify TLS certificates:**
       ```bash
       # Check TLS secret
       kubectl get secret -n <namespace> | grep tls
       kubectl describe secret <tls-secret-name> -n <namespace>
       ```

### SSL Certificate Errors

**Problem:** Browser shows SSL/TLS errors.

**Solutions:**

1. **Accept self-signed certificate:**
   - Click "Advanced" → "Proceed to localhost"
   - Add exception in browser settings

2. **For cluster deployments, check certificate:**
   ```bash
   # View certificate details
   openssl s_client -connect <hostname>:443 -showcerts
   ```

3. **Regenerate certificates if needed:**

=== "Cluster Deployment"
    ```bash
    # For Kubernetes
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout tls.key -out tls.crt \
      -subj "/CN=<your-domain>"
    
    kubectl create secret tls <secret-name> \
      --cert=tls.crt --key=tls.key -n <namespace>
    ```

### Geoserver Connection Issues

**Problem:** Cannot access Geoserver or layers not loading.

**Solutions:**

=== "Local Deployment (Lima VM)"
    1. **Check Geoserver pod:**
       ```bash
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       kubectl get pods -l app.kubernetes.io/name=gfm-geoserver -n default
       kubectl logs -l app.kubernetes.io/name=gfm-geoserver -n default
       ```

    2. **Verify Geoserver port-forward:**
       ```bash
       ps aux | grep "port-forward.*geoserver"
       
       # If not active, restart:
       kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
       ```

    3. **Test Geoserver endpoint:**
       ```bash
       curl http://localhost:3000/geoserver/web/
       ```

    4. **Verify Geoserver credentials:**
       ```bash
       # Default credentials
       # Username: admin
       # Password: geoserver
       
       # Check in workspace env
       cat workspace/lima/env/.env | grep geoserver
       ```

    5. **Re-run Geoserver setup:**
       ```bash
       ./deployment-scripts/setup_geoserver.sh
       ```

=== "Cluster Deployment"
    1. **Check Geoserver pod:**
       ```bash
       kubectl get pods -l app.kubernetes.io/name=gfm-geoserver -n <namespace>
       kubectl logs -l app.kubernetes.io/name=gfm-geoserver -n <namespace>
       ```

    2. **Verify Geoserver service:**
       ```bash
       kubectl get svc geofm-geoserver -n <namespace>
       kubectl describe svc geofm-geoserver -n <namespace>
       ```

    3. **Test Geoserver connectivity:**
       ```bash
       kubectl port-forward -n <namespace> svc/geofm-geoserver 3000:3000 &
       curl http://localhost:3000/geoserver/web/
       ```

    4. **Re-run Geoserver setup:**
       ```bash
       ./deployment-scripts/setup_geoserver.sh
       ```

    5. **For OpenShift with SCC issues:**
       ```bash
       # Check if anyuid SCC is applied
       oc describe scc anyuid | grep <namespace>
       
       # Apply if needed (requires admin)
       oc adm policy add-scc-to-user anyuid -n <namespace> -z default
       ```

## 🗄️ Database Issues

### Database Connection Fails

**Problem:** Services cannot connect to PostgreSQL.

**Solutions:**

=== "Local Deployment (Lima VM)"
    1. **Check PostgreSQL pod:**
       ```bash
       export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
       kubectl get pods -l app.kubernetes.io/name=postgresql -n default
       kubectl logs -l app.kubernetes.io/name=postgresql -n default
       ```

    2. **Verify database credentials:**
       ```bash
       # Check workspace env file
       cat workspace/lima/env/.env | grep pg_
       
       # Default password: devPostgresql123
       ```

    3. **Check database port-forward:**
       ```bash
       ps aux | grep "port-forward.*postgresql"
       
       # If not active, restart:
       kubectl port-forward -n default svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
       ```

    4. **Test database connection:**
       ```bash
       # Install psql if needed
       psql -h localhost -p 54320 -U postgres -d geostudio
       ```

    5. **Check database logs:**
       ```bash
       kubectl logs -l app.kubernetes.io/name=postgresql -n default
       ```

    6. **Re-create databases if needed:**
       ```bash
       python deployment-scripts/create_studio_dbs.py \
         --env-path workspace/lima/env/.env
       ```

=== "Cluster Deployment"
    1. **Check PostgreSQL pod:**
       ```bash
       kubectl get pods -l app.kubernetes.io/name=postgresql -n <namespace>
       kubectl logs -l app.kubernetes.io/name=postgresql -n <namespace>
       ```

    2. **Verify database credentials:**
       ```bash
       kubectl get secret postgresql -n <namespace> -o yaml
       
       # Decode password
       kubectl get secret postgresql -n <namespace> -o jsonpath='{.data.postgres-password}' | base64 -d
       ```

    3. **Check database connectivity:**
       ```bash
       # Port-forward to database
       kubectl port-forward -n <namespace> svc/postgresql 54320:5432 &
       
       # Test connection
       psql -h localhost -p 54320 -U postgres -d geostudio
       ```

    4. **Check PVC status:**
       ```bash
       kubectl get pvc -n <namespace>
       kubectl describe pvc postgresql-pvc -n <namespace>
       ```

    5. **Re-create databases:**
       ```bash
       python deployment-scripts/create_studio_dbs.py \
         --env-path workspace/<deployment-env>/env/.env
       ```

### Database Migration Fails

**Problem:** Database schema migration errors.

**Solutions:**

1. **Check database logs for errors:**

=== "Local Deployment (Lima VM)"
    ```bash
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    kubectl logs -l app.kubernetes.io/name=postgresql -n default | grep ERROR
    ```

=== "Cluster Deployment"
    ```bash
    kubectl logs -l app.kubernetes.io/name=postgresql -n <namespace> | grep ERROR
    ```

2. **Verify database exists:**
   ```bash
   # Connect to database
   psql -h localhost -p 54320 -U postgres
   
   # List databases
   \l
   
   # Check if geostudio database exists
   \c geostudio
   ```

3. **Re-run database creation:**
   ```bash
   python deployment-scripts/create_studio_dbs.py \
     --env-path workspace/<deployment-env>/env/.env
   ```

## 🔍 Debugging Tips

### Enable Debug Logging

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Check Service Health

=== "Local Deployment (Lima VM)"
    ```bash
    # Set kubeconfig
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"

    # Check all pods
    kubectl get pods -n default

    # Check specific pod logs
    kubectl logs <pod-name> -n default -f

    # Check resource usage
    kubectl top pods -n default
    kubectl top nodes
    
    # Check Lima VM status
    limactl list
    
    # Check Lima VM resources
    limactl shell studio
    # Inside VM:
    df -h
    free -h
    top
    ```

=== "Cluster Deployment"
    ```bash
    # Check all pods
    kubectl get pods -n <namespace>

    # Check specific pod logs
    kubectl logs <pod-name> -n <namespace> -f

    # Check resource usage
    kubectl top pods -n <namespace>
    kubectl top nodes
    
    # Check all resources
    kubectl get all -n <namespace>
    ```

### Inspect Container/Pod

=== "Local Deployment (Lima VM)"
    ```bash
    # Set kubeconfig
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"

    # Enter running pod
    kubectl exec -it <pod-name> -n default -- /bin/bash

    # Check environment variables
    kubectl exec <pod-name> -n default -- env

    # Check file system
    kubectl exec <pod-name> -n default -- ls -la

    # Copy files from pod
    kubectl cp default/<pod-name>:/path/to/file ./local-file
    
    # Access Lima VM directly
    limactl shell studio
    ```

=== "Cluster Deployment"
    ```bash
    # Enter running pod
    kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

    # Check environment variables
    kubectl exec <pod-name> -n <namespace> -- env

    # Check file system
    kubectl exec <pod-name> -n <namespace> -- ls -la

    # Copy files from pod
    kubectl cp <namespace>/<pod-name>:/path/to/file ./local-file
    ```

### Monitor Events

=== "Cluster Deployment"
    ```bash
    # Watch events in namespace
    kubectl get events -n <namespace> --watch

    # Get events for specific pod
    kubectl describe pod <pod-name> -n <namespace> | grep Events -A 20
    
    # Sort events by timestamp
    kubectl get events -n <namespace> --sort-by='.lastTimestamp'
    ```

### Check Helm Deployment

=== "Cluster Deployment"
    ```bash
    # List Helm releases
    helm list -n <namespace>
    
    # Get Helm release status
    helm status geospatial-studio -n <namespace>
    
    # Get Helm values
    helm get values geospatial-studio -n <namespace>
    
    # Check Helm history
    helm history geospatial-studio -n <namespace>
    ```

### Validate Environment Configuration

```bash
# Use the validation script
python deployment-scripts/validate-env-files.py \
  --env-file workspace/<deployment-env>/env/.env \
  --env-sh-file workspace/<deployment-env>/env/env.sh \
  --env-variables "studio_api_key,access_key_id,secret_access_key" \
  --env-sh-variables "DEPLOYMENT_ENV,OC_PROJECT,CLUSTER_URL"
```

## 📞 Getting Help

If you're still experiencing issues:

1. **Collect logs:**

=== "Local Deployment (Lima VM)"
    ```bash
    # Set kubeconfig
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    
    # Collect all pod logs
    kubectl logs -l app=geospatial-studio -n default --all-containers=true > logs.txt
    
    # Collect events
    kubectl get events -n default --sort-by='.lastTimestamp' > events.txt
    
    # Collect Lima VM info
    limactl list > lima-status.txt
    limactl shell studio df -h > lima-disk.txt
    
    # Collect port-forward logs
    cat studio-pf.log > port-forward-logs.txt
    ```

=== "Cluster Deployment"
    ```bash
    # Collect all pod logs
    kubectl logs -l app=geospatial-studio -n <namespace> --all-containers=true > logs.txt
    
    # Or use stern for better log aggregation
    stern -n <namespace> . > logs.txt
    
    # Collect events
    kubectl get events -n <namespace> --sort-by='.lastTimestamp' > events.txt
    ```

2. **Gather system information:**

=== "Local Deployment (Lima VM)"
    ```bash
    # Host system info
    limactl --version
    kubectl version --client
    helm version
    python --version
    pip list
    
    # Lima VM info
    limactl list
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    kubectl version
    kubectl get nodes -o wide
    
    # Workspace info
    ls -la workspace/lima/env/
    cat workspace/lima/env/env.sh | grep -E "DEPLOYMENT_ENV|OC_PROJECT"
    ```

=== "Cluster Deployment"
    ```bash
    kubectl version
    helm version
    python --version
    pip list
    
    # Cluster information
    kubectl cluster-info
    kubectl get nodes -o wide
    
    # For OpenShift
    oc version
    oc get clusterversion
    ```

3. **Check deployment configuration:**

=== "Local Deployment (Lima VM)"
   ```bash
   # Review workspace environment files
   cat workspace/lima/env/env.sh
   cat workspace/lima/env/.env
   
   # Review Helm values
   cat workspace/lima/values/geospatial-studio/values-deploy.yaml
   
   # Check Lima VM configuration
   cat deployment-scripts/lima/studio.yaml  # macOS
   cat deployment-scripts/lima/studio-linux.yaml  # Linux
   ```

=== "Cluster Deployment"
   ```bash
   # Review workspace environment files
   cat workspace/<deployment-env>/env/env.sh
   cat workspace/<deployment-env>/env/.env
   
   # Review Helm values
   cat workspace/<deployment-env>/values/geospatial-studio/values-deploy.yaml
   ```

4. **Search existing issues:**
   - [Geospatial Studio Issues](https://github.com/terrastackai/geospatial-studio/issues)
   - [Geospatial Studio Toolkit Issues](https://github.com/terrastackai/geospatial-studio-toolkit/issues)

5. **Create a new issue:**
   - Include error messages
   - Provide steps to reproduce
   - Share relevant logs
   - Mention your environment (OS, deployment type, cluster version, etc.)

6. **Community support:**
   - Check [FAQ](faq.md) for common questions
   - Review [Additional Resources](additional-resources.md) for documentation

---

[← Back: Additional Resources](additional-resources.md){ .md-button } [Next: FAQ →](faq.md){ .md-button .md-button--primary }
