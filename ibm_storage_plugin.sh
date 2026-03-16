# uninstall
helm uninstall ibm-object-storage-plugin -n ibm-object-s3fs
helm plugin uninstall ibmc

# label node
oc label nodes crc topology.kubernetes.io/region=us-east --overwrite
oc label nodes crc topology.kubernetes.io/zone=us-east --overwrite
oc label nodes crc ibm-cloud.kubernetes.io/region=us-east --overwrite

# install ibm storage plugin & sample pvc
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
helm fetch --untar ibm-helm/ibm-object-storage-plugin
helm plugin install ./ibm-object-storage-plugin/helm-ibmc
helm ibmc install ibm-object-storage-plugin ibm-helm/ibm-object-storage-plugin --set license=true --set workerOS="redhat" --set region="us-east"

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca-bundle
  namespace: ibm-object-s3fs
  annotations:
    service.beta.openshift.io/inject-cabundle: "true"
data: {} # Leave this empty; OpenShift will populate it automatically
EOF


oc set volume deployment/ibmcloud-object-storage-plugin \
    --add \
    --name=ca-bundle-vol \
    --type=configmap \
    --configmap-name=trusted-ca-bundle \
    --mount-path=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    --read-only=true \
    --sub-path=service-ca.crt


# changes required in crc vm
# get required variables
MINIO_CLUSTER_IP=$(oc get svc minio -o jsonpath='{.spec.clusterIP}')
MINIO_INTERNAL_URL="minio.geostudio.svc.cluster.local"
export LOCAL_CA_CRT=$(oc get configmap trusted-ca-bundle -n ibm-object-s3fs -o jsonpath='{.data.service-ca\.crt}')

cat deployment-scripts/crc-hosts-modifier-daemonset.yaml | sed -e "s/\$MINIO_CLUSTER_IP/$MINIO_CLUSTER_IP/g" | sed -e "s/\$MINIO_INTERNAL_URL/$MINIO_INTERNAL_URL/g" > workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml

auto_indent_and_replace() {
  local template_file="$1"
  local var_name="$2"
  local content="$3"
  local output_file="$4"

  # find the line with the variable and extract its indentation
  local indent=$(grep "\$$var_name" "$template_file" | sed "s/\$$var_name.*//" | head -1)

  # Add indentation to all lines EXPECT the first line
  local indented_content=$(echo "$content" | awk -v indent="$indent" 'NR==1 {print; next} {print indent $0}')


  # Export and replace
  export "$var_name"="$indented_content"
  envsubst "\$$var_name" < "$template_file" > "$output_file"
}

auto_indent_and_replace workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml SELF_CA_CRT "$LOCAL_CA_CRT" workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset.yaml
rm workspace/$DEPLOYMENT_ENV/initialisation/crc-hosts-modifier-daemonset-tmp.yaml


# Manual option
# ssh into crc vm
# ssh -i ~/.crc/machines/crc/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 core@127.0.0.1
# add entries to /etc/hosts
# get the cluster ip
# echo "$CLUSTER_IP minio.default.svc.cluster.local" | sudo tee -a /etc/hosts > /dev/null
# update ca; append tls-ca-bundle.pem with self signed ca.crt which we set in the deployment/ibmcloud-object-storage-plugin
# path to ca.crt for updating /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
# echo "$SELF_CA_CRT" >> /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem


# Test cos volume on pod; You should already have your cos storage
kubectl apply -f - <<EOF
kind: Secret
apiVersion: v1
metadata:
  name: cos-write-access-x
  namespace: geostudio
data:
  access-key: bWluaW9hZG1pbg==
  secret-key: bWluaW9hZG1pbg==
type: ibm/ibmc-s3fs
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: example-pvc-x # Enter the name of the PVC.
  namespace: geostudio # Enter the namespace where you want to create the PVC. The PVC must be created in the same namespace where you created the Kubernetes secret for your service credentials and where you want to run your pod.
  annotations:
    ibm.io/region: "us-east"
    ibm.io/auto-create-bucket: "false"
    ibm.io/auto-delete-bucket: "false"
    ibm.io/bucket: "testing"
    ibm.io/quota-limit: "true" # Disable or enable a quota limit for your PVC. To use this annotation you must specify the -set quotaLimit=true option during installation.
    ibm.io/endpoint: "https://minio.default.svc.cluster.local:9000"
    ibm.io/tls-cipher-suite: "default"
    ibm.io/secret-name: "cos-write-access-x" # The name of your Kubernetes secret that you created. 
    ibm.io/secret-namespace: "default" # By default, the COS plug-in searches for your secret in the same namespace where you create the PVC. If you created your secret in a namespace other than the namespace where you want to create your PVC, enter the namespace where you created your secret.
    # ibm.io/add-mount-param: "<option-1>,<option-2>" # s3fs mount options
    # ibm.io/access-policy-allowed-ips: "XX.XXX.XX.XXX, XX.XX.XX.XXX, XX.XX.XX.XX" # A csv of allow listed IPs.
    # ibm.io/bucket-versioning: "false" # Set to true to enable bucket versioning.
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ibmc-s3fs-cos
EOF
