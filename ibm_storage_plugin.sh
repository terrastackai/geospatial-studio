# install ibm storage plugin & sample pvc
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
helm fetch --untar ibm-helm/ibm-object-storage-plugin
helm plugin install ./ibm-object-storage-plugin/helm-ibmc
helm ibmc install ibm-object-storage-plugin ibm-helm/ibm-object-storage-plugin --set license=true --set workerOS="linux" --set region="us-east-1"

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


kubectl apply -f - <<EOF
kind: Secret
apiVersion: v1
metadata:
  name: cos-write-access-x
  namespace: default
data:
  access-key: bWluaW9hZG1pbg==
  secret-key: bWluaW9hZG1pbg==
type: ibm/ibmc-s3fs
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: example-pvc-x # Enter the name of the PVC.
  namespace: default # Enter the namespace where you want to create the PVC. The PVC must be created in the same namespace where you created the Kubernetes secret for your service credentials and where you want to run your pod.
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
