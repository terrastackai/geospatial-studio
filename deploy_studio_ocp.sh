#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


echo "----------------------------------------------------------------------"
echo "----------------------  Confirm OpenShift  ---------------------------"
echo "----------------------------------------------------------------------"

IS_OPENSHIFT="false"

if kubectl get routes.route.openshift.io --ignore-not-found -o name &> /dev/null; then
    IS_OPENSHIFT="true"
fi

printf "\n\n--- Is this cluster openshift? $IS_OPENSHIFT ---\n"


# Functions

# Source (import) common_functions.sh
source ./common_functions.sh

export KUBECTL_WAIT_RETRY_ATTEMPTS=5
export KUBECTL_WAIT_RETRY_DELAY=5

# get cluster
set_cluster_url() {
    local oc_url_command_output
    oc_url_command_output=$(eval "kubectl get IngressController default -n openshift-ingress-operator -o jsonpath='{ .status.domain}'" 2>/dev/null)
    local oc_url_command_status=$?
    if [[ $oc_url_command_status -eq 0 && -n "$oc_url_command_output" ]]; then
        export CLUSTER_URL="$oc_url_command_output"
        echo "CLUSTER_URL obtained from kubectl"
    else
        typeset cluster_url
        get_user_input "Enter Cluster Url. For OpenShift, it is easy to identify the CLUSTER_URL from the console ui, it is the part of the console url between https://console-openshift-console.<CLUSTER_URL>/ " cluster_url
        echo "CLUSTER_URL accepted: **$cluster_url**"
        export CLUSTER_URL=$cluster_url
    fi
}

echo "----------------------------------------------------------------------"
echo "------  Generating baseline environment variables  -------------------"
echo "----------------------------------------------------------------------"

# Set environment variables and source setup script
# 1. DEPLOYMENT_ENV
typeset deployment_env
get_user_input "Provide a name for the deployment environment, maybe cluster name e.g. fmaas-dev, cimf-staging, rosa-prod, local... This will be the name used for a local folder created under workspace directory." deployment_env
echo "DEPLOYMENT_ENV accepted: **$deployment_env**"
export DEPLOYMENT_ENV=$deployment_env
JUMP_TO_DEPLOYMENT="No"

# Check if the workspace file exists and if it does not request user for namespace
if [ ! -f "workspace/${DEPLOYMENT_ENV}/env/env.sh" ]; then
    typeset namespace
    get_user_input "Provide the namespace/project name: " namespace
    echo "OC_PROJECT accepted: **$namespace**"
    export OC_PROJECT=$namespace
else
    jump_to_deployment_options="Yes No"
    typeset jump_to_deployment

    # Call the function
    get_menu_selection \
        "Jump to Deployment? Select 'YES' to jump to deployment (this assumes you have defined all the environment variables and deployed Oauth, Database, Storage and Geoserver), select 'NO' to set/reset environment variables and/or update Oauth, Database, Storage and Geoserver deployments  " \
        jump_to_deployment \
        "$jump_to_deployment_options"

    JUMP_TO_DEPLOYMENT=$jump_to_deployment
    source workspace/${DEPLOYMENT_ENV}/env/env.sh
fi

# Component selection for deployment/redeployment
echo "----------------------------------------------------------------------"
echo "---------------  Select Components to Deploy  ------------------------"
echo "----------------------------------------------------------------------"

# Default: deploy all components
DEPLOY_MINIO="Deploy"
DEPLOY_POSTGRES="Deploy"
DEPLOY_KEYCLOAK="Deploy"
DEPLOY_GEOSERVER="Deploy"
DEPLOY_STUDIO="Deploy"

# Check if this is a re-run or jump to deployment (check for existing deployments)
if [[ "$JUMP_TO_DEPLOYMENT" == "Yes" ]] || \
   kubectl get deployment minio -n ${OC_PROJECT} &> /dev/null || \
   kubectl get statefulset postgresql -n ${OC_PROJECT} &> /dev/null || \
   kubectl get deployment keycloak -n ${OC_PROJECT} &> /dev/null || \
   kubectl get deployment geofm-geoserver -n ${OC_PROJECT} &> /dev/null; then
    
    echo "Existing deployment(s) detected or jumping to deployment."
    echo "Select components to deploy/redeploy:"
    echo ""
    
    # MinIO selection
    if kubectl get deployment minio -n ${OC_PROJECT} &> /dev/null; then
        echo "⚠️  MinIO deployment already exists"
    fi
    minio_options="Deploy Skip"
    typeset deploy_minio_choice
    get_menu_selection \
        "Deploy/Redeploy MinIO (object storage)?" \
        deploy_minio_choice \
        "$minio_options"
    DEPLOY_MINIO=$deploy_minio_choice
    
    # PostgreSQL selection
    if kubectl get statefulset postgresql -n ${OC_PROJECT} &> /dev/null; then
        echo "⚠️  PostgreSQL deployment already exists"
    fi
    postgres_options="Deploy Skip"
    typeset deploy_postgres_choice
    get_menu_selection \
        "Deploy/Redeploy PostgreSQL (database)?" \
        deploy_postgres_choice \
        "$postgres_options"
    DEPLOY_POSTGRES=$deploy_postgres_choice
    
    # Keycloak selection
    if kubectl get deployment keycloak -n ${OC_PROJECT} &> /dev/null; then
        echo "⚠️  Keycloak deployment already exists"
    fi
    keycloak_options="Deploy Skip"
    typeset deploy_keycloak_choice
    get_menu_selection \
        "Deploy/Redeploy Keycloak (authentication)?" \
        deploy_keycloak_choice \
        "$keycloak_options"
    DEPLOY_KEYCLOAK=$deploy_keycloak_choice
    
    # GeoServer selection
    if kubectl get deployment geofm-geoserver -n ${OC_PROJECT} &> /dev/null; then
        echo "⚠️  GeoServer deployment already exists"
    fi
    geoserver_options="Deploy Skip"
    typeset deploy_geoserver_choice
    get_menu_selection \
        "Deploy/Redeploy GeoServer?" \
        deploy_geoserver_choice \
        "$geoserver_options"
    DEPLOY_GEOSERVER=$deploy_geoserver_choice
    
    # Studio selection
    if kubectl get deployment geofm-ui -n ${OC_PROJECT} &> /dev/null; then
        echo "⚠️  Geospatial Studio deployment already exists"
    fi
    studio_options="Deploy Skip"
    typeset deploy_studio_choice
    get_menu_selection \
        "Deploy/Redeploy Geospatial Studio?" \
        deploy_studio_choice \
        "$studio_options"
    DEPLOY_STUDIO=$deploy_studio_choice
    
    echo ""
    echo "Deployment plan:"
    echo "  MinIO: $DEPLOY_MINIO"
    echo "  PostgreSQL: $DEPLOY_POSTGRES"
    echo "  Keycloak: $DEPLOY_KEYCLOAK"
    echo "  GeoServer: $DEPLOY_GEOSERVER"
    echo "  Studio: $DEPLOY_STUDIO"
    echo ""
    
    printf "%s " "Press enter to continue with this deployment plan"
    read ans
fi

if [[ "$JUMP_TO_DEPLOYMENT" == "No" ]]; then
    # Below step will create two env scripts under the workspace/${DEPLOYMENT_ENV}/env folder.
    # One script contains just the secret values template, and the other script contains all the other general Geospatial configuration.
    ./deployment-scripts/setup-workspace-env.sh

    # Update the workspave env file with deployment env and namespace
    sed -i -e "s/export DEPLOYMENT_ENV=.*/export DEPLOYMENT_ENV=${DEPLOYMENT_ENV}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export OC_PROJECT=.*/export OC_PROJECT=${OC_PROJECT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

    # Update cluster url
    if [[ -n "$CLUSTER_URL" ]]; then
        cluster_url_defined_options="Yes No"
        typeset cluster_url_defined

        # Call the function
        get_menu_selection \
            "Use CLUSTER_URL = ${CLUSTER_URL} " \
            cluster_url_defined \
            "$cluster_url_defined_options"
    else 
        cluster_url_defined="No"
    fi

    if [[ "$cluster_url_defined" == "No" ]]; then
        # Try to extract the cluster url for OCP else request the user
        set_cluster_url
    fi
    # Update the workspace env file with CLUSTER_URL
    sed -i -e "s/export CLUSTER_URL=.*/export CLUSTER_URL=${CLUSTER_URL}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh


    # Update imge pull secret
    python deployment-scripts/validate-env-files.py \
        --env-file  workspace/${DEPLOYMENT_ENV}/env/.env \
        --env-variables "image_pull_secret_b64" \
        --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh \
        --env-sh-variables ""

    if [ $? -ne 0 ]; then
        echo "***********************************************************************************"
        echo "-----------------------  Configure image pull secret ------------------------------"
        echo "-----------------------------------------------------------------------------------"
        echo "Image pull secrets are only required for private container registries."
        echo "Leave empty if your images are publicly accessible."
        echo "-----------------------------------------------------------------------------------"
        image_pull_secret_config_options="Skip-for-public-images Provide-secret"
        typeset image_pull_secret_config_type

        get_menu_selection \
        "Select image pull secret configuration: " \
        image_pull_secret_config_type \
        "$image_pull_secret_config_options"

        if [[ "$image_pull_secret_config_type" == "Skip-for-public-images" ]]; then
            export STUDIO_IMAGE_PULL_SECRET=""
            echo "ℹ️  Image pull secret not configured (using public images)"
        else
            typeset ips
            get_user_input "Enter base64-encoded image pull secret: " ips
            echo "STUDIO_IMAGE_PULL_SECRET accepted: **$ips**"
            export STUDIO_IMAGE_PULL_SECRET=$ips
        fi

        # Update the workspace env file with STUDIO_IMAGE_PULL_SECRET
        sed -i -e "s/image_pull_secret_b64=.*/image_pull_secret_b64=\"${STUDIO_IMAGE_PULL_SECRET}\"/g" workspace/${DEPLOYMENT_ENV}/env/.env
    fi

    oc adm policy add-scc-to-user anyuid -n ${OC_PROJECT} -z default
    
    source workspace/${DEPLOYMENT_ENV}/env/env.sh

    install_csi_driver_options="Yes No"
    typeset install_csi_driver_config_type

    get_menu_selection \
    "Do you want to install the ibm cos csi driver: " \
    install_csi_driver_config_type \
    "$install_csi_driver_options"

    export INSTALL_CSI_DRIVER="$install_csi_driver_config_type"

    # Install IBM Object Storage Plugin (optional, controlled by INSTALL_CSI_DRIVER env var)
    if [[ "${INSTALL_CSI_DRIVER:-No}" == "Yes" ]]; then
        # label node
        oc label nodes crc topology.kubernetes.io/region=us-east --overwrite
        oc label nodes crc topology.kubernetes.io/zone=us-east --overwrite
        oc label nodes crc ibm-cloud.kubernetes.io/region=us-east --overwrite

        echo "----------------------------------------------------------------------"
        echo "------  Installing IBM Object Storage Plugin (Helm-based)  ----------"
        echo "----------------------------------------------------------------------"

        # Add IBM Helm repo
        helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
        helm repo update

        # Fetch and install Helm plugin with proper permissions
        echo "Fetching IBM Object Storage Plugin chart..."
        helm fetch --untar ibm-helm/ibm-object-storage-plugin

        # Make the plugin script executable
        if [ -f "./ibm-object-storage-plugin/helm-ibmc/ibmc.sh" ]; then
            chmod +x ./ibm-object-storage-plugin/helm-ibmc/ibmc.sh
            echo "Made helm-ibmc plugin executable"
        fi

        # Install Helm plugin (suppress error if already installed)
        if ! helm plugin list | grep -q ibmc; then
            echo "Installing helm-ibmc plugin..."
            helm plugin install ./ibm-object-storage-plugin/helm-ibmc
        else
            echo "Helm plugin 'ibmc' already installed"
        fi

        # Install IBM Object Storage Plugin
        echo "Installing IBM Object Storage Plugin via Helm..."
        # crc runs on a redhat vm
        helm ibmc install ibm-object-storage-plugin ibm-helm/ibm-object-storage-plugin \
            --set license=true \
            --set workerOS="redhat" \
            --set region="us-east"

        # Check if installation succeeded
        if [ $? -ne 0 ]; then
            echo "✗ Failed to install IBM Object Storage Plugin"
            exit 1
        fi

        echo "Waiting for plugin deployment to be ready..."
        kubectl_wait_with_retry $KUBECTL_WAIT_RETRY_ATTEMPTS $KUBECTL_WAIT_RETRY_DELAY \
            --for=condition=available deployment/ibmcloud-object-storage-plugin \
            -n ibm-object-s3fs --timeout=300s

        # Create trusted CA bundle ConfigMap for OpenShift TLS
        if [[ "$DEPLOYMENT_ENV" == "crc" ]]; then
            echo "Creating trusted CA bundle for TLS..."
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

            # Mount CA bundle to plugin deployment
            oc set volume deployment/ibmcloud-object-storage-plugin \
                --add \
                --name=ca-bundle-vol \
                --type=configmap \
                --configmap-name=trusted-ca-bundle \
                --mount-path=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
                --read-only=true \
                --sub-path=service-ca.crt \
                -n ibm-object-s3fs
        fi

        echo "✅ IBM Object Storage Plugin installed successfully"
        echo "   Storage class 'ibmc-s3fs-cos' is now available"
        
        # Verify the plugin is working
        echo ""
        echo "Verifying IBM Object Storage Plugin..."
        echo "Checking plugin pods:"
        kubectl get pods -n ibm-object-s3fs
        
        echo ""
        echo "Checking storage class:"
        kubectl get storageclass ibmc-s3fs-cos -o yaml
        
        echo ""
        echo "Checking plugin logs for any errors:"
        kubectl logs -n ibm-object-s3fs deployment/ibmcloud-object-storage-plugin --tail=20 --all-containers=true || echo "No logs available yet"
        
        echo ""
        echo "Waiting 10 seconds for plugin to fully initialize..."
        sleep 10
    else
        echo "----------------------------------------------------------------------"
        echo "Skipping IBM Object Storage Plugin installation (INSTALL_CSI_DRIVER not set to 'Yes')"
        echo "----------------------------------------------------------------------"
    fi

    echo "***********************************************************************************"
    echo "-----------------------  Configure s3 storage classes -----------------------------"
    echo "-----------------------------------------------------------------------------------"
    echo "---------------- Verify the available storage classes in your cluster -------------"
    echo "-----------------------------------------------------------------------------------"
    echo "---------- You should already have setup the cloud object storage drivers ---------"
    echo "-- See: https://cloud.ibm.com/docs/openshift?topic=openshift-storage_cos_install --"
    echo "***********************************************************************************"
    echo "************************  You will enter the following  ***************************"
    echo "--------------------------  COS_STORAGE_CLASS -------------------------------------"
    echo "------------------------  NON_COS_STORAGE_CLASS ---------------------------------"
    echo "***********************************************************************************"

    while true; do
        printf "%s " "Press enter to continue"
        read ans

        typeset user_cos_storage_class
        get_user_input "Enter COS_STORAGE_CLASS: " user_cos_storage_class
        echo "COS_STORAGE_CLASS accepted: **$user_cos_storage_class**"
        export COS_STORAGE_CLASS=$user_cos_storage_class

        typeset user_non_cos_storage_class
        get_user_input "Enter NON_COS_STORAGE_CLASS: " user_non_cos_storage_class
        echo "NON_COS_STORAGE_CLASS accepted: **$user_non_cos_storage_class**"
        export NON_COS_STORAGE_CLASS=$user_non_cos_storage_class

        sed -i -e "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=${COS_STORAGE_CLASS}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
        sed -i -e "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=${NON_COS_STORAGE_CLASS}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

        python deployment-scripts/validate-env-files.py \
        --env-file  workspace/${DEPLOYMENT_ENV}/env/.env \
        --env-variables "" \
        --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh \
        --env-sh-variables "COS_STORAGE_CLASS,NON_COS_STORAGE_CLASS"

        if [ $? -eq 0 ]; then
            break
        fi
    done

    if [[ "$DEPLOY_MINIO" == "Deploy" ]]; then
        cloud_object_storage_type_options="Cluster-deployment Cloud-managed-instance"
        typeset cloud_object_storage_type

        get_menu_selection \
            "Select whether to deploy a cloud object storage in cluster or use a cloud managed instance that you have externally subscribed to: " \
            cloud_object_storage_type \
            "$cloud_object_storage_type_options"
    else
        # If skipping MinIO, assume cloud-managed to skip deployment
        cloud_object_storage_type="Cloud-managed-instance"
    fi

    if [[ "$cloud_object_storage_type" == "Cluster-deployment" ]]; then

        echo "----------------------------------------------------------------------"
        echo "--------------------  Deploying Minio  -------------------------------"
        echo "----------------------------------------------------------------------"

        source workspace/${DEPLOYMENT_ENV}/env/env.sh
        
        python ./deployment-scripts/update-deployment-template.py --disable-pvc --filename deployment-scripts/minio-deployment.yaml --storageclass ${NON_COS_STORAGE_CLASS} > workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml
        kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml -n ${OC_PROJECT}

        kubectl_wait_with_retry $KUBECTL_WAIT_RETRY_ATTEMPTS $KUBECTL_WAIT_RETRY_DELAY --for=condition=ready pod -l app=minio -n ${OC_PROJECT} --timeout=300s

        MINIO_API_URL="https://minio-api-$OC_PROJECT.$CLUSTER_URL"

        # Update .env with the MinIO details for connection
        sed -i -e "s/access_key_id=.*/access_key_id=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/secret_access_key=.*/secret_access_key=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s|endpoint=.*|endpoint=$MINIO_API_URL|g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/region=.*/region=us-east/g" workspace/${DEPLOYMENT_ENV}/env/.env

        # Wait for MinIO service to be ready (pod ready doesn't mean service is accepting connections)
        echo "Waiting for MinIO service to be ready..."
        MAX_RETRIES=6
        RETRY_DELAY=10
        
        for i in $(seq 1 $MAX_RETRIES); do
            # Try internal service first
            if kubectl exec -n ${OC_PROJECT} $(kubectl get pod -n ${OC_PROJECT} -l app=minio -o jsonpath='{.items[0].metadata.name}') -- curl -ks -f "https://localhost:9000/minio/health/live" > /dev/null 2>&1; then
                echo "✓ MinIO service is ready via localhost (attempt $i/$MAX_RETRIES)"
                break
            fi
            
            # If internal check fails, show diagnostics
            if [ $i -eq $MAX_RETRIES ]; then
                echo "✗ MinIO service failed to become ready after $MAX_RETRIES attempts"
                echo "Diagnostics:"
                echo "- Pod status:"
                kubectl get pods -n ${OC_PROJECT} -l app=minio
                echo "- Pod logs (last 20 lines):"
                kubectl logs -n ${OC_PROJECT} -l app=minio --tail=20
                echo "- Service status:"
                kubectl get svc -n ${OC_PROJECT} minio
                echo "- Route status:"
                kubectl get route -n ${OC_PROJECT} minio-api
                exit 1
            fi
            
            echo "MinIO not ready yet (attempt $i/$MAX_RETRIES), waiting ${RETRY_DELAY}s..."
            
            # Show pod status every 5 attempts
            if [ $((i % 2)) -eq 0 ]; then
                echo "$(date +%H:%M:%S) - Pod status:"
                kubectl get pods -n ${OC_PROJECT} -l app=minio -o custom-columns=NAME:.metadata.name,STATUS:.status.phase --no-headers
            fi
            
            sleep $RETRY_DELAY
        done
        
        # Now verify the Route is accessible (this might take longer due to SSL/routing)
        echo "Verifying MinIO Route accessibility..."
        for i in $(seq 1 5); do
            if curl -k -s -f "$MINIO_API_URL/minio/health/live" > /dev/null 2>&1; then
                echo "✓ MinIO Route is accessible"
                break
            else
                if [ $i -eq 10 ]; then
                    echo "⚠ Warning: MinIO Route not accessible, but service is running. This may be a Route/SSL issue."
                    echo "Continuing deployment - MinIO is accessible internally."
                fi
                echo "Route check attempt $i/10..."
                sleep 5
            fi
        done

        if [[ "$DEPLOYMENT_ENV" == "crc" ]]; then
            MINIO_CLUSTER_IP=$(oc get svc minio -n "${OC_PROJECT}" -o jsonpath='{.spec.clusterIP}')
            MINIO_INTERNAL_URL="minio.${OC_PROJECT}.svc.cluster.local"
            export LOCAL_CA_CRT=$(oc get configmap trusted-ca-bundle -n ibm-object-s3fs -o jsonpath='{.data.service-ca\.crt}')

            cat deployment-scripts/crc-hosts-modifier-daemonset.yaml | sed -e "s/\$MINIO_CLUSTER_IP/$MINIO_CLUSTER_IP/g" | sed -e "s/\$MINIO_INTERNAL_URL/$MINIO_INTERNAL_URL/g" > workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml
            auto_indent_and_replace workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml SELF_CA_CRT "$LOCAL_CA_CRT" workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset.yaml
            rm workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml
            oc apply -f workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset.yaml -n default
        fi

    else
        if [[ "$DEPLOY_MINIO" == "Deploy" ]]; then
            echo "**********************************************************************"
            echo "**********************************************************************"
            echo "-----------  Configure s3 storage and update the values --------------"
            echo "**********************************************************************"
            echo "**********************************************************************"
            echo "***********  Update workspace/${DEPLOYMENT_ENV}/env/.env *************"
            echo "-----------  access_key_id= ------------------------------------------"
            echo "-----------  secret_access_key= --------------------------------------"
            echo "-----------  endpoint= -----------------------------------------------"
            echo "-----------  region= -------------------------------------------------"
            echo "**********************************************************************"
            echo "**********************************************************************"

            while true; do
                printf "%s " "Press enter to continue after entering the variables"
                read ans

                python deployment-scripts/validate-env-files.py \
                --env-file  workspace/${DEPLOYMENT_ENV}/env/.env \
                --env-variables "access_key_id,secret_access_key,endpoint,region" \
                --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh \
                --env-sh-variables ""

                if [ $? -eq 0 ]; then
                    break
                fi
            done
        else
            echo "----------------------------------------------------------------------"
            echo "-------------------  Skipping Minio Deployment  ----------------------"
            echo "----------------------------------------------------------------------"
            echo "Loading existing MinIO/S3 configuration..."
        fi
    fi

    source workspace/${DEPLOYMENT_ENV}/env/env.sh

    # Create buckets
    python deployment-scripts/create_buckets.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env

    # For crc we set the endpoint for the cos pvc to internal cluster url since at the driver s3fuse level the routes don't resolve
    if [[ "$DEPLOYMENT_ENV" == "crc" ]]; then
        sed -i -e "s|endpoint=.*|endpoint=https://minio.$OC_PROJECT.svc.cluster.local:9000|g" workspace/${DEPLOYMENT_ENV}/env/.env
    fi

    source workspace/${DEPLOYMENT_ENV}/env/env.sh


    if [[ "$DEPLOY_POSTGRES" == "Deploy" ]]; then
        postgres_type_options="Cluster-deployment Cloud-managed-instance"
        typeset postgres_type

        # Call the function
        get_menu_selection \
            "Select whether to deploy postgres in cluster or use a cloud managed instance that you have externally subscribed to: " \
            postgres_type \
            "$postgres_type_options"
    else
        # If skipping PostgreSQL, assume cloud-managed to skip deployment
        postgres_type="Cloud-managed-instance"
    fi

    if [[ "$postgres_type" == "Cluster-deployment" ]]; then
        echo "----------------------------------------------------------------------"
        echo "--------------------  Deploying Postgres  ----------------------------"
        echo "----------------------------------------------------------------------"

        # Install Postgres
        helm repo add bitnami  https://charts.bitnami.com/bitnami
        helm repo update

        export POSTGRES_PASSWORD=devPostgresql123

        ./deployment-scripts/install-postgres.sh UPDATE_STORAGE DISABLE_PV DO_NOT_SET_SCC

        kubectl_wait_with_retry $KUBECTL_WAIT_RETRY_ATTEMPTS $KUBECTL_WAIT_RETRY_DELAY --for=condition=ready pod/postgresql-0 -n ${OC_PROJECT} --timeout=300s

        kubectl port-forward --namespace ${OC_PROJECT} svc/postgresql 54320:5432 &
        sleep 5

        # Update .env with the Postgres details for local connection
        sed -i -e "s/pg_username=.*/pg_username=postgres/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/pg_password=.*/pg_password=${POSTGRES_PASSWORD}/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/pg_uri=.*/pg_uri=127.0.0.1/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/pg_port=.*/pg_port=5432/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/pg_original_db_name=.*/pg_original_db_name='postgres'/g" workspace/${DEPLOYMENT_ENV}/env/.env

        python deployment-scripts/create_studio_dbs.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env

        sed -i -e "s/pg_uri=.*/pg_uri=postgresql.${OC_PROJECT}.svc.cluster.local/g" workspace/${DEPLOYMENT_ENV}/env/.env
        
        # Set PgBouncer configuration
        sed -i -e "s/pgbouncer_host=.*/pgbouncer_host=geofm-pgbouncer.${OC_PROJECT}.svc.cluster.local/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/pgbouncer_password=.*/pgbouncer_password=${POSTGRES_PASSWORD}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    else
        if [[ "$DEPLOY_POSTGRES" == "Deploy" ]]; then
            echo "**********************************************************************"
            echo "**********************************************************************"
            echo "-----------  Configure cloud based posgtres and update the values ----"
            echo "**********************************************************************"
            echo "**********************************************************************"
            echo "***********  Update workspace/${DEPLOYMENT_ENV}/env/.env *************"
            echo "-----------  pg_username= --------------------------------------------"
            echo "-----------  pg_password= --------------------------------------------"
            echo "-----------  pg_uri= -------------------------------------------------"
            echo "-----------  pg_port= ------------------------------------------------"
            echo "-----------  pg_original_db_name= ------------------------------------"
            echo "**********************************************************************"
            echo "**********************************************************************"

            while true; do
                printf "%s " "Press enter to continue after entering the variables"
                read ans

                python deployment-scripts/validate-env-files.py \
                --env-file  workspace/${DEPLOYMENT_ENV}/env/.env \
                --env-variables "pg_username,pg_password,pg_uri,pg_port,pg_original_db_name" \
                --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh \
                --env-sh-variables ""

                if [ $? -eq 0 ]; then
                    break
                fi
            done

            python deployment-scripts/create_studio_dbs.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env

            # Set PgBouncer configuration for cloud-managed postgres
            # Note: User needs to manually set pgbouncer_host if using external PgBouncer
            sed -i -e "s/pgbouncer_password=.*/pgbouncer_password=${pg_password}/g" workspace/${DEPLOYMENT_ENV}/env/.env
        else
            echo "----------------------------------------------------------------------"
            echo "-----------------  Skipping Postgres Deployment  ---------------------"
            echo "----------------------------------------------------------------------"
            echo "Loading existing PostgreSQL configuration..."
        fi      
    fi

    source workspace/${DEPLOYMENT_ENV}/env/env.sh

    if [[ "$DEPLOY_KEYCLOAK" == "Deploy" ]]; then
        oauth_type_options="Keycloak ISV"
        typeset oauth_type

        # Call the function
        get_menu_selection \
            "Select whether to use incluster Keycloak of an instance of IBM Verify that you have provisioned externally: " \
            oauth_type \
            "$oauth_type_options"
    else
        # If skipping Keycloak, assume ISV to skip deployment
        oauth_type="ISV"
    fi

    if [[ "$oauth_type" == "Keycloak" ]]; then

        echo "----------------------------------------------------------------------"
        echo "--------------------  Deploying Keycloak  ----------------------------"
        echo "----------------------------------------------------------------------"


        python ./deployment-scripts/update-keycloak-deployment.py --filename deployment-scripts/keycloak-deployment.yaml --env-path workspace/${DEPLOYMENT_ENV}/env/.env > workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml
        kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml -n ${OC_PROJECT}

        kubectl_wait_with_retry $KUBECTL_WAIT_RETRY_ATTEMPTS $KUBECTL_WAIT_RETRY_DELAY --for=condition=ready pod -l app=keycloak -n ${OC_PROJECT} --timeout=300s

        kubectl port-forward -n ${OC_PROJECT} svc/keycloak 8080:8080 &
        sleep 5

        # Keycloak setup
        export client_secret=`cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32`
        export cookie_secret=`cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32`

        ./deployment-scripts/setup-keycloak.sh

        sed -i -e "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env

        sed -i -e "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
        sed -i -e "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
        if [[ "$DEPLOYMENT_ENV" == "crc" ]]; then
            sed -i -e "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=$(printf "http://%s.%s.svc.cluster.local:8080/realms/geostudio" "keycloak" "$OC_PROJECT")|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
        else
            sed -i -e "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=$(printf "https://%s-%s.%s/realms/geostudio" "keycloak" "$OC_PROJECT" "$CLUSTER_URL")|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
        fi
        sed -i -e "s|export OAUTH_URL=.*|export OAUTH_URL=$(printf "https://%s-%s.%s/realms/geostudio/protocol/openid-connect/auth" "keycloak" "$OC_PROJECT" "$CLUSTER_URL")|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
        sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=${OAUTH_PROXY_PORT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

    else
        if [[ "$DEPLOY_KEYCLOAK" == "Deploy" ]]; then
            echo "**********************************************************************"
            echo "**********************************************************************"
            echo "-----------  Configure IBM Verify and update the values --------------"
            echo "**********************************************************************"
            echo "**********************************************************************"
            echo "***********  Update workspace/${DEPLOYMENT_ENV}/env/.env *************"
            echo "-----------  oauth_client_secret= ------------------------------------"
            echo "-----------  oauth_cookie_secret= ------------------------------------"
            echo "**********************************************************************"
            echo "**********************************************************************"
            echo "***********  Update workspace/${DEPLOYMENT_ENV}/env/env.sh ***********"
            echo "-----------  export OAUTH_TYPE=isv -----------------------------------"
            echo "-----------  export OAUTH_CLIENT_ID= ---------------------------------"
            echo "-----------  export OAUTH_ISSUER_URL= --------------------------------"
            echo "-----------  export OAUTH_URL= ---------------------------------------"
            echo "**********************************************************************"
            echo "**********************************************************************"

            while true; do
                printf "%s " "Press enter to continue after entering the variables"
                read ans

                python deployment-scripts/validate-env-files.py \
                --env-file  workspace/${DEPLOYMENT_ENV}/env/.env \
                --env-variables "oauth_client_secret,oauth_cookie_secret" \
                --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh \
                --env-sh-variables "OAUTH_TYPE,OAUTH_CLIENT_ID,OAUTH_ISSUER_URL,OAUTH_URL"

                if [ $? -eq 0 ]; then
                    break
                fi
            done
        else
            echo "----------------------------------------------------------------------"
            echo "-----------------  Skipping Keycloak Deployment  ---------------------"
            echo "----------------------------------------------------------------------"
            echo "Loading existing Keycloak/OAuth configuration..."
        fi
    fi


    echo "----------------------------------------------------------------------"
    echo "--------------------  Updating other values  -------------------------"
    echo "----------------------------------------------------------------------"

    if [[ "$IS_OPENSHIFT" == "false" ]]; then
        # Kubernetes tls secret setup

        # request for CNAME
        typeset cname
        get_user_input "Provide the CNAME of your cluster: e.g. default.svc.cluster.local, example.com " cname
        echo "CNAME accepted: **$cname**"

        # create tls.key and tls.crt
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=$cname"

        # extract the cert and key into env vars

        export TLS_CRT_B64=$(openssl base64 -in tls.crt -A)
        export TLS_KEY_B64=$(openssl base64 -in tls.key -A)

        sed -i -e "s/tls_crt_b64=.*/tls_crt_b64=$TLS_CRT_B64/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/tls_key_b64=.*/tls_key_b64=$TLS_KEY_B64/g" workspace/${DEPLOYMENT_ENV}/env/.env
        sed -i -e "s/export CREATE_TLS_SECRET=.*/export CREATE_TLS_SECRET=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    fi

    # Geoserver setup
    export GEOSERVER_USERNAME="admin"
    export GEOSERVER_PASSWORD="geoserver"
    export GEOSERVER_URL="https://geofm-geoserver-$OC_PROJECT.$CLUSTER_URL/geoserver"

    sed -i -e "s/geoserver_username=.*/geoserver_username=$GEOSERVER_USERNAME/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/geoserver_password=.*/geoserver_password=$GEOSERVER_PASSWORD/g" workspace/${DEPLOYMENT_ENV}/env/.env

    if [[ "$DEPLOY_GEOSERVER" == "Deploy" ]]; then
        echo "----------------------------------------------------------------------"
        echo "--------------------  Deploying Geoserver  ----------------------------"
        echo "----------------------------------------------------------------------"

        if [[ "$IS_OPENSHIFT" == "false" ]]; then
        python ./deployment-scripts/update-deployment-template.py --disable-pvc --filename deployment-scripts/geoserver-deployment.yaml --storageclass ${NON_COS_STORAGE_CLASS} --proxy-base-url $(printf "https://%s-%s.%s/geoserver" "geofm-geoserver" "$OC_PROJECT" "$CLUSTER_URL") --geoserver-csrf-whitelist ${CLUSTER_URL} > workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml
        kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n ${OC_PROJECT}
    else
        geoserver_install_options="Configure-SCC Use-Custom-Image"
        typeset geoserver_install_type

        # Call the function
        get_menu_selection \
            "Select whether to deploy default geoserver which requires admin privileges by configuring scc anyuid or use a custom geoserver image: " \
            geoserver_install_type \
            "$geoserver_install_options"

        if [[ "$geoserver_install_type" == "Configure-SCC" ]]; then
            oc adm policy add-scc-to-user anyuid -n ${OC_PROJECT} -z default
            python ./deployment-scripts/update-deployment-template.py --disable-pvc --filename deployment-scripts/geoserver-deployment.yaml --storageclass ${NON_COS_STORAGE_CLASS} --proxy-base-url $(printf "https://%s-%s.%s/geoserver" "geofm-geoserver" "$OC_PROJECT" "$CLUSTER_URL") --geoserver-csrf-whitelist ${CLUSTER_URL} > workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml
            kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n ${OC_PROJECT}
        else
            printf "\n\n#Use this dockerfile to create a custom image\n\nFROM --platform=linux/amd64 docker.osgeo.org/geoserver:2.28.1\nRUN chmod -R 777 /tmp\nRUN addgroup --system geoserver && adduser --system -gid 101 geoserver\nRUN chown -R geoserver:geoserver /opt\nRUN chmod -R 777 /opt\nRUN chmod -R 777 /usr/local/tomcat\nUSER geoserver:geoserver\n"
            printf "\n\nBuild and push your image to your registry of choice. You'll be prompted to input configuration for the image pull secret:\n image registry uri. e.g. myimage.io\n image registry email. e.g. myemail@example.com\n image registry password\n geoserver image uri. e.g myimages.io/geostudio/patched_geoserver:v0\n\n"
            sleep 5
            while true; do
                printf "%s " "Press enter to if you have pushed the custom geoserver image to a registry"
                read ans

                printf "\n\nCreating the geoserver image pull secret using \n kubectl create secret docker-registry <secret-name> --docker-server=<docker-registry-uri> --docker-username=iamapikey --docker-password=<docker-password> --docker-email=email@example.com --namespace ${OC_PROJECT}\n\n"
                geoserver_image_pull_secret_name="geoserver-image-pull-secret"
                typeset geoserver_image_registry_uri
                get_user_input "Provide the geoserver image registry uri: " geoserver_image_registry_uri
                echo "geoserver image registry uri accepted: **$geoserver_image_registry_uri**"

                typeset geoserver_image_registry_email
                get_user_input "Provide the geoserver image registry email: " geoserver_image_registry_email
                echo "geoserver image email accepted: **$geoserver_image_registry_email**"

                typeset geoserver_image_registry_password
                get_user_input "Provide the geoserver image registry password: " geoserver_image_registry_password
                echo "geoserver image registry password accepted"

                kubectl create secret docker-registry ${geoserver_image_pull_secret_name} --docker-server=${geoserver_image_registry_uri} --docker-username=iamapikey --docker-password=${geoserver_image_registry_password} --docker-email=${geoserver_image_registry_email} --namespace ${OC_PROJECT} --dry-run=client -o yaml > workspace/$DEPLOYMENT_ENV/initialisation/geoserver_docker_secret.yaml
                kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver_docker_secret.yaml

                if [ $? -ne 0 ]; then
                    continue
                fi

                typeset geoserver_image_uri
                get_user_input "Provide the geoserver image uri: " geoserver_image_uri
                echo "geoserver image uri accepted: **$geoserver_image_uri**"

                python ./deployment-scripts/update-deployment-template.py --disable-pvc --filename deployment-scripts/geoserver-deployment.yaml --storageclass ${NON_COS_STORAGE_CLASS} --proxy-base-url $(printf "https://%s-%s.%s/geoserver" "geofm-geoserver" "$OC_PROJECT" "$CLUSTER_URL") --geoserver-csrf-whitelist ${CLUSTER_URL} --geoserver-run-unprivileged "false" --geoserver-image-pull-secret ${geoserver_image_pull_secret_name} --geoserver-image-uri ${geoserver_image_uri} > workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml
                kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n ${OC_PROJECT}

                if [ $? -eq 0 ]; then
                    break
                fi
            done
        fi
    fi

        kubectl_wait_with_retry $KUBECTL_WAIT_RETRY_ATTEMPTS $KUBECTL_WAIT_RETRY_DELAY --for=condition=ready pod -l app.kubernetes.io/name=gfm-geoserver -n ${OC_PROJECT} --timeout=900s

        kubectl port-forward -n ${OC_PROJECT} svc/geofm-geoserver 3000:3000 &
        sleep 5

        echo "----------------------------------------------------------------------"
        echo "--------------------  Configuring Geoserver  ----------------------------"
        echo "----------------------------------------------------------------------"
        ./deployment-scripts/setup_geoserver.sh
    else
        echo "----------------------------------------------------------------------"
        echo "-----------------  Skipping Geoserver Deployment  --------------------"
        echo "----------------------------------------------------------------------"
        echo "Loading existing GeoServer configuration..."
        source workspace/${DEPLOYMENT_ENV}/env/env.sh
    fi

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

    sed -i -e "s/studio_api_key=.*/studio_api_key=$STUDIO_API_KEY/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/studio_api_encryption_key=.*/studio_api_encryption_key=$API_ENCRYPTION_KEY/g" workspace/${DEPLOYMENT_ENV}/env/.env


    sed -i -e "s/redis_password=.*/redis_password=devPassword/g" workspace/${DEPLOYMENT_ENV}/env/.env
   

    sed -i -e "s/export ENVIRONMENT=.*/export ENVIRONMENT=${DEPLOYMENT_ENV}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export ROUTE_ENABLED=.*/export ROUTE_ENABLED=${IS_OPENSHIFT}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export SHARE_PIPELINE_PVC=.*/export SHARE_PIPELINE_PVC=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export STORAGE_PVC_ENABLED=.*/export STORAGE_PVC_ENABLED=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export STORAGE_FILESYSTEM_ENABLED=.*/export STORAGE_FILESYSTEM_ENABLED=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export CREATE_TUNING_FOLDERS_FLAG=.*/export CREATE_TUNING_FOLDERS_FLAG=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export PIPELINES_TERRATORCH_INFERENCE_CREATE_FT_PVC=.*/export PIPELINES_TERRATORCH_INFERENCE_CREATE_FT_PVC=false/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

    sed -i -e "s/export OAUTH_PROXY_ENABLED=.*/export OAUTH_PROXY_ENABLED=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=8443/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

    export IMAGE_REGISTRY=geospatial-studio
    sed -i -e "s/export CONTAINER_IMAGE_REPOSITORY=.*/export CONTAINER_IMAGE_REPOSITORY=${IMAGE_REGISTRY}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

    while true; do
        printf "%s " "Press enter to confirm all mandatory environment variables are defined"
        read ans

        python deployment-scripts/validate-env-files.py \
        --env-file  workspace/${DEPLOYMENT_ENV}/env/.env \
        --env-variables "deployment_name,ocp_project,studio_api_key,studio_api_encryption_key,access_key_id,secret_access_key,endpoint,region,pg_username,pg_password,pg_uri,pg_port,pg_original_db_name,pg_studio_db_name,geoserver_username,geoserver_password,oauth_client_secret,oauth_cookie_secret,redis_password,image_pull_secret_b64" \
        --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh \
        --env-sh-variables "DEPLOYMENT_ENV,OC_PROJECT,ROUTE_ENABLED,CONTAINER_IMAGE_REPOSITORY,CLUSTER_URL,COS_STORAGE_CLASS,NON_COS_STORAGE_CLASS,STORAGE_PVC_ENABLED,OAUTH_PROXY_ENABLED,OAUTH_PROXY_PORT,OAUTH_TYPE,OAUTH_CLIENT_ID,OAUTH_ISSUER_URL,OAUTH_URL"

        if [ $? -eq 0 ]; then
            break
        fi
    done

    source workspace/${DEPLOYMENT_ENV}/env/env.sh

    echo "----------------------------------------------------------------------"
    echo "----------------  Generating deployment scripts  ---------------------"
    echo "----------------------------------------------------------------------"

    # Create deployment values files
    ./deployment-scripts/values-file-generate.sh

    cp workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values.yaml workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml

    # Replace credential placeholders with actual values from .env
    source workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s|<postgres_host>|${pg_uri}|g" workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    sed -i -e "s|<postgres_port>|${pg_port}|g" workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    sed -i -e "s|<pg_user>|${pg_username}|g" workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    sed -i -e "s|<pg_pass>|${pg_password}|g" workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    sed -i -e "s|<pgbouncer_host>|${pgbouncer_host}|g" workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    sed -i -e "s|<pgbouncer_port>|${pgbouncer_port}|g" workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    sed -i -e "s|<pgbouncer_user>|${pgbouncer_username}|g" workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    sed -i -e "s|<pgbouncer_pass>|${pgbouncer_password}|g" workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml

    # The line below removes GPUs from the pipeline components, to leave GPUs activated, copy out this line
    gpu_configuration_options="GPU-Available No-GPU-Available"
    typeset gpu_configuration_type

    # Call the function
    get_menu_selection \
        "Select whether you have GPU available in your cluster: " \
        gpu_configuration_type \
        "$gpu_configuration_options"

    if [[ "$gpu_configuration_type" == "GPU-Available" ]]; then
        python ./deployment-scripts/remove-pipeline-gpu.py --remove-affinity-only workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    else
        python ./deployment-scripts/remove-pipeline-gpu.py workspace/${DEPLOYMENT_ENV}/values/geospatial-studio/values-deploy.yaml
    fi

else
    while true 
    do
        printf "%s " "Press enter to confirm all mandatory environment variables are defined"
        read ans

        python deployment-scripts/validate-env-files.py \
        --env-file  workspace/${DEPLOYMENT_ENV}/env/.env \
        --env-variables "deployment_name,ocp_project,studio_api_key,studio_api_encryption_key,access_key_id,secret_access_key,endpoint,region,pg_username,pg_password,pg_uri,pg_port,pg_original_db_name,pg_studio_db_name,geoserver_username,geoserver_password,oauth_client_secret,oauth_cookie_secret,redis_password,image_pull_secret_b64" \
        --env-sh-file workspace/${DEPLOYMENT_ENV}/env/env.sh \
        --env-sh-variables "DEPLOYMENT_ENV,OC_PROJECT,ROUTE_ENABLED,CONTAINER_IMAGE_REPOSITORY,CLUSTER_URL,COS_STORAGE_CLASS,NON_COS_STORAGE_CLASS,STORAGE_PVC_ENABLED,OAUTH_PROXY_ENABLED,OAUTH_PROXY_PORT,OAUTH_TYPE,OAUTH_CLIENT_ID,OAUTH_ISSUER_URL,OAUTH_URL"

        if [ $? -eq 0 ]; then
            break
        fi
    done
fi

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

if [[ "$DEPLOY_STUDIO" == "Deploy" ]]; then
    echo "----------------------------------------------------------------------"
    echo "--------------------  Deploying the Studio  --------------------------"
    echo "----------------------------------------------------------------------"

    # Deploy Geospatial Studio
    ./deployment-scripts/deploy_studio.sh
else
    echo "----------------------------------------------------------------------"
    echo "------------------  Skipping Studio Deployment  ----------------------"
    echo "----------------------------------------------------------------------"
fi

echo "----------------------------------------------------------------------"
echo "-----------------------  Deployment summary  -------------------------"
echo "----------------------------------------------------------------------"
export UI_ROUTE_URL=$(kubectl get route geofm-ui -n "${OC_PROJECT}" -o jsonpath='{"https://"}{.spec.host}') && \
echo "Opening $UI_ROUTE_URL..." && \
(open $UI_ROUTE_URL || xdg-open $UI_ROUTE_URL || start $UI_ROUTE_URL)

export API_ROUTE_URL=$(kubectl get route geofm-gateway -n "${OC_PROJECT}" -o jsonpath='{"https://"}{.spec.host}')

printf "\n\U1F30D\U1F30E\U1F30F   Geospatial Studio deployed in an OpenShift Cluster! \n"
printf "\U1F5FA   Access the Geospatial Studio UI at: ${UI_ROUTE_URL}\n"
printf "\U1F4BB   Access the Geospatial Studio API at: ${API_ROUTE_URL}\n"

printf "Dev Studio API Key: %s\n" $STUDIO_API_KEY
printf "Dev Postgres Password: %s\n\n" $POSTGRES_PASSWORD

echo "----------------------------------------------------------------------"
echo "----------------------------------------------------------------------"
echo "----------------------------------------------------------------------"
