#!/bin/bash

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
get_user_input "Provide a name for the deployment environment, maybe cluster name e.g. fmaas-dev, cimf-staging, rosa-prod, local... This will be the name used for a local folder created under workspace directory." deployment_env
echo "DEPLOYMENT_ENV accepted: **$deployment_env**"
export DEPLOYMENT_ENV=$deployment_env

typeset namespace
get_user_input "For uninstall. Provide the namespace/project name: " namespace
echo "OC_PROJECT accepted: **$namespace**"
export OC_PROJECT=$namespace

oc project $OC_PROJECT

# kill all forwarded ports
# Define the list of ports
PORTS=(3000 8080 54320)

for PORT in "${PORTS[@]}"
do
  echo "Attempting to kill processes on port $PORT"
  # Find PIDs and kill them
  PIDS=$(lsof -t -i:"$PORT")

  if [ -z "$PIDS" ]; then
    echo "No processes found running on port $PORT"
  else
    # Use 'kill -9' for forceful termination if needed
    # kill -9 $PIDS
    # Use 'kill' for a graceful termination
    kill -9 $PIDS
    echo "Killed processes: $PIDS on port $PORT"
  fi
done

helm uninstall studio

kubectl delete pvc redis-data-geofm-redis-master-0 -n $OC_PROJECT
kubectl delete pvc redis-data-geofm-redis-replicas-0 -n $OC_PROJECT

kubectl delete -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-with-initial-data.yaml -n $OC_PROJECT

kubectl delete -f workspace/$DEPLOYMENT_ENV/initialisation/populate-buckets-default-pvc.yaml -n $OC_PROJECT

kubectl delete -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver-deployment.yaml -n $OC_PROJECT

kubectl delete -f workspace/$DEPLOYMENT_ENV/initialisation/geoserver_docker_secret.yaml -n $OC_PROJECT

kubectl delete -f workspace/$DEPLOYMENT_ENV/initialisation/keycloak-deployment.yaml -n $OC_PROJECT

helm uninstall postgresql

kubectl delete -f workspace/$DEPLOYMENT_ENV/initialisation/create_postgres_local_pvc.yaml -n $OC_PROJECT

kubectl delete -f workspace/$DEPLOYMENT_ENV/initialisation/minio-deployment.yaml -n $OC_PROJECT
