# Local VM Cluster Setup

This guide provides detailed deployment instructions for a local cluster deployment in a VM.  This is only recommended for testing and development purposes.

Below we provide two different deployment options, which are similar during deployment, and mainly differ in initial setup.

* Lima VM
* Minikube

## VM cluster initialisation
Here you need to follow either the Lima VM *or* the Minikube instructions.

### Lima VM setup

**Prerequisites**

* [Lima VM](https://lima-vm.io/docs/installation/) - v1.2.1 (*currently incompatible with v2*)
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above) 
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor
* Minimum 8GB RAM and 4 CPUs available for the VM (more recommended)

**VM cluster initialization**

1. Install [Lima VM](https://github.com/lima-vm/lima). Needs to be *v1.2.1* (not yet compatible with v2)

2. Install Python dependencies:
```shell
pip install -f requirements.txt
```

3. Start the Lima VM cluster:
```shell
limactl start --name=studio deployment-scripts/lima/studio.yaml
```

4. Set up the kubectl context (*NB: you will need to do this in each terminal prompt where you with to interact with the cluster, i.e. deploy, k9s*):
```shell
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
```

5. To monitor subsequent deployment on the cluster you can use a tool such as [k9s](https://k9scli.io).

Other lima commands that you might find useful are:

```bash
# List vms
limactl ls

# Open a shell for the vm
limactl shell studio

# Stop the vm
limactl stop studio

# Delete the vm (useful if you wish to do a clean deployment, also delete persisted data separately)
limactl delete studio --force
```

### Minikube setup

**Prerequisites**

* Docker / Podman installed and running
* [Helm](https://helm.sh/docs/v3/) - v3.19 (*currently incompatible with v4*)
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above) 
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor
* Minimum 8GB RAM and 4 CPUs available for the VM (more recommended)

**VM cluster initialization**

1. Follow the [Getting started](https://minikube.sigs.k8s.io/docs/start) guide to setup and install your local minikube instance.


2. Start the Minikube cluster.  *Ensure your container machine configuration has resource allocation for memory > 8g and cpu > 4*

```bash
# Start with recommended resources for geospatial workloads
minikube start --driver=podman --container-runtime=containerd  --memory=8g --cpus=4

# Verify cluster is running
minikube status
```

3. Install the following minikube addons:
```bash
minikube addons enable metrics-server
minikube addons enable storage-provisioner
minikube addons enable dashboard
```

4. Setup the kubectl context:
```bash
# Set kubectl context to minikube
kubectl config use-context minikube

# Verify you're connected to the right cluster
kubectl config current-context
```

5. To monitor deployment on the cluster you can use:
```bash
minikube dashboard
```


## Geospatial Studio - Deployment instructions (automated)
<!-- Alternatively, you can install using an automated script.  This will deploy the dependencies (MinIO, Keycloak, Postgres) and set them up, before deploying the studio and pipelines.

NB: you need to be in a python environment with the requirements installed (from `requirements.txt`). -->
<!-- 
```bash
./run_deploy_steps_lima.sh
``` -->

<!-- Once the deployment is complete, it should report the URL for accessing the UI and the gateway API.  It will also provide the inital dev apikey and database password.  (For production deployment, these should be changed). -->
If you want to use the automated deployment script, run the following command:

```shell
./deploy_studio_lima.sh
```

*Deployment can take ~10 minutes (or longer) depending available download speed for container images.*

You can monitor the progress and debug using [`k9s`](https://k9scli.io) or similar tools.
```shell
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
k9s
```

| After deployment: | |
|---|---|
| Access the Studio UI | [https://localhost:4180](https://localhost:4180) |
| Access the Studio API | [https://localhost:4181](https://localhost:4181) |
| Authenticate Studio | username: `testuser` password: `testpass123` |
| Access Geoserver | [http://localhost:3000](http://localhost:3000) |
| Authenticate Geoserver | username: `admin` password: `geoserver` |
| Access Keycloak | [http://localhost:8080](http://localhost:8080) |
| Authenticate Keycloak | username: `admin` password: `admin` |
| Access MinIO | Console: [https://localhost:9001](https://localhost:9001)      API: [https://localhost:9000](https://localhost:9000) |
| Authenticate MinIO | username: `minioadmin` password: `minioadmin` |

If you need to restart any of the port-forwards you can use the following commands:
```shell
kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
```

This is printed at the end of the installation script. In case you missed it and have issues with keycloak, Run this command to configure the `etc/hosts ` for seamless connection as some of the services may call the internal urls on the host machine.

```shell
echo -e \"127.0.0.1 keycloak.default.svc.cluster.local postgresql.default.svc.cluster.local minio.default.svc.cluster.local geofm-ui.default.svc.cluster.local geofm-gateway.default.svc.cluster.local geofm-geoserver.default.svc.cluster.local\" >> /etc/hosts

```

## Geospatial Studio - Deployment instructions (manual)

> Note: Strictly run all the scripts in this guide from the root directory of this repository.

**Deployment steps:**

1. [Cluster configuration](#1-cluster-configuration)
2. [Initialize environment variables](#2-initialize-environment-variables)
3. [Create and configure COS instance and buckets](#3-storage-setup)
4. [Create and configure DBs + tables](#4-database-preparation)
5. [Setup authenticator](#5-authenticator-setup)
6. [Geoserver setup](#6-geoserver-setup)
7. [External services (Optional)](#7-external-services-configuration)
8. [Deploy studio services](#8-deploy-geospatial-studio-services)
9. [End-to-end tests](#9-end-to-end-tests)


## 1. Cluster configuration

### Initialization

Provide a name for the deployment environment. This will be the name used for a local folder created under workspace directory.

```bash
export DEPLOYMENT_ENV=lima
# or
export DEPLOYMENT_ENV=minikube
```

Use the `default` namespace in lima vm cluster
```bash
export OC_PROJECT=default
```

This step will create two env scripts under the workspace/${DEPLOYMENT_ENV}/env folder.  One script contains just the secret values template, and the other script contains all the other general Geospatial configuration.

```bash
./deployment-scripts/setup-workspace-env.sh
```

Update the CLUSTER_URL in `workspace/${DEPLOYMENT_ENV}/env/env.sh` to be:
```bash
# CLUSTER
export CLUSTER_URL=localhost
```

***Note*** Work through each env var in `workspace/${DEPLOYMENT_ENV}/env` and poplulate environment variables as required at this time or as you generate them in the subsequent steps.


## 2. Storage setup

The following storage options are supported:
- MinIO. A local cloud object storage installation (Default)
- External cloud object storage service e.g. IBM Cloud Object Storage, AWS S3
- Mounted volumes utilizing local storage on the host machine.

This section assumes you wish to use a locally deployed instance of MinIO to provide S3-compatible object storage.

> Note:  Source the variables to export any newly added variables.
```bash
source workspace/$DEPLOYMENT_ENV/env/env.sh
```

### Set up S3 compatible storage

#### MinIO

Deploy MinIO for S3-compatible object storage:
```bash
# Install MinIO
# Create TLS for MinIO
openssl genrsa -out minio-private.key 2048
openssl req -new -x509 -nodes -days 730 -keyout minio-private.key -out minio-public.crt --config deployment-scripts/minio-openssl.conf

kubectl create secret tls minio-tls-secret --cert=minio-public.crt --key=minio-private.key -n ${OC_PROJECT}
# Create configmap required by cloud object storage drivers
kubectl create configmap minio-public-config --from-file=minio-public.crt -n kube-system
# Install MinIO
python ./deployment-scripts/update-deployment-template.py --disable-route --filename deployment-scripts/minio-deployment.yaml | kubectl apply -f - -n ${OC_PROJECT}
```

Wait for MinIO to be ready:
```bash
kubectl wait --for=condition=ready pod -l app=minio -n default --timeout=300s
```

#### Access MinIO Console
To access the MinIO console:
```bash
# Port forward to access MinIO console at http://localhost:9001
kubectl port-forward -n default svc/minio-console 9001:9001 &
```
Login with username: `minioadmin`, password: `minioadmin`
...

#### Install cloud object storage drivers in the cluster
```bash
# Ensure node has labels required by drivers
kubectl label nodes lima-studio topology.kubernetes.io/region=us-east-1 topology.kubernetes.io/zone=us-east-1a

# Install the drivers
kubectl apply -k deployment-scripts/ibm-object-csi-driver/
```


> Note:  This script should be run once only, if run before you should see the `deployment-scripts/.env` file 

* Once the S3 instance has been created, you can add the credentials and endpoint to the `workspace/${DEPLOYMENT_ENV}/env/.env` file as shown below.

  ```
  access_key_id=minioadmin
  secret_access_key=minioadmin
  #endpoint=https://minio.default.svc.cluster.local:9000
  endpoint=https://localhost:9000
  region=us-east
  ```

* Also at this point update `workspace/${DEPLOYMENT_ENV}/env/.env.sh` with...
  ```bash
  # Storage classes
  export COS_STORAGE_CLASS=cos-s3-csi-s3fs-sc
  export NON_COS_STORAGE_CLASS=local-path
  ```

### Create the required buckets

Run the following script to create the buckets:

```bash
# Port forward to access MinIO api at https://localhost:9000
kubectl port-forward -n default svc/minio 9000:9000 &
```

```bash
python deployment-scripts/create_buckets.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env
```

> NB: to update the list of buckets to create, currently you need to edit the list in the python script.


Once you create the buckets update the minio endpoint `workspace/${DEPLOYMENT_ENV}/env/.env` with

```
endpoint=https://minio.default.svc.cluster.local:9000
#endpoint=https://127.0.0.1:9000
```


## 3. Database preparation
The studio uses Postgresql for storing meta and operational data.  Here we will deploy an instance on the local cluster, you could alternatively use a cloud-managed instance.

> Note:  Source the variables to export any newly added variables.
```bash
source workspace/$DEPLOYMENT_ENV/env/env.sh
```

### Set up Postgresql instance

#### Setting up a Postgresql database instance in cluster

Add bitnami chart repository:

```bash
helm repo add bitnami  https://charts.bitnami.com/bitnami
helm repo update
```

Install postgres:

***Note*** If you have an instance of postgres already installed, following this guide to [uninstall](postgres-uninstall.md).

```bash
./deployment-scripts/install-postgres.sh
```

Once completed, in terminal you will find some notes on the created postgres database. To prepare for the [create databases](#create-databases) section below, follow these steps..
* To get the password for "postgres" run:
  ```bash
  export POSTGRES_PASSWORD=$(kubectl get secret --namespace ${OC_PROJECT} postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
  ```

* To connect to your database from outside the cluster for [create databases](#create-databases) section below execute the following commands:

***Note*** change host port from default 54320 in the command below if the value of `pg_forwarded_port` was changed in `workspace/${DEPLOYMENT_ENV}/env/.env`

  ```bash
  kubectl port-forward --namespace ${OC_PROJECT} svc/postgresql 54320:5432 &
  PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 54320
  ```

* Update `workspace/${DEPLOYMENT_ENV}/env/.env` with...
  ```bash
  pg_username=postgres
  pg_password=<POSTGRES_PASSWORD>
  pg_uri=127.0.0.1
  pg_port=5432
  pg_original_db_name='postgres'
  ```
  > Note: after completing [create databases](#create-databases) section below update   `pg_uri` in `workspace/${DEPLOYMENT_ENV}/env/.env` with...
  ```bash
  pg_uri=postgresql.default.svc.cluster.local
  ```

### Create databases

> Once you have created the postgresql instance, you will need to gather the instance url, the port, the username, password and initial database, put these in the `workspace/${DEPLOYMENT_ENV}/env/.env` file.

To create the required databases and users, run the script:

```bash
python deployment-scripts/create_studio_dbs.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env
```

Once you create the databases update the pg_uri in `workspace/${DEPLOYMENT_ENV}/env/.env` with

```
pg_uri=postgresql.default.svc.cluster.local
#pg_uri=127.0.0.1
```

## 4. Authenticator setup
We use an OAuth2 authenticatorfor user authentication for the platform. This can be configured to use an external authenticator service or a service deployed on the cluster. At the moment our charts are configured to use [Keycloak](https://www.keycloak.org), although you could update to use other OAuth2 providers, such as IBM Security Verify (code include).

> Note:  Source the variables to export any newly added variables.
```bash
source workspace/$DEPLOYMENT_ENV/env/env.sh
```

### Installing and setup

#### 1. Keycloak

Deploy Keycloak for authentication:
```bash
kubectl apply -f deployment-scripts/keycloak-deployment.yaml -n default
```

Wait for Keycloak to be ready:
```bash
kubectl wait --for=condition=ready pod -l app=keycloak -n default --timeout=300s
```

#### Configure Keycloak Realm and Client
You can either use the `deployment-scripts/setup-keycloak.sh` script to create the realm, client and test user, or you can follow the instructions below to create them manually through the Keycloak dashboard.

---
1. **Access Keycloak Admin Console**:
   ```bash
   # Port forward to access Keycloak at http://localhost:8080
   kubectl port-forward -n default svc/keycloak 8080:8080 &
   ```
   - Open: http://localhost:8080
   - Login with username: `admin`, password: `admin`

2. **Create Realm**:
   - Click on "master" dropdown in top-left
   - Click "Create Realm"
   - Realm name: `geostudio`
   - Click "Create"

3. **Create Client**:
   - Go to "Clients" → "Create client"
   - Client ID: `geostudio-client`
   - Client type: `OpenID Connect`
   - Click "Next"
   - Client authentication: `ON`
   - Authorization: `OFF`
   - Authentication flow: Check all boxes (Standard flow, Direct access grants, etc.)
   - Valid redirect URIs: 
     ```
     https://geofm-ui.default.svc.cluster.local:4180/oauth2/callback
     https://geofm-gateway.default.svc.cluster.local:4180/oauth2/callback
     ```
   - Web origins: `*`
   - Click "Save"

4. **Get Client Secret**:
   - Go to "Clients" → "geostudio-client" → "Credentials" tab
   - Copy the "Client secret" value
   - Generate cookie secret as below
     ```bash
     openssl rand -base64 32 | tr -- '+/' '-_'
     ```
   - Update your `workspace/${DEPLOYMENT_ENV}/env/.env` file with this secrets

      ```bash
      # Oauth Credentials
      oauth_client_secret=
      oauth_cookie_secret=
      ```

5. **Create Test User** (Optional):
   - Go to "Users" → "Create new user"
   - Username: `testuser`
   - Email: `test@example.com`
   - First name: `Test`
   - Last name: `User`
   - Click "Create"
   - Go to "Credentials" tab → "Set password"
   - Password: `testpass123`
   - Temporary: `OFF`
   - Click "Save"
---

Once you setup the authenticator (with either method), update `workspace/${DEPLOYMENT_ENV}/env/.env.sh` with...
```bash
# AUTH
export OAUTH_TYPE=keycloak # for Keycloak
export OAUTH_CLIENT_ID=geostudio-client
export OAUTH_ISSUER_URL=http://keycloak.default.svc.cluster.local:8080/realms/geostudio
export OAUTH_URL=http://keycloak.default.svc.cluster.local:8080/realms/geostudio/protocol/openid-connect/auth
```

For a kubernetes environment create a tls secret key and crt pair.
```bash
# create tls.key and tls.crt

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=default.svc.cluster.local"

# extract the cert and key into env vars

export TLS_CRT_B64=$(openssl base64 -in tls.crt -A)
export TLS_KEY_B64=$(openssl base64 -in tls.key -A)
```

Update `workspace/${DEPLOYMENT_ENV}/env/.env` with...

```bash
tls_crt_b64=$TLS_CRT_B64
tls_key_b64=$TLS_KEY_B64
```

Update `workspace/${DEPLOYMENT_ENV}/env/env.sh` with...

```bash
export CREATE_TLS_SECRET=true
```

Update your etc hosts with the local urls
```bash
# Add our internal cluster urls to etc hosts for seamless connectivity since some of the services may call these internal urls on host machine

echo -e "\n#lima\n127.0.0.1 keycloak.default.svc.cluster.local postgresql.default.svc.cluster.local minio.default.svc.cluster.local geofm-ui.default.svc.cluster.local geofm-gateway.default.svc.cluster.local" >> /etc/hosts
```

## 5. Geoserver setup
To deploy Geoserver.  This will deploy geoserver, wait for the deployment to be completed and then start the required port-forwarding:
```bash
export GEOSERVER_URL=http://localhost:3000/geoserver

python ./deployment-scripts/update-deployment-template.py --filename deployment-scripts/geoserver-deployment.yaml --disable-route | kubectl apply -f - -n ${OC_PROJECT}

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gfm-geoserver -n default --timeout=900s

kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
```

Once the deployment is complete and the port-forwarding is started, run the following script to setup the geoserver instance:
```bash
./deployment-scripts/setup_geoserver.sh
```

Update `workspace/${DEPLOYMENT_ENV}/env/.env` with the Geoserver credentials.

```bash
# Geoserver credentials
geoserver_username=admin
geoserver_password=geoserver
```

## 6 Extra configuration

Now we will generate or load an API key and encryption key for the studio.  If these are not already present, they will be generated and written to the file `.studio-api-key`.  If the file already exists, those will be used.  *NB: this is important for redeploying a cluster which will reuse persisted data.*

```bash
file=./.studio-api-key
if [ -e "$file" ]; then
    echo "File exists"
    source $file
else 
    export STUDIO_API_KEY=$(echo "pak-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)")
    export API_ENCRYPTION_KEY=$(echo "$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')")
    echo "export STUDIO_API_KEY=$STUDIO_API_KEY" > ./.studio-api-key
    echo "export API_ENCRYPTION_KEY=$API_ENCRYPTION_KEY" >> ./.studio-api-key
fi
```

Update `workspace/${DEPLOYMENT_ENV}/env/.env`

```bash
# Studio api key
studio_api_key=$STUDIO_API_KEY

# Studio api encryption_key
studio_api_encryption_key=$API_ENCRYPTION_KEY

# Redis password
redis_password=devPassword

# imagePullSecret b64secret (if required)
image_pull_secret_b64=
```

Update `workspace/${DEPLOYMENT_ENV}/env/.env.sh`

```bash
# Environment vars
export ENVIRONMENT=local
export ROUTE_ENABLED=false

# storage config
export SHARE_PIPELINE_PVC=true
export STORAGE_PVC_ENABLED=true
export STORAGE_FILESYSTEM_ENABLED=true
export CREATE_TUNING_FOLDERS_FLAG=false

# switch off oauth config (optional)
export OAUTH_PROXY_ENABLED=false
export OAUTH_PROXY_PORT=4180
```

## 7. Deploy Geospatial Studio services

> Note:  Source the variables to export any newly added variables.
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

At this point, review `workspace/${DEPLOYMENT_ENV}/env/.env` and `workspace/${DEPLOYMENT_ENV}/env/env.sh` to ensure that you have collected all the needed environment variables and secrets. To generate values.yaml for `studio` and `studio-pipelines charts`, run the command below.

```bash
./deployment-scripts/values-file-generate.sh
```

This will generate two values files
* `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`
* `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values.yaml`

>If you get a permision error when auto-retrieving the cluster url, you need to manually enter the `CLUSTER_URL` in `workspace/$DEPLOYMENT_ENV/env/env.sh`.

It is recommended not to edit these values.yaml and instead create copies of them with names `values-deploy.yaml.`:

```bash
cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml

cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values-deploy.yaml
```

Now review the `values-deploy.yaml` files above. Explanation of each can be found in the file comments.  Once you have completed this you can use `helm` to deploy.  

<!-- Update `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml`

```yaml
# Essential services for local development
geofm-ui:
  # ... more configurations
  resources:
    ui:
    oauth:
  # ... more configurations

gfm-studio-gateway:
  # ... more configurations
  resources:
    api:
    oauth:
    celeryWorker:
    celeryFlower:
  securityContext:
    api:
      runAsUser: 1001
  extraEnvironment:
    api:
      PIPELINES_V2_INFERENCE_ROOT_FOLDER: "/data/"
  # ... more configurations

gfm-geoserver:
  # ... more configurations
  resources:
  persistence:
    pvc_type: "cluster"
    capacity: 20Gi
  # ... more configurations


# Optional services (disabled for minimal local setup)

gfm-mlflow:
  # ... more configurations
  resources:
  # ... more configurations
```


Update `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values-deploy.yaml`

```yaml
# Optional services (disabled for minimal local setup)
terrakit-data-fetch:
  enabled: false
  # ... more configurations

postprocess-generic:
  enabled: false
  # ... more configurations

sentinelhub-connector:
  enabled: false
  # ... more configurations

terratorch-inference:
  enabled: false
  # ... more configurations

run-inference:
  enabled: false
  # ... more configurations
``` -->

Now you need to pull dependecies for dependent charts. Also, in some instances you might need to delete `geospatial-studio/Chart.lock` file when there are conflicts.

```bash
helm dependency build ./geospatial-studio/
```

To see the helm template you can run the following command:
```bash
helm template -f workspace/$DEPLOYMENT_ENV/values/geospatial-studio/values-deploy.yaml studio ./geospatial-studio/ --debug > dryrun.yaml

helm template -f workspace/$DEPLOYMENT_ENV/values/geospatial-studio-pipelines/values-deploy.yaml studio ./geospatial-studio-pipelines/ --debug > dryrun.yaml
```

To begin deployment run the two commands to deploy studio core services and the pipelines.

```bash
./deployment-scripts/deploy_studio.sh

./deployment-scripts/deploy_pipelines.sh
```

If for any reason you need to uninstall the deployments you can use:
```bash
helm uninstall studio
helm uninstall studio-pipelines
```

<!-- To restart all pods, run
```bash
./deployment-scripts/restart-all-studio-pods.sh
``` -->



Following deployment, you will need to setup port-forwarding to access the different deployed services:
```bash
kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n default deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
```

| After deployment: | |
|---|---|
| Access the Studio UI | [https://localhost:4180](https://localhost:4180) |
| Access the Studio API | [https://localhost:4181](https://localhost:4181) |
| Authenticate Studio | username: `testuser` password: `testpass123` |
| Access Geoserver | [http://localhost:3000](http://localhost:3000) |
| Authenticate Geoserver | username: `admin` password: `geoserver` |
| Access Keycloak | [https://localhost:8080](https://localhost:8080) |
| Authenticate Keycloak | username: `admin` password: `admin` |
| Access MinIO | Console: [https://localhost:9001](https://localhost:9001)      API: [https://localhost:9000](https://localhost:9000) |
| Authenticate MinIO | username: `minioadmin` password: `minioadmin` |


<!-- ## Enable Permissions in Lima vm local directory


```bash
# ssh to studio vm
limactl shell studio
# chmod 777 to /data/studio-inference-pv directory
sudo chmod 777 -R /data/studio-inference-pv
``` -->

## 9. API Testing Guide

To test the APIs using the provided payloads, follow this guide. You'll need an API client like curl or [Insomnia](https://insomnia.rest/).

Check the API's Swagger Page: [https://localhost:4181]

### Authenticate with the API Key

The API requires an api-key or oauth-token for authentication. Use the default api-key used in your deployment flow to get started.

In your requests, you'll pass this key in a header: `-H "X-API-Key: $STUDIO_API_KEY"`

### Test Payload

Use the default data provided under `/tests/api-data/*.json` as the payloads to hit the endpoints.

***Sample POST requests:***

1. ADD a sandbox models resource

    ```bash
    curl -kX POST 'https://localhost:4181/v2/models' \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --data @tests/api-data/00-inf-models.json
    ```

2. SUBMIT a test inference

    ```bash
    curl -kX POST 'https://localhost:4181/v2/inference' \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --data @tests/api-data/01-inf-inferences.json
    ```

    Check the UI, inference lab history to check the onboarded inference

3. SUBMIT a test onboarding dataset

    ```bash
    curl -kX POST 'https://localhost:4181/v2/datasets/onboard' \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --data @tests/api-data/02-ft-datasets.json
    ```

4. SUBMIT a test onboarding finetuning base model

    ```bash
    curl -kX POST 'https://localhost:4181/v2/base-models' \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --data @tests/api-data/04-ft-base-models.json
    ```

3. SUBMIT a test onboarding finetuning template

    ```bash
    curl -kX POST 'https://localhost:4181/v2/tune-templates' \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $STUDIO_API_KEY" \
      --data @tests/api-data/03-ft-templates.json
    ```
