# Geospatial Studio - Deployment instructions

> Note: Strictly run all the scripts in this guide from the root directory of the [geospatial-studio repository](https://github.com/terrastackai/geospatial-studio).

**Deployment steps:**

1. [Cluster configuration](#1-cluster-configuration)
2. [Initialize environment variables](#2-initialize-environment-variables)
3. [Create and configure COS instance and buckets](#3-storage-setup)
4. [Create and configure DBs + tables](#4-database-preparation)
5. [Setup authenticator](#5-authenticator-setup)
6. [Geoserver setup](#6-geoserver-setup)
7. [External services (Optional)](#7-external-services-configuration)
8. [Extra configuration](#8-extra-configuration)
9. [Deploy Geospatial Studio services](#9-deploy-geospatial-studio-services)
10. [End-to-end tests](#10-testing)


## 1. Cluster configuration

### Initialization

Provide a name for the deployment environment, maybe cluster name e.g. fmaas-dev, cimf-staging, rosa-prod, local... This will be the name used for a local folder created under workspace directory.

```bash
export DEPLOYMENT_ENV=xxxx
```

Set up the kubectl context or login to openshift:
For OpenShift use the script below to login after supplying the token and server. These can be obtained from OpenShift console.
```shell
oc login --token=<cluster-token> --server=<cluster-server>
```

Set cluster namespace/project as an environment variable OC_PROJECT
```bash
export OC_PROJECT=xxxx
```

### Create deployment namespace [Admin]

```bash
./deployment-scripts/create-namespace.sh
```

### Create Deployer role for project [Admin]

Non-administrator users require elevated privileges to deploy the Geospatial Studio stack.  

Run the following once per project/namespace:
```bash
./deployment-scripts/admin-role-for-namespace.sh
```

Run the following for each existing non admin user in your cluster that you want to give studio deployer role:
```bash
export USER_TO_ADD=<email address>
./deployment-scripts/admin-role-for-user.sh
```

### Install GPU drivers [Admin][OpenShift]

These steps only need to be done once for the cluster

> Only users with cluster admin privileges can perform these steps.

#### 1. Verify or install operators and plugins
* _NVIDIA GPU Operator_ in `nvidia-gpu-operator` namespace, follow these instructions https://docs.nvidia.com/datacenter/cloud-native/openshift/24.9.0/install-gpu-ocp.html#
* _Node Feature Discovery_ in `openshift-nfd` namespace, follow these instructions https://docs.nvidia.com/datacenter/cloud-native/openshift/24.9.0/install-nfd.html


### Installing S3 compatible cloud object storage drivers for OpenShift [Admin]

These steps only need to be done once for the cluster

> Only users with cluster admin privileges can perform these steps.

#### 1. IBM Cloud Object Storage plug-in
Follow these instructions: https://cloud.ibm.com/docs/openshift?topic=openshift-storage_cos_install to install _IBM Cloud Object Storage_ in `ibm-object-s3fs` namespace.

This will provide storage classes that are S3 compatible and can connect to MinIO, AWS S3, IBM COS Object storage instances


## 2. Initialize environment variables

> Note:  If you are coming back to this step later, and you might be missing the environment variables exported in [initialization section](#initialization), ensure you re-export them again in your terminal.
```bash
export DEPLOYMENT_ENV=xxxx
export OC_PROJECT=xxxx
``` 

This step will create two env scripts under the workspace/${DEPLOYMENT_ENV}/env folder.  One script contains just the secret values template, and the other script contains all the other general Geospatial configuration.

```bash
./deployment-scripts/setup-workspace-env.sh
```

***Note*** Work through each env var in `workspace/${DEPLOYMENT_ENV}/env` and poplulate environment variables as required at this time or as you generate them in the subsequent steps.


## 3. Storage setup

> Note:  Source latest environment variables using the command below..
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

### Set up S3 compatible storage

The following storage options are supported:
- MinIO. A cluster-installed cloud object storage installation (Default)
- External cloud object storage service e.g. IBM Cloud Object Storage, AWS S3 etc

This section assumes you wish to use a cluster-installed instance of MinIO to provide S3-compatible object storage.

* Also at this point update `workspace/${DEPLOYMENT_ENV}/env/.env.sh` with...
  ```bash
  # Storage classes
  # Verify the available storage classes in your cluster and set the following env vars
  export COS_STORAGE_CLASS=
  export NON_COS_STORAGE_CLASS=
  ```

> Note:  Source the variables to export any newly added variables.
```bash
source workspace/$DEPLOYMENT_ENV/env/env.sh
```

### Set up S3 compatible storage

#### MinIO

Deploy MinIO for S3-compatible object storage:
```bash
# Install MinIO
python ./deployment-scripts/update-deployment-template.py --disable-pvc --filename deployment-scripts/minio-deployment.yaml --storageclass ${NON_COS_STORAGE_CLASS} | kubectl apply -f - -n ${OC_PROJECT}
kubectl wait --for=condition=ready pod -l app=minio -n ${OC_PROJECT} --timeout=300s
MINIO_API_URL="https://minio-api-$OC_PROJECT.$CLUSTER_URL"

# Update .env with the MinIO details for connection
sed -i -e "s/access_key_id=.*/access_key_id=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/secret_access_key=.*/secret_access_key=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s|endpoint=.*|endpoint=$MINIO_API_URL|g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/region=.*/region=us-east-1/g" workspace/${DEPLOYMENT_ENV}/env/.env
```


> Note:  This script should be run once only, if run before you should see the `deployment-scripts/.env` file

* Once the S3 instance has been created and .env updated, you can validate the credentials and endpoint in the `workspace/${DEPLOYMENT_ENV}/env/.env`

### Create the required buckets

Run the following script to create the buckets:

```bash
python deployment-scripts/create_buckets.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env
```

> NB: to update the list of buckets to create, currently you need to edit the list in the python script.

### Populate buckets with initial data

Run to populate the buckets with initial data (including the auxiliary data for post-processing)

```bash
./deployment-scripts/populate-buckets-with-auxiliary-data.sh
```

To check the logs for the job populating the data to the buckets, you can run

```bash
kubectl logs job/populate-buckets-job
```

> NB: this process might takes hours. You can continue with [database preparation](#4-database-preparation). You can also use the script below to check the contents of the ${BUCKET_INFERENCE_AUXDATA} bucket to ascertain completion. 

```bash
source workspace/$DEPLOYMENT_ENV/env/env.sh
python deployment-scripts/list_bucket_contents.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env --bkt "${BUCKET_INFERENCE_AUXDATA}"
```

## 4. Database preparation

> Note:  Source latest environment variables using the command below..
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

### Set up Postgresql instance

#### Setting up a Postgresql database instance in IBM Cloud

Follow these instructions: https://cloud.ibm.com/docs/databases-for-postgresql?topic=databases-for-postgresql-getting-started&interface=ui to provision an IBM Cloud Databases for PostgreSQL instance.

> Note: Ensure to allow public access to your database instance.

* Update `workspace/${DEPLOYMENT_ENV}/env/.env` with...
  ```bash
  pg_username=
  pg_password=
  pg_uri=
  pg_port=
  pg_original_db_name='ibmclouddb'
  ```

#### Setting up a Postgresql database instance in cluster

Add bitnami chart repository:

```bash
helm repo add bitnami  https://charts.bitnami.com/bitnami
helm repo update
```

Install postgres:

***Note*** If you have an instance of postgres already installed, following this guide to [uninstall](postgres-uninstall.md).

```bash
./deployment-scripts/install-postgres.sh UPDATE_STORAGE DISABLE_PV DO_NOT_SET_SCC
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
  pg_uri=postgresql.<OC_PROJECT>.svc.cluster.local
  ```

### Create databases

> Once you have created the postgresql instance, you will need to gather the instance url, the port, the username, password and initial database, put these in the `workspace/${DEPLOYMENT_ENV}/env/.env` file.

To create the required databases and users, run the script:

```bash
python deployment-scripts/create_studio_dbs.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env
```

## 5. Authenticator setup

> Note:  Source latest environment variables using the command below..
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

We use OAuth2 authenticator	for user authentication for the platform. This can be configured to use an external authenticator service, or could be deployed using the onboarded OpenShift authenticator or a service deployed on the cluster. At the moment our charts are configured to use IBM Security Verify `isv` and Keycloak `keycloak`.

### Installing and setup

#### 1. IBM Security Verify
Visit https://docs.verify.ibm.com/verify

* Once you setup the authenticator, update `workspace/${DEPLOYMENT_ENV}/env/.env.sh` with...
  ```bash
  # AUTH
  export OAUTH_TYPE=isv # for IBM Security Verify
  export OAUTH_CLIENT_ID=
  export OAUTH_ISSUER_URL=
  export OAUTH_URL=
  ```

  Generate cookie secret as below
  ```bash
  openssl rand -base64 32
  ```

* Also update `workspace/${DEPLOYMENT_ENV}/env/.env` with...
  ```bash
  # Oauth Credentials
  oauth_client_secret=
  oauth_cookie_secret=
  ```

#### 2. Keycloak

Deploy Keycloak for authentication:
```bash
python ./deployment-scripts/update-keycloak-deployment.py --filename deployment-scripts/keycloak-deployment.yaml --env-path workspace/${DEPLOYMENT_ENV}/env/.env | kubectl apply -f - -n ${OC_PROJECT}
```

Wait for Keycloak to be ready:
```bash
kubectl wait --for=condition=ready pod -l app=keycloak -n ${OC_PROJECT} --timeout=300s
```

#### Configure Keycloak Realm and Client

You can follow the following commands to auto configure
```bash
export client_secret=`cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32`
export cookie_secret=`cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32`

./deployment-scripts/setup-keycloak.sh

sed -i -e "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env

sed -i -e "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=$(printf "https://%s-%s.%s/realms/geostudio" "keycloak" "$OC_PROJECT" "$CLUSTER_URL")|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export OAUTH_URL=.*|export OAUTH_URL=$(printf "https://%s-%s.%s/realms/geostudio/protocol/openid-connect/auth" "keycloak" "$OC_PROJECT" "$CLUSTER_URL")|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=${OAUTH_PROXY_PORT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
```

Otherwise; if you have not run the above bash block you can follow the instructions below to create them manually through the Keycloak dashboard.

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

Update `workspace/${DEPLOYMENT_ENV}/env/.env.sh` with the following script

```bash
sed -i -e "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=$(printf "https://%s-%s.%s/realms/geostudio" "keycloak" "$OC_PROJECT" "$CLUSTER_URL")|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export OAUTH_URL=.*|export OAUTH_URL=$(printf "https://%s-%s.%s/realms/geostudio/protocol/openid-connect/auth" "keycloak" "$OC_PROJECT" "$CLUSTER_URL")|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
```

Once you setup the authenticator (with either method), validate `workspace/${DEPLOYMENT_ENV}/env/.env.sh`

## 6. Geoserver setup

To deploy Geoserver.  This will deploy geoserver, wait for the deployment to be completed and then start the required port-forwarding:
```bash
python ./deployment-scripts/update-deployment-template.py --disable-pvc --filename deployment-scripts/geoserver-deployment.yaml --storageclass ${NON_COS_STORAGE_CLASS} --proxy-base-url $(printf "https://%s-%s.%s/geoserver" "geofm-geoserver" "$OC_PROJECT" "$CLUSTER_URL") --geoserver-csrf-whitelist ${CLUSTER_URL} | kubectl apply -f - -n ${OC_PROJECT}

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gfm-geoserver -n ${OC_PROJECT} --timeout=900s

kubectl port-forward -n ${OC_PROJECT} svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
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

## 7. External services configuration

> Note:  Source latest environment variables using the command below..
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

The services listed below are optional and when subscribed have a cost implication. They make the studio more user friendly and give access to extra datasources, but the studio can run end to end without them.

#### 1. Mapbox
Visit https://account.mapbox.com/ to access your account or create a new account. Follow these instructions to create access token https://docs.mapbox.com/help/dive-deeper/access-tokens/. It is recommended that for the token created, you use the [url restrictions](https://docs.mapbox.com/help/dive-deeper/access-tokens/#url-restrictions) feature to secure your token and add the UI url which should be of the form 
```bash
https://geofm-ui-${CLUSTER_URL}
```

* Update `workspace/${DEPLOYMENT_ENV}/env/.env` with...
  ```bash
  # Mapbox credentials
  mapbox_token=
  ```

#### 2. Cesium
Visit https://ion.cesium.com/signin to access your account or create a new account and access token.
* Update `workspace/${DEPLOYMENT_ENV}/env/.env` with...
  ```bash
  # Cesium credentials
  cesium_token=
  ```

#### 3. Sentinel Hub
Visit https://www.sentinel-hub.com/ to access your account or create a new account and access token.
* Update `workspace/${DEPLOYMENT_ENV}/env/.env` with...
  ```bash
  # Sentinelhub credentials
  sh_client_id=
  sh_client_secret=
  ```

#### 4. Nasa Earth Data
Visit https://search.earthdata.nasa.gov/ to access your account or create a new account. Create access token.
* Update the token to `workspace/${DEPLOYMENT_ENV}/env/.env` with ...
  ```bash
  # Nasa Earth Data credentials
  nasa_earth_data_bearer_token=
  ```

## 8. Extra configuration

Update `workspace/${DEPLOYMENT_ENV}/env/.env`

* To generate the studio_api_key run:
  ```bash
  export STUDIO_API_KEY=$(echo "pak-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)")
  export API_ENCRYPTION_KEY=$(echo "$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')")
  ```

```bash
# Studio api key
studio_api_key=$STUDIO_API_KEY

# Studio api-key en
studio_api_encryption_key=$API_ENCRYPTION_KEY

# Redis password
redis_password=devPassword

# imagePullSecret b64secret
image_pull_secret_b64=
```

> Note: image_pull_secret_b64 to be provided if necessary


Update `workspace/${DEPLOYMENT_ENV}/env/env.sh`

Observability configuration for pipelines.
- Set true/false for OBSERVABILITY_ENABLED
```bash
# OBSERVABILITY
export OBSERVABILITY_ENABLED=true
export OBSERVABILITY_OTLP_ENDPOINT=
export OBSERVABILITY_OTLP_TRACES_ENDPOINT=
```

GPU Configuration for pipelines.
- Set true/false for CONFIGURE_GPU_AFFINITY used by terratorch inference deployment
- Supply the selector key and the node gpu spec
```bash
# GPU_CONFIG
export CONFIGURE_GPU_AFFINITY=true
export NODE_SELECTOR_KEY=nvidia.com/gpu.product
export NODE_GPU_SPEC=NVIDIA-A100-SXM4-80GB
```

If not deploying to an Openshift cluster, update the following,
# Environment vars
export ROUTE_ENABLED=false

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

## 9. Deploy Geospatial Studio services

> Note:  Source latest environment variables using the command below..
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

At this point, review `workspace/${DEPLOYMENT_ENV}/env/.env` and `workspace/${DEPLOYMENT_ENV}/env/env.sh` to ensure that you have collected all the needed environment variables and secrets. To generate values.yaml for `studio` and `studio-pipelines charts`, run the command below.
```bash
./deployment-scripts/values-file-generate.sh
```
This will generate two values files
* workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml
* workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values.yaml

It is recommended not to edit these values.yaml and instead create copies of them with names values-deploy.yaml.

To prepare for deployment, make a copy of the values.yaml file:

Copy for the studio
```bash
cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
```

Copy for the studio pipelines
```bash
cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values-deploy.yaml
```

Now review the `values-deploy.yaml` files above. Explanation of each can be found [here](deployment-values-details.md).  Once you have completed this you can use `helm` to deploy. If using OpenShift, ensure you are logged in to the cluster in the terminal (get the cli login link from the top right corner of the OpenShift dashboard, dropdown under your username). For Kubernetes, ensure the right context is set.

Once you are logged in, if this is the first time you are deploying the studio or have made changes to the charts, you need to pull dependecies for redis. Also in some instances you might need to delete `geospatial-studio/Chart.lock` file when there are conflicts.

```bash
helm dependency build ./geospatial-studio/
```

To see the helm template you can run the following command,
```bash
helm template -f workspace/$DEPLOYMENT_ENV/values/geospatial-studio/values-deploy.yaml studio ./geospatial-studio/ --debug > dryrun.yaml

helm template -f workspace/$DEPLOYMENT_ENV/values/geospatial-studio-pipelines/values-deploy.yaml studio ./geospatial-studio-pipelines/ --debug > dryrun.yaml
```

Then proceed to deploy with studio with,

```bash
./deployment-scripts/deploy_studio.sh
```

You can also deploy the pipelines with,
```bash
./deployment-scripts/deploy_pipelines.sh
```

To uninstall use
```bash
helm uninstall studio
helm uninstall studio-pipelines
```

To restart all pods, run
```bash
./deployment-scripts/restart-all-studio-pods.sh
```

## 10. Testing

> Note:  Source latest environment variables using the command below..
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

### Generate authentication API Key

Authentication to the Geospatial Studio is handled by a redirect in the UI, but for programmatic access (from the SDK, for example), the user will need to create an API key. This is can be easily done through the UI.

Run the command below to open the UI in your default browser;
```bash
ROUTE_URL=$(kubectl get route geofm-ui -o jsonpath='{"https://"}{.spec.host}') && \
echo "Opening $ROUTE_URL..." && \
(open $ROUTE_URL || xdg-open $ROUTE_URL || start $ROUTE_URL)
```

Authenticate the loaded UI in the browser and go to the Geospatial Studio UI page and navigate to the Manage your API keys link.

This should pop-up a window where you can generate, access and delete your api keys. NB: every user is limited to a maximum of two activate api keys at any one time. Copy your generated apikey to the bash command below and run it in terminal.

```bash
MY_GEOSTUDIO_KEY=
```

In your requests, you'll pass the key generated above in a header: `-H "X-API-Key: $MY_GEOSTUDIO_KEY"`

### Test Payload

Use the default data provided under `/tests/api-data/*.json` as the payloads to hit the endpoints.

***Sample POST requests:***

1. ADD a sandbox models resource

    ```bash
    curl -X POST "$ROUTE_URL/studio-gateway/v2/models" \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $MY_GEOSTUDIO_KEY" \
      --data @tests/api-data/00-models.json
    ```

3. SUBMIT a test inference

    ```bash
    curl -X POST "$ROUTE_URL/studio-gateway/v2/inference" \
      --header 'Content-Type: application/json' \
      --header "X-API-Key: $MY_GEOSTUDIO_KEY" \
      --data @tests/api-data/01-inferences.json
    ```

    Check the UI, inference lab history to check the onboarded inference