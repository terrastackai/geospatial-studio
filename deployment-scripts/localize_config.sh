# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


config_name=$1
echo $config_name

sed -i -e "s|http://geofm-mlflow.${OC_PROJECT}.svc.cluster.local:5000/|http://localhost:5000/|g" ${config_name}
sed -i -e "s|/geotunes/tune-tasks|${HOME}/studio-data/ft-files-pvc/tune-tasks|g" ${config_name}
sed -i -e "s|/ft-data/|${HOME}/studio-data/ft-data-pvc|g" ${config_name}