#!/bin/zsh

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


# Paste your image pull secret below
## This is a dummy image pull secret
## {"auths":{"example.io":{"username":"example","password":"example","email":"example@example.com","auth":"ZXhhbXBsZTpleGFtcGxl"}}}
## base64 encoded
export STUDIO_IMAGE_PULL_SECRET="eyJhdXRocyI6eyJleGFtcGxlLmlvIjp7InVzZXJuYW1lIjoiZXhhbXBsZSIsInBhc3N3b3JkIjoiZXhhbXBsZSIsImVtYWlsIjoiZXhhbXBsZUBleGFtcGxlLmNvbSIsImF1dGgiOiJaWGhoYlhCc1pUcGxlR0Z0Y0d4bCJ9fX0="
export GEOSERVER_USERNAME="admin"
export GEOSERVER_PASSWORD="geoserver"

export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"

echo "----------------------------------------------------------------------"
echo "------  Creating baseline deployment/values files  -------------------"
echo "----------------------------------------------------------------------"

# Set environment variables and source setup script
export DEPLOYMENT_ENV=lima
export OC_PROJECT=default
export IMAGE_REGISTRY=geospatial-studio
./deployment-scripts/setup-workspace-env.sh

sed -i -e "s/export CLUSTER_URL=.*/export CLUSTER_URL=localhost/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export DEPLOYMENT_ENV=.*/export DEPLOYMENT_ENV=lima/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OC_PROJECT=.*/export OC_PROJECT=default/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

source workspace/${DEPLOYMENT_ENV}/env/env.sh

echo "----------------------------------------------------------------------"
echo "--------------------  Add labels to node  ------------------"
echo "----------------------------------------------------------------------"

kubectl label nodes lima-studio topology.kubernetes.io/region=us-east-1 topology.kubernetes.io/zone=us-east-1a

# echo "----------------------------------------------------------------------"
# echo "--------------------  Create local Storage Classes  ------------------"
# echo "----------------------------------------------------------------------"

# kubectl apply -f deployment-scripts/create_local_storage_class.yaml -n ${OC_PROJECT}

echo "----------------------------------------------------------------------"
echo "----------------------  Deploying Minio  -----------------------------"
echo "----------------------------------------------------------------------"

# Install MinIO
# Create TLS for minio
openssl genrsa -out minio-private.key 2048
openssl req -new -x509 -nodes -days 730 -keyout minio-private.key -out minio-public.crt --config deployment-scripts/minio-openssl.conf

kubectl create secret tls minio-tls-secret --cert=minio-public.crt --key=minio-private.key -n ${OC_PROJECT}
kubectl create configmap minio-public-config --from-file=minio-public.crt -n kube-system
python ./deployment-scripts/update-deployment-template.py --disable-route --filename deployment-scripts/minio-deployment.yaml | kubectl apply -f - -n ${OC_PROJECT}
kubectl wait --for=condition=ready pod -l app=minio -n ${OC_PROJECT} --timeout=300s

sleep 5
kubectl port-forward -n ${OC_PROJECT} svc/minio 9001:9001 >> studio-pf.log 2>&1 &
sleep 5

kubectl apply -k deployment-scripts/ibm-object-csi-driver/

kubectl wait --for=condition=ready pod -l app=cos-s3-csi-controller -n kube-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=cos-s3-csi-driver -n kube-system --timeout=300s


# # # Update .env with the MinIO details for local connection
sed -i -e "s/access_key_id=.*/access_key_id=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/secret_access_key=.*/secret_access_key=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s|endpoint=.*|endpoint=https://localhost:9000|g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/region=.*/region=us-east-1/g" workspace/${DEPLOYMENT_ENV}/env/.env

## Setup storage class for minio and default in cluster storage class
sed -i -e "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=cos-s3-csi-s3fs-sc/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=local-path/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

kubectl port-forward -n default svc/minio 9000:9000 >> studio-pf.log 2>&1 &
sleep 5

python deployment-scripts/create_buckets.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env

sed -i -e "s|endpoint=.*|endpoint=https://minio.default.svc.cluster.local:9000|g" workspace/${DEPLOYMENT_ENV}/env/.env

source workspace/${DEPLOYMENT_ENV}/env/env.sh


echo "----------------------------------------------------------------------"
echo "--------------------  Deploying Postgres  ----------------------------"
echo "----------------------------------------------------------------------"

# Install Postgres
helm repo add bitnami  https://charts.bitnami.com/bitnami
helm repo update

export POSTGRES_PASSWORD=devPostgresql123

./deployment-scripts/install-postgres.sh

kubectl wait --for=condition=ready pod/postgresql-0 -n ${OC_PROJECT} --timeout=300s

# export POSTGRES_PASSWORD=$(kubectl get secret --namespace ${OC_PROJECT} postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

kubectl port-forward --namespace ${OC_PROJECT} svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
sleep 5

# Update .env with the Postgres details for local connection
sed -i -e "s/pg_username=.*/pg_username=postgres/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/pg_password=.*/pg_password=${POSTGRES_PASSWORD}/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/pg_uri=.*/pg_uri=127.0.0.1/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/pg_port=.*/pg_port=5432/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/pg_original_db_name=.*/pg_original_db_name='postgres'/g" workspace/${DEPLOYMENT_ENV}/env/.env

python deployment-scripts/create_studio_dbs.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env

sed -i -e "s/pg_uri=.*/pg_uri=postgresql.default.svc.cluster.local/g" workspace/${DEPLOYMENT_ENV}/env/.env

source workspace/${DEPLOYMENT_ENV}/env/env.sh

echo "----------------------------------------------------------------------"
echo "--------------------  Deploying Keycloak  ----------------------------"
echo "----------------------------------------------------------------------"

python ./deployment-scripts/update-keycloak-deployment.py --disable-route --filename deployment-scripts/keycloak-deployment.yaml --env-path workspace/${DEPLOYMENT_ENV}/env/.env | kubectl apply -f - -n ${OC_PROJECT}

kubectl wait --for=condition=ready pod -l app=keycloak -n default --timeout=300s

kubectl port-forward -n default svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
sleep 5

# Keycloak setup
export client_secret=`cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32`
export cookie_secret=`cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32`

./deployment-scripts/setup-keycloak.sh

# sed -i -e "s/oauth_client_secret=.*/oauth_client_secret=$client_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env

sed -i -e "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=http://keycloak.default.svc.cluster.local:8080/realms/geostudio|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export OAUTH_URL=.*|export OAUTH_URL=http://keycloak.default.svc.cluster.local:8080/realms/geostudio/protocol/openid-connect/auth|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g" workspace/${DEPLOYMENT_ENV}/env/env.sh


echo "----------------------------------------------------------------------"
echo "--------------------  Updating other values  -------------------------"
echo "----------------------------------------------------------------------"
# Kubernetes tls secret setup
# create tls.key and tls.crt
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=default.svc.cluster.local"

# extract the cert and key into env vars

export TLS_CRT_B64=$(openssl base64 -in tls.crt -A)
export TLS_KEY_B64=$(openssl base64 -in tls.key -A)

sed -i -e "s/tls_crt_b64=.*/tls_crt_b64=$TLS_CRT_B64/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/tls_key_b64=.*/tls_key_b64=$TLS_KEY_B64/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/export CREATE_TLS_SECRET=.*/export CREATE_TLS_SECRET=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

# Geoserver setup

export GEOSERVER_URL=http://localhost:3000/geoserver

sed -i -e "s/geoserver_username=.*/geoserver_username=$GEOSERVER_USERNAME/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/geoserver_password=.*/geoserver_password=$GEOSERVER_PASSWORD/g" workspace/${DEPLOYMENT_ENV}/env/.env

echo "----------------------------------------------------------------------"
echo "--------------------  Deploying Geoserver  ----------------------------"
echo "----------------------------------------------------------------------"

python ./deployment-scripts/update-deployment-template.py --filename deployment-scripts/geoserver-deployment.yaml --disable-route | kubectl apply -f - -n ${OC_PROJECT}

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gfm-geoserver -n default --timeout=900s

kubectl port-forward -n default svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
sleep 5

echo "----------------------------------------------------------------------"
echo "--------------------  Configuring Geoserver  ----------------------------"
echo "----------------------------------------------------------------------"
./deployment-scripts/setup_geoserver.sh

# Additional setup

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

# export STUDIO_API_KEY=$(echo "pak-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)")
# export API_ENCRYPTION_KEY=$(echo "$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')")

sed -i -e "s/studio_api_key=.*/studio_api_key=$STUDIO_API_KEY/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/studio_api_encryption_key=.*/studio_api_encryption_key=$API_ENCRYPTION_KEY/g" workspace/${DEPLOYMENT_ENV}/env/.env


sed -i -e "s/redis_password=.*/redis_password=devPassword/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/image_pull_secret_b64=.*/image_pull_secret_b64=\"${STUDIO_IMAGE_PULL_SECRET}\"/g" workspace/${DEPLOYMENT_ENV}/env/.env

sed -i -e "s/export ENVIRONMENT=.*/export ENVIRONMENT=local/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export ROUTE_ENABLED=.*/export ROUTE_ENABLED=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export SHARE_PIPELINE_PVC=.*/export SHARE_PIPELINE_PVC=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export STORAGE_PVC_ENABLED=.*/export STORAGE_PVC_ENABLED=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export STORAGE_FILESYSTEM_ENABLED=.*/export STORAGE_FILESYSTEM_ENABLED=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export CREATE_TUNING_FOLDERS_FLAG=.*/export CREATE_TUNING_FOLDERS_FLAG=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=.*|export PIPELINES_V2_INFERENCE_ROOT_FOLDER_VALUE=/data|g" workspace/${DEPLOYMENT_ENV}/env/env.sh

sed -i -e "s/export OAUTH_PROXY_ENABLED=.*/export OAUTH_PROXY_ENABLED=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

sed -i -e "s/export CONTAINER_IMAGE_REPOSITORY=.*/export CONTAINER_IMAGE_REPOSITORY=${IMAGE_REGISTRY}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

source workspace/${DEPLOYMENT_ENV}/env/env.sh

echo "----------------------------------------------------------------------"
echo "----------------  Generating deployment scripts  ---------------------"
echo "----------------------------------------------------------------------"

# Create deployment values files
./deployment-scripts/values-file-generate.sh

cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values-deploy.yaml

# The line below removes GPUs from the pipeline components, to leave GPUs activated, copy out this line
python ./deployment-scripts/remove-pipeline-gpu.py workspace/${DEPLOYMENT_ENV}/values/geospatial-studio-pipelines/values-deploy.yaml

echo "**********************************************************************"
echo "**********************************************************************"
echo "-----------  Make any changes to deployment values yaml --------------"
echo "**********************************************************************"
echo "**********************************************************************"

printf "%s " "Press enter to continue"
read ans


echo "----------------------------------------------------------------------"
echo "----------------  Building Helm dependencies  ------------------------"
echo "----------------------------------------------------------------------"

# Build Helm dependencies
helm dep update ./geospatial-studio/
helm dependency build ./geospatial-studio/

echo "----------------------------------------------------------------------"
echo "--------------------  Deploying the Studio  --------------------------"
echo "----------------------------------------------------------------------"

# Deploy Geospatial Studio
./deployment-scripts/deploy_studio.sh

echo "----------------------------------------------------------------------"
echo "-------------  Deploying the Studio Pipelines  -----------------------"
echo "----------------------------------------------------------------------"

# Deploy Geospatial Studio Pipelines
./deployment-scripts/deploy_pipelines.sh

echo "----------------------------------------------------------------------"
echo "---------  Set up Port Forwarding for UI and API  --------------------"
echo "----------------------------------------------------------------------"

kubectl wait --for=condition=ready pod -l app=geofm-gateway -n default --timeout=300s

kubectl port-forward deployment/geofm-ui 4180:4180 >> studio-pf.log 2>&1 &
kubectl port-forward deployment/geofm-gateway 4181:4180 >> studio-pf.log 2>&1 &
kubectl port-forward deployment/geofm-mlflow 5000:5000 >> studio-pf.log 2>&1 &

echo "----------------------------------------------------------------------"
echo "-----------------------  Deployment summary  -------------------------"
echo "----------------------------------------------------------------------"

printf "\n\U1F30D\U1F30E\U1F30F   Geospatial Studio deployed to Lima VM! \n"
printf "\U1F5FA   Access the Geospatial Studio UI at: https://localhost:4180\n"
printf "\U1F4BB   Access the Geospatial Studio API at: https://localhost:4181\n"
printf "K8S \U2388   To access the k8s cluster dashboard, run: minikube dashboard\n\n"

CONFIGURE_HOSTS_CMD="echo -e \"127.0.0.1 keycloak.default.svc.cluster.local postgresql.default.svc.cluster.local minio.default.svc.cluster.local geofm-ui.default.svc.cluster.local geofm-gateway.default.svc.cluster.local geofm-geoserver.default.svc.cluster.local\" >> /etc/hosts"
printf "\U1F4E1 Configure your etc hosts with the local urls:\n"
printf "Add our internal cluster urls to etc hosts for seamless connectivity since some of the services may call these internal urls on host machine \n"
printf "Use: %s\n\n" "$CONFIGURE_HOSTS_CMD"

printf "Dev Studio API Key: %s\n" $STUDIO_API_KEY
printf "Dev Postgres Password: %s\n\n" $POSTGRES_PASSWORD

echo "----------------------------------------------------------------------"
echo "----------------------------------------------------------------------"
echo "----------------------------------------------------------------------"
