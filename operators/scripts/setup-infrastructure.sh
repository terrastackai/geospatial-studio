# !/bin/bash
set -e  # Exit immediately on error

# Setup Infrastructure for GEOStudio Operator
# This script deploys the infrastructure components required for GEOStudio.
#
# Prerequisites:
#   - Kubernetes namespace must already exist (or use 'default')
#   - kubectl configured with access to the namespace
#   - Namespace-scoped permissions (create deployments, services, secrets, etc.)
#
# Usage:
#   ./operators/scripts/setup-infrastructure.sh
#
#   The script will prompt for namespace if not provided via USER_NAMESPACE env var.
#
# Configuration via environment variables:
#   DEPLOYMENT_ENV              - Environment name (default: lima)
#   USER_NAMESPACE              - Target namespace (default: prompts user, or 'default')
#   KUBECONFIG                  - Path to kubeconfig
#   
#   Infrastructure Components:
#   DEPLOY_MINIO                - Deploy MinIO object storage (default: true)
#   DEPLOY_POSTGRESQL           - Deploy PostgreSQL database (default: true)
#   DEPLOY_KEYCLOAK             - Deploy Keycloak authentication (default: true)
#   INSTALL_IBM_CSI_DRIVER      - Install IBM Object CSI Driver (default: true)
#
#   External Services (when DEPLOY_*=false):
#   EXTERNAL_POSTGRES_HOST      - External PostgreSQL hostname
#   EXTERNAL_POSTGRES_PORT      - External PostgreSQL port (default: 5432)
#   EXTERNAL_POSTGRES_USER      - External PostgreSQL user
#   EXTERNAL_POSTGRES_PASSWORD  - External PostgreSQL password
#   EXTERNAL_POSTGRES_DB        - External PostgreSQL database name (default: postgres)
#   EXTERNAL_MINIO_ENDPOINT     - External MinIO/S3 endpoint (e.g., https://s3.amazonaws.com)
#   EXTERNAL_MINIO_ACCESS_KEY   - External MinIO/S3 access key
#   EXTERNAL_MINIO_SECRET_KEY   - External MinIO/S3 secret key
#   EXTERNAL_MINIO_REGION       - External MinIO/S3 region (default: us-east-1)
#   EXTERNAL_KEYCLOAK_URL       - External Keycloak base URL
#   EXTERNAL_KEYCLOAK_CLIENT_SECRET - External Keycloak client secret

# Detect cluster type
detect_cluster_type() {
    if [[ "$KUBECONFIG" == *"lima"* ]]; then
        echo "lima"
    elif [[ "$KUBECONFIG" == *"crc"* ]] || kubectl get nodes 2>/dev/null | grep -q "crc"; then
        echo "crc"
    else
        echo "generic"
    fi
}

# Configuration defaults
export DEPLOYMENT_ENV=${DEPLOYMENT_ENV:-lima}
export USER_NAMESPACE=${USER_NAMESPACE:-default}
export OPERATOR_NAMESPACE=${OPERATOR_NAMESPACE:-geostudio-operator-system}

# Check KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "======================================================================"
    echo "  KUBECONFIG Not Set"
    echo "======================================================================"
    echo ""
    echo "ERROR: KUBECONFIG environment variable is not set"
    echo ""
    echo "Please export KUBECONFIG before running this script:"
    echo ""
    echo "  export KUBECONFIG=/path/to/your/kubeconfig"
    echo ""
    echo "Common examples:"
    echo "  # Default kubectl config"
    echo "  export KUBECONFIG=~/.kube/config"
    echo ""
    echo "  # Lima"
    echo "  export KUBECONFIG=\"\$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml\""
    echo ""
    echo "  # Minikube"
    echo "  export KUBECONFIG=~/.kube/config"
    echo ""
    echo "  # OpenShift/CRC"
    echo "  export KUBECONFIG=~/.crc/machines/crc/kubeconfig"
    echo ""
    exit 1
fi

# Infrastructure component flags
export DEPLOY_MINIO=${DEPLOY_MINIO:-true}
export DEPLOY_POSTGRESQL=${DEPLOY_POSTGRESQL:-true}
export DEPLOY_KEYCLOAK=${DEPLOY_KEYCLOAK:-true}
export INSTALL_IBM_CSI_DRIVER=${INSTALL_IBM_CSI_DRIVER:-true}

# Image configuration
export IMAGE_REGISTRY=${IMAGE_REGISTRY:-geospatial-studio}
export STUDIO_IMAGE_PULL_SECRET=${STUDIO_IMAGE_PULL_SECRET:-"eyJhdXRocyI6eyJleGFtcGxlLmlvIjp7InVzZXJuYW1lIjoiZXhhbXBsZSIsInBhc3N3b3JkIjoiZXhhbXBsZSIsImVtYWlsIjoiZXhhbXBsZUBleGFtcGxlLmNvbSIsImF1dGgiOiJaWGhoYlhCc1pUcGxlR0Z0Y0d4bCJ9fX0="}

# PostgreSQL defaults
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-devPostgresql123}

# Detect cluster type
CLUSTER_TYPE=$(detect_cluster_type)

echo "======================================================================"
echo "  GEOStudio Infrastructure Setup"
echo "======================================================================"
echo ""
echo "Configuration:"
echo "  Cluster Type: $CLUSTER_TYPE"
echo "  Environment: $DEPLOYMENT_ENV"
echo "  Namespace: $USER_NAMESPACE"
echo ""
echo "Infrastructure Components:"
echo "  MinIO:        $([ "$DEPLOY_MINIO" = "true" ] && echo "Deploy" || echo "External: ${EXTERNAL_MINIO_ENDPOINT}")"
echo "  PostgreSQL:   $([ "$DEPLOY_POSTGRESQL" = "true" ] && echo "Deploy" || echo "External: ${EXTERNAL_POSTGRES_HOST}")"
echo "  Keycloak:     $([ "$DEPLOY_KEYCLOAK" = "true" ] && echo "Deploy" || echo "External: ${EXTERNAL_KEYCLOAK_URL}")"
echo "  CSI Driver:   $([ "$INSTALL_IBM_CSI_DRIVER" = "true" ] && echo "Install" || echo "Skip")"
echo ""

# Validate cluster connection
if ! kubectl cluster-info &>/dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    echo "Check KUBECONFIG: $KUBECONFIG"
    exit 1
fi

echo "----------------------------------------------------------------------"
echo "--------------------  Namespace Configuration  -----------------------"
echo "----------------------------------------------------------------------"

# Prompt for namespace if not provided via environment variable
if [ -z "$USER_NAMESPACE" ] || [ "$USER_NAMESPACE" = "default" ]; then
    echo ""
    echo "GEOStudio will be deployed to a Kubernetes namespace."
    echo ""
    echo "Options:"
    echo "  1. Press ENTER to use the 'default' namespace"
    echo "  2. Type a namespace name to use an existing namespace"
    echo ""
    
    while true; do
        printf "Namespace name [default]: "
        read user_input
        
        # Use default if empty
        if [ -z "$user_input" ]; then
            export USER_NAMESPACE="default"
            break
        else
            export USER_NAMESPACE="$user_input"
            break
        fi
    done
fi

# Validate namespace exists
echo ""
echo "Validating namespace: $USER_NAMESPACE"

while true; do
    if kubectl get namespace "$USER_NAMESPACE" &>/dev/null; then
        echo "✓ Namespace '$USER_NAMESPACE' exists and is accessible"
        break
    else
        echo ""
        echo "✗ Namespace '$USER_NAMESPACE' does not exist or is not accessible"
        echo ""
        echo "Options:"
        echo "  1. Create the namespace: kubectl create namespace $USER_NAMESPACE"
        echo "  2. Press ENTER to use 'default' namespace instead"
        echo "  3. Type a different namespace name"
        echo ""
        printf "Choice [use default]: "
        read user_choice
        
        if [ -z "$user_choice" ]; then
            # Use default namespace
            export USER_NAMESPACE="default"
            echo "Switching to 'default' namespace..."
        else
            # Try the new namespace name
            export USER_NAMESPACE="$user_choice"
        fi
    fi
done

echo ""
echo "✓ Using namespace: $USER_NAMESPACE"
echo ""

echo "----------------------------------------------------------------------"
echo "------  Creating baseline deployment/values files  -------------------"
echo "----------------------------------------------------------------------"

# Set environment variables and source setup script
export OC_PROJECT=${USER_NAMESPACE}
./deployment-scripts/setup-workspace-env.sh

sed -i -e "s/export CLUSTER_URL=.*/export CLUSTER_URL=localhost/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export DEPLOYMENT_ENV=.*/export DEPLOYMENT_ENV=${DEPLOYMENT_ENV}/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
sed -i -e "s/export OC_PROJECT=.*/export OC_PROJECT=$OC_PROJECT/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

source workspace/${DEPLOYMENT_ENV}/env/env.sh

# Note: User namespace should already exist
# Operator namespace is created by install-operator.sh (requires cluster-admin)
echo "----------------------------------------------------------------------"
echo "Deploying to namespace: $USER_NAMESPACE"
echo "----------------------------------------------------------------------"

echo "----------------------------------------------------------------------"
echo "--------------------  Configuring Cluster Topology  ------------------"
echo "----------------------------------------------------------------------"

# Auto-detect node name based on cluster type
if [ "$CLUSTER_TYPE" = "lima" ]; then
    NODE_NAME="lima-studio"
elif [ "$CLUSTER_TYPE" = "crc" ]; then
    NODE_NAME=$(kubectl get nodes -o name | head -1 | cut -d'/' -f2)
else
    echo "Generic K8s cluster - skipping node labeling"
    NODE_NAME=""
fi

if [ -n "$NODE_NAME" ]; then
    kubectl label nodes $NODE_NAME topology.kubernetes.io/region=us-east-1 topology.kubernetes.io/zone=us-east-1a --overwrite
    echo "✓ Node labeled: $NODE_NAME"
else
    echo "⊘ Node labeling skipped"
fi

# Deploy MinIO
if [ "$DEPLOY_MINIO" = "true" ]; then
    echo "----------------------------------------------------------------------"
    echo "----------------------  Deploying MinIO  -----------------------------"
    echo "----------------------------------------------------------------------"

    openssl genrsa -out minio-private.key 2048
    sed -e "s/default/$OC_PROJECT/g" deployment-scripts/minio-openssl.conf > workspace/$DEPLOYMENT_ENV/initialisation/minio-user-openssl.conf
    openssl req -new -x509 -nodes -days 730 -keyout minio-private.key -out minio-public.crt --config workspace/$DEPLOYMENT_ENV/initialisation/minio-user-openssl.conf

    kubectl create secret tls minio-tls-secret --cert=minio-public.crt --key=minio-private.key -n ${OC_PROJECT} --dry-run=client -o yaml > workspace/$DEPLOYMENT_ENV/initialisation/minio-tls-secret.yaml
    kubectl label -f workspace/$DEPLOYMENT_ENV/initialisation/minio-tls-secret.yaml app.kubernetes.io/name=geostudio app.kubernetes.io/component=infrastructure --overwrite --local --dry-run=client -o yaml | kubectl apply -f -

    kubectl create configmap minio-public-config --from-file=minio-public.crt -n kube-system --dry-run=client -o yaml > workspace/$DEPLOYMENT_ENV/initialisation/minio-public-config.yaml
    kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-public-config.yaml -n kube-system

    python ./deployment-scripts/update-deployment-template.py --disable-route --filename deployment-scripts/minio-deployment.yaml > workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml || {
        echo "ERROR: Failed to generate MinIO deployment (Python dependencies missing?)"
        echo "Install: pip3 install --break-system-packages ibm-cos-sdk python-dotenv"
        exit 1
    }
    kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml -n ${OC_PROJECT}

    kubectl wait --for=condition=ready pod -l app=minio -n ${OC_PROJECT} --timeout=300s

    sleep 5
    kubectl port-forward -n ${OC_PROJECT} svc/minio 9001:9001 >> studio-pf.log 2>&1 &
    sleep 5

    # Update workspace with MinIO config
    sed -i -e "s/access_key_id=.*/access_key_id=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/secret_access_key=.*/secret_access_key=minioadmin/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s|endpoint=.*|endpoint=https://localhost:9000|g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/region=.*/region=us-east-1/g" workspace/${DEPLOYMENT_ENV}/env/.env

    kubectl port-forward -n ${OC_PROJECT} svc/minio 9000:9000 >> studio-pf.log 2>&1 &
    sleep 5

    python deployment-scripts/create_buckets.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env || {
        echo "WARNING: Bucket creation failed (Python dependencies?). Buckets may need manual creation."
    }

    # Update endpoint to cluster-internal
    sed -i -e "s|endpoint=.*|endpoint=https://minio.$OC_PROJECT.svc.cluster.local:9000|g" workspace/${DEPLOYMENT_ENV}/env/.env

    echo "✓ MinIO deployed successfully"
else
    echo "----------------------------------------------------------------------"
    echo "-------------------  Using External MinIO/S3  ------------------------"
    echo "----------------------------------------------------------------------"
    
    if [ -z "$EXTERNAL_MINIO_ENDPOINT" ] || [ -z "$EXTERNAL_MINIO_ACCESS_KEY" ] || [ -z "$EXTERNAL_MINIO_SECRET_KEY" ]; then
        echo "ERROR: EXTERNAL_MINIO_ENDPOINT, EXTERNAL_MINIO_ACCESS_KEY, EXTERNAL_MINIO_SECRET_KEY required when DEPLOY_MINIO=false"
        exit 1
    fi
    
    echo "Using external object storage: $EXTERNAL_MINIO_ENDPOINT"
    
    # Update workspace with external MinIO config
    sed -i -e "s/access_key_id=.*/access_key_id=${EXTERNAL_MINIO_ACCESS_KEY}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/secret_access_key=.*/secret_access_key=${EXTERNAL_MINIO_SECRET_KEY}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s|endpoint=.*|endpoint=${EXTERNAL_MINIO_ENDPOINT}|g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/region=.*/region=${EXTERNAL_MINIO_REGION:-us-east-1}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    
    echo "✓ External MinIO configured"
fi

# Install CSI Driver
echo "----------------------------------------------------------------------"
echo "----------------  Checking/Installing IBM CSI Driver  ----------------"
echo "----------------------------------------------------------------------"

if [ "$INSTALL_IBM_CSI_DRIVER" = "true" ]; then
    if kubectl get csidriver cos.s3.csi.ibm.io &>/dev/null; then
        echo "✓ IBM Object CSI Driver already installed, skipping installation"
    elif kubectl get storageclass cos-s3-csi-s3fs-sc &>/dev/null; then
        echo "✓ Storage class cos-s3-csi-s3fs-sc already exists, skipping CSI driver installation"
    else
        echo "Installing IBM Object CSI Driver..."
        cp -R deployment-scripts/ibm-object-csi-driver workspace/$DEPLOYMENT_ENV/initialisation
        sed -e "s/default/$OC_PROJECT/g" deployment-scripts/template/cos-s3-csi-s3fs-sc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-s3fs-sc.yaml
        sed -e "s/default/$OC_PROJECT/g" deployment-scripts/template/cos-s3-csi-sc.yaml > workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-sc.yaml
        kubectl apply -k workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/
        
        kubectl wait --for=condition=ready pod -l app=cos-s3-csi-controller -n kube-system --timeout=300s
        kubectl wait --for=condition=ready pod -l app=cos-s3-csi-driver -n kube-system --timeout=300s
        echo "✓ IBM Object CSI Driver installed successfully"
    fi
    
    sed -i -e "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=cos-s3-csi-s3fs-sc/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=local-path/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
else
    echo "IBM CSI Driver installation disabled (INSTALL_IBM_CSI_DRIVER=false)"
    echo "Note: Ensure an alternative S3-compatible storage class is available"
    
    sed -i -e "s/export COS_STORAGE_CLASS=.*/export COS_STORAGE_CLASS=local-path/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export NON_COS_STORAGE_CLASS=.*/export NON_COS_STORAGE_CLASS=local-path/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
fi

source workspace/${DEPLOYMENT_ENV}/env/env.sh

# Deploy PostgreSQL
if [ "$DEPLOY_POSTGRESQL" = "true" ]; then
    echo "----------------------------------------------------------------------"
    echo "--------------------  Deploying PostgreSQL  --------------------------"
    echo "----------------------------------------------------------------------"

    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update

    ./deployment-scripts/install-postgres.sh

    kubectl wait --for=condition=ready pod/postgresql-0 -n ${OC_PROJECT} --timeout=300s

    kubectl port-forward --namespace ${OC_PROJECT} svc/postgresql 54320:5432 >> studio-pf.log 2>&1 &
    sleep 5

    # Update workspace with local PostgreSQL config
    sed -i -e "s/pg_username=.*/pg_username=postgres/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/pg_password=.*/pg_password=${POSTGRES_PASSWORD}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/pg_uri=.*/pg_uri=127.0.0.1/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/pg_port=.*/pg_port=5432/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/pg_original_db_name=.*/pg_original_db_name='postgres'/g" workspace/${DEPLOYMENT_ENV}/env/.env

    # Create databases with fallback
    python deployment-scripts/create_studio_dbs.py --env-path workspace/${DEPLOYMENT_ENV}/env/.env || {
        echo "Python script failed, creating databases directly..."
        kubectl exec postgresql-0 -n ${OC_PROJECT} -- bash -c "
            PGPASSWORD=${POSTGRES_PASSWORD} psql -U postgres -c 'CREATE DATABASE geostudio;' 2>&1 | grep -v 'already exists' || true
            PGPASSWORD=${POSTGRES_PASSWORD} psql -U postgres -c 'CREATE DATABASE geostudio_auth;' 2>&1 | grep -v 'already exists' || true
            PGPASSWORD=${POSTGRES_PASSWORD} psql -U postgres -c 'CREATE DATABASE mlflow;' 2>&1 | grep -v 'already exists' || true
        "
        echo "✓ Databases created successfully"
    }

    # Update to cluster-internal URI
    sed -i -e "s/pg_uri=.*/pg_uri=postgresql.$OC_PROJECT.svc.cluster.local/g" workspace/${DEPLOYMENT_ENV}/env/.env

    echo "✓ PostgreSQL deployed successfully"
else
    echo "----------------------------------------------------------------------"
    echo "------------------  Using External PostgreSQL  -----------------------"
    echo "----------------------------------------------------------------------"
    
    if [ -z "$EXTERNAL_POSTGRES_HOST" ] || [ -z "$EXTERNAL_POSTGRES_USER" ] || [ -z "$EXTERNAL_POSTGRES_PASSWORD" ]; then
        echo "ERROR: EXTERNAL_POSTGRES_HOST, EXTERNAL_POSTGRES_USER, EXTERNAL_POSTGRES_PASSWORD required when DEPLOY_POSTGRESQL=false"
        exit 1
    fi
    
    echo "Using external PostgreSQL: $EXTERNAL_POSTGRES_HOST"
    
    # Update workspace with external PostgreSQL config
    sed -i -e "s/pg_username=.*/pg_username=${EXTERNAL_POSTGRES_USER}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/pg_password=.*/pg_password=${EXTERNAL_POSTGRES_PASSWORD}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/pg_uri=.*/pg_uri=${EXTERNAL_POSTGRES_HOST}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/pg_port=.*/pg_port=${EXTERNAL_POSTGRES_PORT:-5432}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/pg_original_db_name=.*/pg_original_db_name='${EXTERNAL_POSTGRES_DB:-postgres}'/g" workspace/${DEPLOYMENT_ENV}/env/.env
    
    echo ""
    echo "⚠️  IMPORTANT: You must manually create these databases in your PostgreSQL:"
    echo "    - geostudio"
    echo "    - geostudio_auth"
    echo "    - mlflow"
    echo ""
    
    echo "✓ External PostgreSQL configured"
fi

source workspace/${DEPLOYMENT_ENV}/env/env.sh

# Deploy Keycloak
if [ "$DEPLOY_KEYCLOAK" = "true" ]; then
    echo "----------------------------------------------------------------------"
    echo "--------------------  Deploying Keycloak  ----------------------------"
    echo "----------------------------------------------------------------------"

    python ./deployment-scripts/update-keycloak-deployment.py --disable-route --filename deployment-scripts/keycloak-deployment.yaml --env-path workspace/${DEPLOYMENT_ENV}/env/.env > workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml || {
        echo "ERROR: Failed to generate Keycloak deployment (Python dependencies missing?)"
        echo "Install: pip3 install --break-system-packages python-dotenv"
        exit 1
    }
    kubectl apply -f workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml -n ${OC_PROJECT}

    kubectl wait --for=condition=ready pod -l app=keycloak -n ${OC_PROJECT} --timeout=300s

    kubectl port-forward -n ${OC_PROJECT} svc/keycloak 8080:8080 >> studio-pf.log 2>&1 &
    sleep 5

    export client_secret=`cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32`
    export cookie_secret=`cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32`

    ./deployment-scripts/setup-keycloak.sh

    sed -i -e "s/oauth_client_secret=.*/oauth_client_secret=$client_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s|export OAUTH_URL=.*|export OAUTH_URL=http://keycloak.$OC_PROJECT.svc.cluster.local:8080/realms/geostudio/protocol/openid-connect/auth|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

    echo "✓ Keycloak deployed successfully"
else
    echo "----------------------------------------------------------------------"
    echo "------------------  Using External Keycloak  -------------------------"
    echo "----------------------------------------------------------------------"
    
    if [ -z "$EXTERNAL_KEYCLOAK_URL" ]; then
        echo "ERROR: EXTERNAL_KEYCLOAK_URL required when DEPLOY_KEYCLOAK=false"
        exit 1
    fi
    
    echo "Using external Keycloak: $EXTERNAL_KEYCLOAK_URL"
    
    # Generate cookie secret if not provided
    export cookie_secret=${EXTERNAL_KEYCLOAK_COOKIE_SECRET:-$(cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c32)}
    
    if [ -z "$EXTERNAL_KEYCLOAK_CLIENT_SECRET" ]; then
        echo "ERROR: EXTERNAL_KEYCLOAK_CLIENT_SECRET required when DEPLOY_KEYCLOAK=false"
        exit 1
    fi
    
    sed -i -e "s/oauth_client_secret=.*/oauth_client_secret=${EXTERNAL_KEYCLOAK_CLIENT_SECRET}/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/oauth_cookie_secret=.*/oauth_cookie_secret=$cookie_secret/g" workspace/${DEPLOYMENT_ENV}/env/.env
    sed -i -e "s/export OAUTH_TYPE=.*/export OAUTH_TYPE=keycloak/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export OAUTH_CLIENT_ID=.*/export OAUTH_CLIENT_ID=geostudio-client/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s|export OAUTH_ISSUER_URL=.*|export OAUTH_ISSUER_URL=${EXTERNAL_KEYCLOAK_URL}/realms/geostudio|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s|export OAUTH_URL=.*|export OAUTH_URL=${EXTERNAL_KEYCLOAK_URL}/realms/geostudio/protocol/openid-connect/auth|g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    sed -i -e "s/export OAUTH_PROXY_PORT=.*/export OAUTH_PROXY_PORT=4180/g" workspace/${DEPLOYMENT_ENV}/env/env.sh
    
    echo "✓ External Keycloak configured"
fi

echo "----------------------------------------------------------------------"
echo "--------------------  Updating Other Values  -------------------------"
echo "----------------------------------------------------------------------"

# Generate TLS certificates for OAuth proxy
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=$OC_PROJECT.svc.cluster.local"

export TLS_CRT_B64=$(openssl base64 -in tls.crt -A)
export TLS_KEY_B64=$(openssl base64 -in tls.key -A)

sed -i -e "s/tls_crt_b64=.*/tls_crt_b64=$TLS_CRT_B64/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/tls_key_b64=.*/tls_key_b64=$TLS_KEY_B64/g" workspace/${DEPLOYMENT_ENV}/env/.env
sed -i -e "s/export CREATE_TLS_SECRET=.*/export CREATE_TLS_SECRET=true/g" workspace/${DEPLOYMENT_ENV}/env/env.sh

echo "----------------------------------------------------------------------"
echo "Infrastructure Setup Complete"
echo "----------------------------------------------------------------------"

# Generate API keys
file=./.studio-api-key
if [ -e "$file" ]; then
    source $file
else 
    export STUDIO_API_KEY=$(echo "pak-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)")
    export API_ENCRYPTION_KEY=$(echo "$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')")
    echo "export STUDIO_API_KEY=$STUDIO_API_KEY" > ./.studio-api-key
    echo "export API_ENCRYPTION_KEY=$API_ENCRYPTION_KEY" >> ./.studio-api-key
fi

# Update final workspace values
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

echo ""
echo "======================================================================"
echo "  Infrastructure Setup Complete!"
echo "======================================================================"
echo ""
echo "Deployed Components:"
[ "$DEPLOY_MINIO" = "true" ] && echo "  ✓ MinIO (object storage) - namespace: $USER_NAMESPACE" || echo "  ⊘ MinIO (using external: ${EXTERNAL_MINIO_ENDPOINT})"
[ "$DEPLOY_POSTGRESQL" = "true" ] && echo "  ✓ PostgreSQL (database) - namespace: $USER_NAMESPACE" || echo "  ⊘ PostgreSQL (using external: ${EXTERNAL_POSTGRES_HOST})"
[ "$DEPLOY_KEYCLOAK" = "true" ] && echo "  ✓ Keycloak (authentication) - namespace: $USER_NAMESPACE" || echo "  ⊘ Keycloak (using external: ${EXTERNAL_KEYCLOAK_URL})"
[ "$INSTALL_IBM_CSI_DRIVER" = "true" ] && echo "  ✓ IBM CSI Driver - namespace: kube-system" || echo "  ⊘ IBM CSI Driver (disabled)"
echo ""
echo "Configuration:"
echo "  Cluster Type: $CLUSTER_TYPE"
echo "  Environment: $DEPLOYMENT_ENV"
echo "  Namespace: $USER_NAMESPACE"
echo "  Workspace: workspace/${DEPLOYMENT_ENV}/"
echo ""
echo "Credentials:"
echo "  Studio API Key: $STUDIO_API_KEY"
[ "$DEPLOY_POSTGRESQL" = "true" ] && echo "  Postgres Password: $POSTGRES_PASSWORD"
[ "$DEPLOY_KEYCLOAK" = "true" ] && echo "  Keycloak Client Secret: <in workspace/${DEPLOYMENT_ENV}/env/.env (oauth_client_secret)>"
echo ""
echo "Next Steps:"
echo "  Deploy GEOStudio application:"
echo "    ./operators/scripts/deploy-geostudio.sh"
echo ""
echo "  Or with a custom CR:"
echo "    ./operators/scripts/deploy-geostudio.sh path/to/my-geostudio.yaml"
echo ""
