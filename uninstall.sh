#!/bin/bash

# Source common functions if available
if [ -f ./common_functions.sh ]; then
    source ./common_functions.sh
fi

# get_user_input
get_user_input() {
    local prompt_msg="$1"
    local result_var_name="$2"
    local input=""

    while [[ -z "$input" ]]; do
        printf "%s\n" "$prompt_msg"

        read -r input

        if [[ -z "$input" ]]; then
            echo "Error: Input cannot be blank. Please try again."
        fi
    done
    eval "$result_var_name='$input'"
}

typeset deployment_env
get_user_input "Provide a name for the deployment environment, maybe cluster name e.g. fmaas-dev, cimf-staging, rosa-prod, lima, local... This will be the name used for a local folder created under workspace directory." deployment_env
echo "DEPLOYMENT_ENV accepted: **$deployment_env**"
export DEPLOYMENT_ENV=$deployment_env

# Get namespace with default value
echo "For uninstall. Provide the namespace/project name (default: default): "
read -r namespace

# Use default if empty
if [[ -z "$namespace" ]]; then
    namespace="default"
    echo "Using default namespace: $namespace"
fi

echo "OC_PROJECT accepted: **$namespace**"
export OC_PROJECT=$namespace

# Set KUBECONFIG for Lima deployments
if [[ "$DEPLOYMENT_ENV" == "lima" ]]; then
    export KUBECONFIG="$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml"
    echo "Using Lima KUBECONFIG: $KUBECONFIG"
fi

# Use kubectl for all operations (works with both OpenShift and Kubernetes)
KUBECTL_CMD="kubectl"

# Check if we're in OpenShift environment
if command -v oc &> /dev/null; then
    echo "OpenShift CLI detected, using 'oc' command"
    KUBECTL_CMD="oc"
    $KUBECTL_CMD project $OC_PROJECT 2>/dev/null || echo "Note: Could not switch to project $OC_PROJECT"
else
    echo "Using kubectl command"
fi

echo "----------------------------------------------------------------------"
echo "--------------------  Killing Port Forwards  -------------------------"
echo "----------------------------------------------------------------------"

# Kill all forwarded ports used by deploy_studio_lima.sh
PORTS=(3000 4180 4181 5000 8080 9000 9001 54320)

for PORT in "${PORTS[@]}"
do
  echo "Attempting to kill processes on port $PORT"
  # Find PIDs and kill them
  PIDS=$(lsof -t -i:"$PORT" 2>/dev/null)

  if [ -z "$PIDS" ]; then
    echo "No processes found running on port $PORT"
  else
    kill -9 $PIDS 2>/dev/null
    echo "Killed processes: $PIDS on port $PORT"
  fi
done

# Also kill any remaining studio-pf.log related processes
pkill -f "studio-pf.log" 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "--------------------  Uninstalling Helm Releases  --------------------"
echo "----------------------------------------------------------------------"

# Uninstall Geospatial Studio
echo "Uninstalling Geospatial Studio..."
helm uninstall studio -n $OC_PROJECT 2>/dev/null || echo "Studio helm release not found or already uninstalled"

# Wait for Studio pods to terminate
echo "Waiting for Studio pods to terminate..."
$KUBECTL_CMD wait --for=delete pod -l app.kubernetes.io/instance=studio -n $OC_PROJECT --timeout=300s 2>/dev/null || echo "No Studio pods found or timeout reached"

# Uninstall PostgreSQL
echo "Uninstalling PostgreSQL..."
helm uninstall postgresql -n $OC_PROJECT 2>/dev/null || echo "PostgreSQL helm release not found or already uninstalled"

# Wait for PostgreSQL pods to terminate
echo "Waiting for PostgreSQL pods to terminate..."
$KUBECTL_CMD wait --for=delete pod -l app.kubernetes.io/name=postgresql -n $OC_PROJECT --timeout=300s 2>/dev/null || echo "No PostgreSQL pods found or timeout reached"

echo "----------------------------------------------------------------------"
<<<<<<< HEAD
<<<<<<< HEAD
echo "--------------------  Deleting Deployments  --------------------------"
echo "----------------------------------------------------------------------"

# Delete Geoserver
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml" ]; then
    echo "Deleting Geoserver..."
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n $OC_PROJECT 2>/dev/null || echo "Geoserver not found"
fi

# Delete Keycloak
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml" ]; then
    echo "Deleting Keycloak..."
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml -n $OC_PROJECT 2>/dev/null || echo "Keycloak not found"
fi

# Delete MinIO
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml" ]; then
    echo "Deleting MinIO..."
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml -n $OC_PROJECT 2>/dev/null || echo "MinIO not found"
fi

echo "----------------------------------------------------------------------"
echo "--------------------  Deleting Jobs and Pods  ------------------------"
echo "----------------------------------------------------------------------"

# Delete populate buckets jobs/pods
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-with-initial-data.yaml" ]; then
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-with-initial-data.yaml -n $OC_PROJECT 2>/dev/null || echo "Populate buckets job not found"
fi

if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-default-pvc.yaml" ]; then
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-default-pvc.yaml -n $OC_PROJECT 2>/dev/null || echo "Populate buckets PVC job not found"
fi

# Delete any remaining jobs
echo "Deleting all Studio-related jobs..."
$KUBECTL_CMD delete jobs -l app.kubernetes.io/instance=studio -n $OC_PROJECT 2>/dev/null || echo "No Studio jobs with label found"

# Delete jobs by name pattern (for jobs without the label)
$KUBECTL_CMD get jobs -n $OC_PROJECT -o name | grep -E "(geofm-|gfm-|gateway-)" | xargs -r $KUBECTL_CMD delete -n $OC_PROJECT 2>/dev/null || echo "No additional Studio jobs found"
=======
echo "--------------------  Deleting PVCs  ---------------------------------"
echo "----------------------------------------------------------------------"

# Delete Redis PVCs
$KUBECTL_CMD delete pvc redis-data-geofm-redis-master-0 -n $OC_PROJECT 2>/dev/null || echo "Redis master PVC not found"
$KUBECTL_CMD delete pvc redis-data-geofm-redis-replicas-0 -n $OC_PROJECT 2>/dev/null || echo "Redis replica PVC not found"

# Delete PostgreSQL PVC
$KUBECTL_CMD delete pvc data-postgresql-0 -n $OC_PROJECT 2>/dev/null || echo "PostgreSQL PVC not found"

# Delete all Studio-related PVCs
echo "Deleting all Studio-related PVCs..."
$KUBECTL_CMD get pvc -n $OC_PROJECT -o name | grep -E "(gfm-|geofm-|inference-|generic-)" | xargs -r $KUBECTL_CMD delete -n $OC_PROJECT 2>/dev/null || echo "No additional Studio PVCs found"

echo "----------------------------------------------------------------------"
=======
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
echo "--------------------  Deleting Deployments  --------------------------"
echo "----------------------------------------------------------------------"

# Delete Geoserver
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml" ]; then
    echo "Deleting Geoserver..."
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n $OC_PROJECT 2>/dev/null || echo "Geoserver not found"
fi

# Delete Keycloak
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml" ]; then
    echo "Deleting Keycloak..."
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml -n $OC_PROJECT 2>/dev/null || echo "Keycloak not found"
fi

# Delete MinIO
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml" ]; then
    echo "Deleting MinIO..."
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml -n $OC_PROJECT 2>/dev/null || echo "MinIO not found"
fi

echo "----------------------------------------------------------------------"
echo "--------------------  Deleting Jobs and Pods  ------------------------"
echo "----------------------------------------------------------------------"

# Delete populate buckets jobs/pods
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-with-initial-data.yaml" ]; then
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-with-initial-data.yaml -n $OC_PROJECT 2>/dev/null || echo "Populate buckets job not found"
fi

if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-default-pvc.yaml" ]; then
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-default-pvc.yaml -n $OC_PROJECT 2>/dev/null || echo "Populate buckets PVC job not found"
fi

# Delete any remaining jobs
<<<<<<< HEAD
$KUBECTL_CMD delete jobs -l app.kubernetes.io/instance=studio -n $OC_PROJECT 2>/dev/null || echo "No Studio jobs found"
>>>>>>> 1d5df52 (♻️ refactor(uninstall): enhance cleanup script for reliable resource removal)
=======
echo "Deleting all Studio-related jobs..."
$KUBECTL_CMD delete jobs -l app.kubernetes.io/instance=studio -n $OC_PROJECT 2>/dev/null || echo "No Studio jobs with label found"

# Delete jobs by name pattern (for jobs without the label)
$KUBECTL_CMD get jobs -n $OC_PROJECT -o name | grep -E "(geofm-|gfm-|gateway-)" | xargs -r $KUBECTL_CMD delete -n $OC_PROJECT 2>/dev/null || echo "No additional Studio jobs found"
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)

echo "----------------------------------------------------------------------"
echo "--------------------  Deleting Secrets  ------------------------------"
echo "----------------------------------------------------------------------"

# Delete MinIO TLS secret
$KUBECTL_CMD delete secret minio-tls-secret -n $OC_PROJECT 2>/dev/null || echo "MinIO TLS secret not found"

# Delete Studio secrets
$KUBECTL_CMD delete secret geofm-gateway-secrets -n $OC_PROJECT 2>/dev/null || echo "Gateway secrets not found"
$KUBECTL_CMD delete secret geofm-gateway-jobs-secrets -n $OC_PROJECT 2>/dev/null || echo "Gateway jobs secrets not found"
$KUBECTL_CMD delete secret geofm-gateway-cos-secret -n $OC_PROJECT 2>/dev/null || echo "Gateway COS secret not found"
$KUBECTL_CMD delete secret geoft-cronjob-secrets -n $OC_PROJECT 2>/dev/null || echo "Cronjob secrets not found"
$KUBECTL_CMD delete secret auth-seed -n $OC_PROJECT 2>/dev/null || echo "Auth seed secret not found"
$KUBECTL_CMD delete secret studio-cos-secret -n $OC_PROJECT 2>/dev/null || echo "COS secret not found"
$KUBECTL_CMD delete secret us-icr-pull-secret -n $OC_PROJECT 2>/dev/null || echo "Image pull secret not found"

# Delete Geoserver docker secret
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/geoserver_docker_secret.yaml" ]; then
    $KUBECTL_CMD delete -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver_docker_secret.yaml -n $OC_PROJECT 2>/dev/null || echo "Geoserver docker secret not found"
fi

# Delete all Studio-related secrets
echo "Deleting all Studio-related secrets..."
$KUBECTL_CMD get secrets -n $OC_PROJECT -o name | grep -E "(geofm-|gfm-|geoft-)" | xargs -r $KUBECTL_CMD delete -n $OC_PROJECT 2>/dev/null || echo "No additional Studio secrets found"

echo "----------------------------------------------------------------------"
echo "--------------------  Deleting ConfigMaps  ---------------------------"
echo "----------------------------------------------------------------------"

# Delete MinIO public config from kube-system
$KUBECTL_CMD delete configmap minio-public-config -n kube-system 2>/dev/null || echo "MinIO public config not found in kube-system"

# Delete Studio ConfigMaps
$KUBECTL_CMD delete configmap geofm-gateway-cm -n $OC_PROJECT 2>/dev/null || echo "Gateway ConfigMap not found"
$KUBECTL_CMD delete configmap geofm-gateway-seed-data -n $OC_PROJECT 2>/dev/null || echo "Gateway seed data ConfigMap not found"
$KUBECTL_CMD delete configmap geofm-mlflow-run-trigger -n $OC_PROJECT 2>/dev/null || echo "MLflow trigger ConfigMap not found"
$KUBECTL_CMD delete configmap geofm-gateway-sandbox-models -n $OC_PROJECT 2>/dev/null || echo "Sandbox models ConfigMap not found"

# Delete any remaining Studio ConfigMaps
$KUBECTL_CMD delete configmaps -l app.kubernetes.io/instance=studio -n $OC_PROJECT 2>/dev/null || echo "No additional Studio ConfigMaps found"

echo "----------------------------------------------------------------------"
echo "--------------------  Deleting RBAC Resources  -----------------------"
echo "----------------------------------------------------------------------"

# Delete RoleBinding
$KUBECTL_CMD delete rolebinding api-gateway-sa-rb -n $OC_PROJECT 2>/dev/null || echo "API gateway RoleBinding not found"
$KUBECTL_CMD delete rolebinding gateway-service-role-binding -n $OC_PROJECT 2>/dev/null || echo "Gateway service RoleBinding not found"

# Delete Role
$KUBECTL_CMD delete role api-gateway-sa-role -n $OC_PROJECT 2>/dev/null || echo "API gateway Role not found"
$KUBECTL_CMD delete role gateway-service-account -n $OC_PROJECT 2>/dev/null || echo "Gateway service Role not found"

# Delete ServiceAccount
$KUBECTL_CMD delete serviceaccount api-gateway-sa -n $OC_PROJECT 2>/dev/null || echo "API gateway ServiceAccount not found"

# Delete any remaining Studio RBAC resources
$KUBECTL_CMD delete rolebindings -l app.kubernetes.io/instance=studio -n $OC_PROJECT 2>/dev/null || echo "No additional Studio RoleBindings found"
$KUBECTL_CMD delete roles -l app.kubernetes.io/instance=studio -n $OC_PROJECT 2>/dev/null || echo "No additional Studio Roles found"
$KUBECTL_CMD delete serviceaccounts -l app.kubernetes.io/instance=studio -n $OC_PROJECT 2>/dev/null || echo "No additional Studio ServiceAccounts found"

echo "----------------------------------------------------------------------"
echo "--------------------  Deleting CSI Driver (Lima)  --------------------"
echo "----------------------------------------------------------------------"

# Delete IBM Object CSI Driver (for Lima deployments)
if [ -f "workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/cos-s3-csi-s3fs-sc.yaml" ]; then
    echo "Deleting IBM Object CSI Driver..."
    $KUBECTL_CMD delete -k workspace/$DEPLOYMENT_ENV/initialisation/ibm-object-csi-driver/ 2>/dev/null || echo "CSI driver not found or already deleted"
fi

echo "----------------------------------------------------------------------"
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
echo "--------------------  Deleting PVCs  ---------------------------------"
echo "----------------------------------------------------------------------"

# Delete Redis PVCs
$KUBECTL_CMD delete pvc redis-data-geofm-redis-master-0 -n $OC_PROJECT 2>/dev/null || echo "Redis master PVC not found"
$KUBECTL_CMD delete pvc redis-data-geofm-redis-replicas-0 -n $OC_PROJECT 2>/dev/null || echo "Redis replica PVC not found"

# Delete PostgreSQL PVC
$KUBECTL_CMD delete pvc data-postgresql-0 -n $OC_PROJECT 2>/dev/null || echo "PostgreSQL PVC not found"

# Delete all Studio-related PVCs
echo "Deleting all Studio-related PVCs..."
$KUBECTL_CMD get pvc -n $OC_PROJECT -o name | grep -E "(gfm-|geofm-|inference-|generic-)" | xargs -r $KUBECTL_CMD delete -n $OC_PROJECT 2>/dev/null || echo "No additional Studio PVCs found"

echo "----------------------------------------------------------------------"
<<<<<<< HEAD
=======
>>>>>>> 1d5df52 (♻️ refactor(uninstall): enhance cleanup script for reliable resource removal)
=======
>>>>>>> b566d2e (✨ feat(pgbouncer): add isolated connection pools to prevent service starvation)
echo "--------------------  Removing Node Labels  --------------------------"
echo "----------------------------------------------------------------------"

# Remove node labels (for Lima)
if [[ "$DEPLOYMENT_ENV" == "lima" ]]; then
    echo "Removing node labels from lima-studio..."
    $KUBECTL_CMD label nodes lima-studio topology.kubernetes.io/region- topology.kubernetes.io/zone- 2>/dev/null || echo "Node labels not found or already removed"
fi

echo "----------------------------------------------------------------------"
echo "--------------------  Cleanup Complete  ------------------------------"
echo "----------------------------------------------------------------------"

echo ""
echo "✅ Uninstall complete for deployment: $DEPLOYMENT_ENV in namespace: $OC_PROJECT"
echo ""
echo "Note: The following items were NOT deleted and may need manual cleanup:"
echo "  - Workspace directory: workspace/$DEPLOYMENT_ENV/"
echo "  - Generated certificates: tls.key, tls.crt, minio-private.key, minio-public.crt"
echo "  - API key file: .studio-api-key"
