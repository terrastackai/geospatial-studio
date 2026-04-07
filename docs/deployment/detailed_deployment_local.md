# Local VM Cluster Setup

This guide provides detailed deployment instructions for a local cluster deployment in a VM.  This is only recommended for testing and development purposes.

Below we provide two different deployment options, which are similar during deployment, and mainly differ in initial setup.

* Lima VM
* Minikube
* OpenShift Local (formerly CodeReady Containers)

## Clone Repository

```bash
git clone https://github.com/IBM/geospatial-studio.git
cd geospatial-studio
```

## Install Python Dependencies

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## VM cluster initialisation
Here you need to follow the Lima VM *or* the Minikube  *or* the Openshift local(CRC) instructions.

### [Option 1] Lima VM setup

**Prerequisites**

* [Lima VM](https://lima-vm.io/docs/installation/) - v1.2.1 or later
* [Helm](https://helm.sh/docs/v3/) - v3.19 or later
* [OpenShift CLI](https://docs.okd.io/4.18/cli_reference/openshift_cli/getting-started-cli.html)
* Kubectl (bundled with above) 
* [jq](https://github.com/jqlang/jq) - json command-line processor
* [yq](https://github.com/mikefarah/yq) - yaml command-line processor
* Minimum 8GB RAM and 4 CPUs available for the VM (more recommended)

**VM cluster initialization**

1. Install [Lima VM](https://github.com/lima-vm/lima). Needs to be *v1.2.1* (not yet compatible with v2)

2. Start the Lima VM cluster:
```shell
limactl start --name=studio deployment-scripts/lima/studio.yaml
```

3. Set up the kubectl context (*NB: you will need to do this in each terminal prompt where you with to interact with the cluster, i.e. deploy, k9s*):
```shell
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
```

4. To monitor subsequent deployment on the cluster you can use a tool such as [k9s](https://k9scli.io).

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

### [Option 2] Minikube setup

**Prerequisites**

* Docker / Podman installed and running
* [Helm](https://helm.sh/docs/v3/) - v3.19 or later
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

### [Option 3] OpenShift Local setup (formerly CodeReady Containers)

**Prerequisites**
#### System Requirements
- **CPU**: 8+ cores (12+ recommended)
- **Memory**: 32GB RAM minimum (48GB recommended)
- **Disk**: 100GB free space minimum
- **OS**: Linux

#### Required Software
- [Red Hat OpenShift Local (CRC)](https://developers.redhat.com/products/openshift-local/overview)
- [oc CLI](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [Python 3.9+](https://www.python.org/downloads/)
- [jq](https://github.com/jqlang/jq) - json command-line processor
- [yq](https://github.com/mikefarah/yq) - yaml command-line processor

### CRC Cluster setup

```bash
# Download from https://developers.redhat.com/products/openshift-local/overview
# Or use package manager (macOS example):
brew install --cask openshift-local

# Verify installation
crc version

# Set up your host machine for CRC (one-time operation):
crc setup

# Start with recommended resources for geospatial workloads
crc start --cpus 8 --memory 32768 --disk-size 100

# Verify cluster is running
crc status

# Login to CRC
# Use the credentials from crc start output
eval $(crc oc-env)
oc login -u kubeadmin -p <kubeadmin_password> https://api.crc.testing:6443

# Access the OpenShift Container Platform web console with your default web browser.
crc console

# Alternatively, you can use a tool such as [k9s](https://k9scli.io).
k9s



# Useful commands:
# stop the instance
crc stop

# Remove previous cluster (if present)
crc delete

# view the password for the developer and kubeadmin users
crc console --credentials
```


## Geospatial Studio - Deployment instructions (automated)

For automated deployment in *Openshift local(CRC)* cluster, checkout [this documentation](crc_deployment.md).

Otherwise for automated deployment in *Lima VM*, run the script below and follow the steps thereafter:
```shell
./deploy_studio_lima.sh
```

*Deployment can take ~10 minutes (or longer) depending available download speed for container images.*

You can monitor the progress and debug using [`k9s`](https://k9scli.io) or similar tools.
```shell
export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
k9s
```

If you need to restart any of the port-forwards you can use the following commands:

Setup the environment variable
```bash
export OC_PROJECT=default
```
```shell
kubectl port-forward -n ${OC_PROJECT} svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/minio 9001:9001 >> studio-pf.log 2>&1 &
kubectl port-forward -n $OC_PROJECT svc/minio 9000:9000 >> studio-pf.log 2>&1 &
```

This is printed at the end of the installation script. In case you missed it and have issues with keycloak, Run this command to configure the `etc/hosts ` for seamless connection as some of the services may call the internal urls on the host machine.

```shell
echo -e \"127.0.0.1 keycloak.$OC_PROJECT.svc.cluster.local postgresql.$OC_PROJECT.svc.cluster.local minio.$OC_PROJECT.svc.cluster.local geofm-ui.$OC_PROJECT.svc.cluster.local geofm-gateway.$OC_PROJECT.svc.cluster.local geofm-geoserver.$OC_PROJECT.svc.cluster.local\" >> /etc/hosts

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
# or
export DEPLOYMENT_ENV=crc
```

```bash
export OC_PROJECT=default
```


```bash
export IMAGE_REGISTRY=geospatial-studio
```

This step will create two env scripts under the workspace/${DEPLOYMENT_ENV}/env folder.  One script contains just the secret values template, and the other script contains all the other general Geospatial configuration.

```bash
./deployment-scripts/setup-workspace-env.sh
```

Update the DEPLOYMENT_ENV, OC_PROJECT, CLUSTER_URL variables  in `workspace/${DEPLOYMENT_ENV}/env/env.sh` to be:
```bash
# deployment_env
DEPLOYMENT_ENV=lima
# or
DEPLOYMENT_ENV=minikube
# or
DEPLOYMENT_ENV=crc

# oc_project
OC_PROJECT=default

# cluster_url
# For OpenShift local:
export CLUSTER_URL='apps-crc.testing'

# Otherwise use:
export CLUSTER_URL=localhost

```

***Note*** Work through each env var in `workspace/${DEPLOYMENT_ENV}/env` and poplulate environment variables as required at this time or as you generate them in the subsequent steps.


Source the environment variables set:
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

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

#### For Openshift local(CRC):
```bash
# Label the CRC node with required topology labels:
oc label nodes crc topology.kubernetes.io/region=us-east --overwrite
oc label nodes crc topology.kubernetes.io/zone=us-east --overwrite
oc label nodes crc ibm-cloud.kubernetes.io/region=us-east --overwrite

# Add IBM Helm repository:
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update

# Fetch the IBM Object Storage Plugin:
helm fetch --untar ibm-helm/ibm-object-storage-plugin
# Make the plugin script executable
chmod +x ./ibm-object-storage-plugin/helm-ibmc/ibmc.sh
# Install Helm plugin
helm plugin install ./ibm-object-storage-plugin/helm-ibmc
# Install IBM Object Storage Plugin
helm ibmc install ibm-object-storage-plugin ibm-helm/ibm-object-storage-plugin \
    --set license=true \
    --set workerOS="redhat" \
    --set region="us-east"

# Wait for the plugin deployment to be ready:
kubectl wait --for=condition=available deployment/ibmcloud-object-storage-plugin \
    -n ibm-object-s3fs --timeout=300s

# Create a ConfigMap for OpenShift TLS certificates:   
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca-bundle
  namespace: ibm-object-s3fs
  annotations:
    service.beta.openshift.io/inject-cabundle: "true"
data: {}
EOF

# Mount the CA bundle to the plugin deployment:
oc set volume deployment/ibmcloud-object-storage-plugin \
    --add \
    --name=ca-bundle-vol \
    --type=configmap \
    --configmap-name=trusted-ca-bundle \
    --mount-path=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    --read-only=true \
    --sub-path=service-ca.crt \
    -n ibm-object-s3fs

# Verify the plugin is working:
# Check plugin pods
kubectl get pods -n ibm-object-s3fs

# Check storage class
kubectl get storageclass ibmc-s3fs-cos

# Wait for plugin to initialize
sleep 10

# Configure Storage Classes
# Set storage class environment variables
export COS_STORAGE_CLASS=ibmc-s3fs-cos
export NON_COS_STORAGE_CLASS=crc-csi-hostpath-provisioner
export PVC_ACCESS_MODE=ReadWriteOnce
# Update workspace env file
sed -i -e "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=${COS_STORAGE_CLASS}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=${NON_COS_STORAGE_CLASS}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

# Deploy MinIO:
# Generate MinIO deployment YAML
python ./deployment-scripts/update-deployment-template.py \
    --disable-pvc \
    --filename deployment-scripts/minio-deployment.yaml \
    --storageclass ${NON_COS_STORAGE_CLASS} \
    > workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml

# Apply MinIO deployment
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml -n ${OC_PROJECT}

# Wait for MinIO to be ready
kubectl wait --for=condition=ready pod -l app=minio -n ${OC_PROJECT} --timeout=300s
```

* Update MinIO Connection details:
  ```bash
  export MINIO_API_URL="https://minio-api-$OC_PROJECT.$CLUSTER_URL"
  # Update `workspace/${DEPLOYMENT_ENV}/env/.env` with MinIO details for external connection
  sed -i -e "s/access_key_id=.*/access_key_id=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
  sed -i -e "s/secret_access_key=.*/secret_access_key=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
  sed -i -e "s|endpoint=.*|endpoint=$MINIO_API_URL|g" workspace/${DEPLOYMENT_ENV}/env/.env
  sed -i -e "s/region=.*/region=us-east-1/g" workspace/${DEPLOYMENT_ENV}/env/.env
  ```

* Configure Host Modifier DaemonSet: This step ensures MinIO is accessible from within pods
  ```bash
  # Get MinIO cluster IP and internal URL
  export MINIO_CLUSTER_IP=$(oc get svc minio -n "${OC_PROJECT}" -o jsonpath='{.spec.clusterIP}')
  export MINIO_INTERNAL_URL="minio.${OC_PROJECT}.svc.cluster.local"
  export LOCAL_CA_CRT=$(oc get configmap trusted-ca-bundle -n ibm-object-s3fs -o jsonpath='{.data.service-ca\.crt}')

  # Generate hosts modifier DaemonSet
  cat deployment-scripts/crc-hosts-modifier-daemonset.yaml | \
      sed -e "s/\$MINIO_CLUSTER_IP/$MINIO_CLUSTER_IP/g" | \
      sed -e "s/\$MINIO_INTERNAL_URL/$MINIO_INTERNAL_URL/g" \
      > workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml

  # Use common function to inject CA certificate
  source ./common_functions.sh
  auto_indent_and_replace \
      workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml \
      SELF_CA_CRT \
      "$LOCAL_CA_CRT" \
      workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset.yaml

  # Apply DaemonSet
  oc apply -f workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset.yaml -n default

  # Clean up temporary file
  rm workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml
  ```


#### Otherwise, for Lima VM and Minikube:

```bash
### Install cloud object storage drivers in the cluster
# Ensure node has labels required by drivers
kubectl label nodes lima-studio topology.kubernetes.io/region=us-east-1 topology.kubernetes.io/zone=us-east-1a

# Install the drivers
cp -R deployment-scripts/ibm-object-csi-driver workspace/$DEPLOYMENT_ENV/initialisation
sed -e "s/default/$OC_PROJECT/g" deployment-scripts/template/cos-s3-csi-s3fs-sc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-s3fs-sc.yaml
sed -e "s/default/$OC_PROJECT/g" deployment-scripts/template/cos-s3-csi-sc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-sc.yaml
kubectl apply -k workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/

# Create TLS for MinIO
openssl genrsa -out minio-private.key 2048
mkdir -p workspace/$DEPLOYMENT_ENV/initialisation
sed -e "s/default/$OC_PROJECT/g" deployment-scripts/minio-openssl.conf > workspace/$DEPLOYMENT_ENV/initialisation/minio-user-openssl.conf
openssl req -new -x509 -nodes -days 730 -keyout minio-private.key -out minio-public.crt --config workspace/$DEPLOYMENT_ENV/initialisation/minio-user-openssl.conf

# Create TLS secret for MinIO
kubectl create secret tls minio-tls-secret --cert=minio-public.crt --key=minio-private.key -n ${OC_PROJECT} --dry-run=client -o yaml > workspace/$DEPLOYMENT_ENV/initialisation/minio-tls-secret.yaml
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-tls-secret.yaml -n ${OC_PROJECT}

# Create ConfigMap for CSI driver (required by IBM Object CSI Driver)
kubectl create configmap minio-public-config --from-file=minio-public.crt -n kube-system --dry-run=client -o yaml > workspace/$DEPLOYMENT_ENV/initialisation/minio-public-config.yaml
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-public-config.yaml -n kube-system

# Install MinIO
python ./deployment-scripts/update-deployment-template.py --disable-route --filename deployment-scripts/minio-deployment.yaml > workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml

# Apply MinIO deployment
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml -n ${OC_PROJECT}

# Wait for MinIO to be ready
kubectl wait --for=condition=ready pod -l app=minio -n ${OC_PROJECT} --timeout=300s

# Access MinIO Console:
# Port forward to access MinIO console at https://localhost:9001
kubectl port-forward -n ${OC_PROJECT} svc/minio-console 9001:9001 &
kubectl port-forward -n ${OC_PROJECT} svc/minio 9000:9000 &

# Login with username: `minioadmin`, password: `minioadmin`

# Also at this point update `workspace/${DEPLOYMENT_ENV}/env/.env.sh` with...
export COS_STORAGE_CLASS=cos-s3-csi-s3fs-sc
export NON_COS_STORAGE_CLASS=local-path

# Install the drivers
cp -R geospatial-studio/files/ibm-object-csi-driver workspace/$DEPLOYMENT_ENV/initialisation
sed -e "s/default/$OC_PROJECT/g" deployment-scripts/template/cos-s3-csi-s3fs-sc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-s3fs-sc.yaml
sed -e "s/default/$OC_PROJECT/g" deployment-scripts/template/cos-s3-csi-sc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-sc.yaml
kubectl apply -k workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/
```

* Once the S3 instance has been created, you can add the credentials and endpoint to the `workspace/${DEPLOYMENT_ENV}/env/.env` file as shown below.

  ```
  access_key_id=minioadmin
  secret_access_key=minioadmin
  endpoint=https://localhost:9000
  region=us-east
  ```

### Create the required buckets
Source the environment variables:

```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

Create required S3 buckets
```bash
python deployment-scripts/create_buckets.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env
```

> NB: to update the list of buckets to create, currently you need to edit the list in the python script.


Once you create the buckets update the minio endpoint `workspace/${DEPLOYMENT_ENV}/env/.env` with

```
endpoint=https://minio.$OC_PROJECT.svc.cluster.local:9000
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
# Export postgres password
export POSTGRES_PASSWORD=devPostgresql123

# For OpenShift local(CRC):
./deployment-scripts/install-postgres.sh UPDATE_STORAGE DISABLE_PV

# For Lima/Minikube:
./deployment-scripts/install-postgres.sh
```

Wait for Postgresql to be ready:
```bash
kubectl wait --for=condition=ready pod/postgresql-0 -n ${OC_PROJECT} --timeout=300s
```

Once completed, in terminal you will find some notes on the created postgres database. To prepare for the [create databases](#create-databases) section below, follow these steps..

* To connect to your database from outside the cluster for [create databases](#create-databases) section below execute the following commands:

***Note*** change host port from default 54320 in the command below if the value of `pg_forwarded_port` was changed in `workspace/${DEPLOYMENT_ENV}/env/.env`

  ```bash
  kubectl port-forward --namespace ${OC_PROJECT} svc/postgresql 54320:5432 &
  PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 54320
  ```

* Update `workspace/${DEPLOYMENT_ENV}/env/.env` with...
  ```bash
  pg_username=postgres
  pg_password=$POSTGRES_PASSWORD
  pg_uri=127.0.0.1
  pg_port=5432
  pg_original_db_name='postgres'
  ```

### Create databases

> Once you have created the postgresql instance, you will need to gather the instance url, the port, the username, password and initial database, put these in the `workspace/${DEPLOYMENT_ENV}/env/.env` file.

To create the required databases and users, run the script:

```bash
python deployment-scripts/create_studio_dbs.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env
```

Once you create the databases update the pg_uri in `workspace/${DEPLOYMENT_ENV}/env/.env` with

```
pg_uri=postgresql.${OC_PROJECT}.svc.cluster.local
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
# For Openshift local(CRC):
python ./deployment-scripts/update-keycloak-deployment.py --filename deployment-scripts/keycloak-deployment.yaml --env-path workspace/${DEPLOYMENT_ENV}/env/.env > workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml



# Otherwise use:
python ./deployment-scripts/update-keycloak-deployment.py --disable-route --filename deployment-scripts/keycloak-deployment.yaml --env-path workspace/${DEPLOYMENT_ENV}/env/.env > workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml



kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml -n ${OC_PROJECT}
```

Wait for Keycloak to be ready:
```bash
kubectl wait --for=condition=ready pod -l app=keycloak -n ${OC_PROJECT} --timeout=300s
```
Setup Port Forwarding for Keycloak
```bash
kubectl port-forward -n ${OC_PROJECT} svc/keycloak 8080:8080 &
sleep 5
```

#### Configure Keycloak Realm and Client
You can either use the `deployment-scripts/setup-keycloak.sh` script to create the realm, client and test user, or you can follow the instructions below to create them manually through the Keycloak dashboard.

```bash
# Generate client secret and cookie secret
export client_secret=$(cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32)
export cookie_secret=$(cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32)

# Run the automated script
./deployment-scripts/setup-keycloak.sh
```

OR configure keycloak manually:

---
1. **Access Keycloak Admin Console**:
   ```bash
   # Port forward to access Keycloak at http://localhost:8080
   kubectl port-forward -n ${OC_PROJECT} svc/keycloak 8080:8080 &
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
     https://geofm-ui.$OC_PROJECT.svc.cluster.local:4180/oauth2/callback
     https://geofm-gateway.$OC_PROJECT.svc.cluster.local:4180/oauth2/callback
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

Once you setup the authenticator (with either method), update `workspace/${DEPLOYMENT_ENV}/env/env.sh` with...
```bash
# AUTH
export OAUTH_TYPE=keycloak # for Keycloak
export OAUTH_CLIENT_ID=geostudio-client
export OAUTH_ISSUER_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio
# For Openshift local(crc):
export OAUTH_URL=https://keycloak-$OC_PROJECT.$CLUSTER_URL/realms/geostudio/protocol/openid-connect/auth
# Otherwise use:
export OAUTH_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio/protocol/openid-connect/auth
```

For a kubernetes environment create a tls secret key and crt pair.
```bash
# create tls.key and tls.crt

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=$OC_PROJECT.svc.cluster.local"

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

echo -e "\n#Studio\n127.0.0.1 keycloak.$OC_PROJECT.svc.cluster.local postgresql.$OC_PROJECT.svc.cluster.local minio.$OC_PROJECT.svc.cluster.local geofm-ui.$OC_PROJECT.svc.cluster.local geofm-gateway.$OC_PROJECT.svc.cluster.local" >> /etc/hosts
```

## 5. Geoserver setup
This will deploy geoserver, wait for the deployment to be completed and then start the required port-forwarding:

For Openshift Local(CRC):
```bash
# Set Geoserver Credentials
export GEOSERVER_USERNAME="admin"
export GEOSERVER_PASSWORD="geoserver"
export GEOSERVER_URL="https://geofm-geoserver-$OC_PROJECT.$CLUSTER_URL/geoserver"

# Configure SCC for Geoserver
oc adm policy add-scc-to-user anyuid -n ${OC_PROJECT} -z default

# Generate Geoserver deployment YAML
python ./deployment-scripts/update-deployment-template.py \
    --disable-pvc \
    --filename deployment-scripts/geoserver-deployment.yaml \
    --storageclass ${NON_COS_STORAGE_CLASS} \
    --proxy-base-url $(printf "https://%s-%s.%s/geoserver" "geofm-geoserver" "$OC_PROJECT" "$CLUSTER_URL") \
    --geoserver-csrf-whitelist ${CLUSTER_URL} \
    > workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml

# Apply Geoserver deployment
kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n ${OC_PROJECT}
```

For Lima and minikube:

```bash
export GEOSERVER_URL=http://localhost:3000/geoserver

python ./deployment-scripts/update-deployment-template.py --filename deployment-scripts/geoserver-deployment.yaml --proxy-base-url $(printf "http://geofm-geoserver-%s.svc.cluster.local:3000/geoserver" "$OC_PROJECT") --disable-route > workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml

kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n ${OC_PROJECT}

```

Wait for Geoserver to be ready:
```bash
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

Update `workspace/${DEPLOYMENT_ENV}/env/env.sh`

```bash
# Environment vars
export ENVIRONMENT=local # set to 'crc' for Openshift Local(CRC)
export ROUTE_ENABLED=false # set to true for Openshift Local(CRC)

# storage config
export SHARE_PIPELINE_PVC=true # set to false for Openshift Local(CRC)
export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=

# switch off oauth config (optional)
export OAUTH_PROXY_ENABLED=false # set to true for Openshift Local(CRC)
export OAUTH_PROXY_PORT=4180 # set to 8443 for Openshift Local(CRC)
```

Set image Registry
```bash
export IMAGE_REGISTRY=geospatial-studio
sed -i -e "s/export CONTAINER_IMAGE_REPOSITORY=.*/export CONTAINER_IMAGE_REPOSITORY=${IMAGE_REGISTRY}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
```

## 7. Deploy Geospatial Studio services

> Note:  Source the variables to export any newly added variables.
```bash
source workspace/${DEPLOYMENT_ENV}/env/env.sh
```

At this point, review `workspace/${DEPLOYMENT_ENV}/env/.env` and `workspace/${DEPLOYMENT_ENV}/env/env.sh` to ensure that you have collected all the needed environment variables and secrets. 

Validate all mandatory environment variables are defined:
```bash
python deployment-scripts/validate-env-files.py \
    --env-file workspace/${DEPLOYMENT_ENV}/env/.env \
    --env-variables "deployment_name,ocp_project,studio_api_key,studio_api_encryption_key,access_key_id,secret_access_key,endpoint,region,pg_username,pg_password,pg_uri,pg_port,pg_original_db_name,pg_studio_db_name,geoserver_username,geoserver_password,oauth_client_secret,oauth_cookie_secret,redis_password,image_pull_secret_b64" \
    --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh \
    --env-sh-variables "DEPLOYMENT_ENV,OC_PROJECT,ROUTE_ENABLED,CONTAINER_IMAGE_REPOSITORY,CLUSTER_URL,COS_STORAGE_CLASS,PVC_ACCESS_MODE,NON_COS_STORAGE_CLASS,OAUTH_PROXY_ENABLED,OAUTH_PROXY_PORT,OAUTH_TYPE,OAUTH_CLIENT_ID,OAUTH_ISSUER_URL,OAUTH_URL"
```


To generate values.yaml for `studio` charts, run the command below.

```bash
./deployment-scripts/values-file-generate.sh
```

This will generate two values files
* `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml`

>If you get a permision error when auto-retrieving the cluster url, you need to manually enter the `CLUSTER_URL` in `workspace/$DEPLOYMENT_ENV/env/env.sh`.

It is recommended not to edit these values.yaml and instead create copies of them with names `values-deploy.yaml.`:

```bash
cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
```

Now review the `values-deploy.yaml` files above. Explanation of each can be found in the file comments.  Once you have completed this you can use `helm` to deploy.  

Update `workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml`

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
```

Configure GPU Settings
```bash
# For CRC without GPU:
python ./deployment-scripts/remove-pipeline-gpu.py \
    workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml

# For CRC with GPU(remove affinity only):
python ./deployment-scripts/remove-pipeline-gpu.py --remove-affinity-only \
    workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
```

Now you need to pull dependecies for dependent charts. Also, in some instances you might need to delete `geospatial-studio/Chart.lock` file when there are conflicts.

```bash
helm dep update ./geospatial-studio/
helm dependency build ./geospatial-studio/
```

To see the helm template you can run the following command:
```bash
helm template -f workspace/$DEPLOYMENT_ENV/values/geospatial-studio/values-deploy.yaml studio ./geospatial-studio/ --debug > dryrun.yaml
```

To begin deployment run the command below to deploy studio core services and the pipelines.

```bash
./deployment-scripts/deploy_studio.sh
```

If for any reason you need to uninstall the deployments you can use:
```bash
helm uninstall studio
```

<!-- To restart all pods, run
```bash
./deployment-scripts/restart-all-studio-pods.sh




Following deployment, you will need to setup port-forwarding to access the different deployed services:
```bash
kubectl port-forward -n ${OC_PROJECT} svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward -n ${OC_PROJECT} deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &
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
