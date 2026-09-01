#!/bin/bash

# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0
#
# deploy_studio_kind.sh — one-command AIR-GAPPED deploy of Geospatial Studio onto a
# local kind (Kubernetes-in-Docker) cluster. Run this on the OFFLINE target host.
#
# It performs the kind equivalent of the Lima/k3s air-gap prep, then hands off to the
# existing deploy_studio_k8s.sh (driven non-interactively):
#   1. load the kind node image and create the cluster (if missing)
#   2. `kind load` every image archive in the bundle into the cluster's containerd
#   3. alias docker.io/* -> registry-1.docker.io/* so Bitnami charts resolve offline
#   4. preflight that key images are present, then deploy with STORAGE_MODE=local-hostpath
#
# Build the bundle on a CONNECTED amd64 host first:
#   TARGET=kind ARCH=amd64 ./deployment-scripts/airgap/build-airgap-bundle.sh
# then copy the repo (with geospatial-studio/charts/*.tgz) and the bundle dir to this host.
# See KIND-AIRGAP-RUNBOOK.md.
set -euo pipefail

# ---- config (override via env) ----------------------------------------------
AIRGAP_DIR="${AIRGAP_DIR:-$HOME/studio-data/airgap-images}"
KIND_CLUSTER="${KIND_CLUSTER:-studio}"
ARCH="${ARCH:-amd64}"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found in PATH"; }

# ---- preflight: tools + bundle ----------------------------------------------
need docker; need kind; need kubectl; need helm
[ -d "$AIRGAP_DIR" ] || die "bundle dir not found: $AIRGAP_DIR (build it on a connected host; see KIND-AIRGAP-RUNBOOK.md)"

NODE_TAR="$AIRGAP_DIR/kind-node-${ARCH}.tar"
NODE_IMG_FILE="$AIRGAP_DIR/kind-node-image.txt"
[ -f "$NODE_TAR" ]      || die "missing $NODE_TAR"
[ -f "$NODE_IMG_FILE" ] || die "missing $NODE_IMG_FILE (records the kindest/node image tag)"
NODE_IMG="$(cat "$NODE_IMG_FILE")"
[ -n "$NODE_IMG" ]      || die "empty node image tag in $NODE_IMG_FILE"

# ---- 1. load node image + create cluster (idempotent) -----------------------
if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER"; then
  log "kind cluster '$KIND_CLUSTER' already exists — reusing it"
else
  log "Loading kind node image ($NODE_IMG) and creating cluster '$KIND_CLUSTER'"
  docker load -i "$NODE_TAR"
  cat <<EOF | kind create cluster --name "$KIND_CLUSTER" --image "$NODE_IMG" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
EOF
fi
kubectl cluster-info --context "kind-${KIND_CLUSTER}" >/dev/null || die "cannot reach cluster kind-${KIND_CLUSTER}"

# ---- 2. load every image archive into the cluster's containerd --------------
# Everything except the node image itself (that goes into docker, not the node store).
log "Loading image archives from $AIRGAP_DIR into cluster '$KIND_CLUSTER'"
shopt -s nullglob
loaded=0
for tar in "$AIRGAP_DIR"/*.tar; do
  case "$(basename "$tar")" in
    kind-node-*.tar) continue ;;   # node image, already docker-loaded above
  esac
  echo "  kind load image-archive $(basename "$tar")"
  kind load image-archive "$tar" --name "$KIND_CLUSTER"
  loaded=$((loaded+1))
done
shopt -u nullglob
[ "$loaded" -gt 0 ] || die "no image archives (*.tar) found in $AIRGAP_DIR"

# ---- 3. alias docker.io/* -> registry-1.docker.io/* in every node -----------
# Bitnami charts request the registry-1.docker.io form, but archives import as
# docker.io/*; containerd matches by literal ref, so with imagePullPolicy=IfNotPresent
# the chart's ref isn't found and the pod tries to pull (fails offline). Idempotent.
log "Aliasing docker.io/* -> registry-1.docker.io/* in cluster nodes"
for node in $(kind get nodes --name "$KIND_CLUSTER"); do
  docker exec "$node" bash -c '
    for ref in $(ctr -n k8s.io images ls -q | grep "^docker.io/" | grep -v "@sha256:"); do
      ctr -n k8s.io images tag "$ref" "registry-1.docker.io/${ref#docker.io/}" >/dev/null 2>&1 || true
    done'
done

# ---- 4. preflight: key images must be in the store --------------------------
log "Preflight: verifying key images are present in the node image store"
CP_NODE="${KIND_CLUSTER}-control-plane"
store_refs="$(docker exec "$CP_NODE" ctr -n k8s.io images ls -q 2>/dev/null || true)"
missing=0
for want in keycloak minio geoserver geostudio-gateway geostudio-ui redis postgresql; do
  if grep -q "$want" <<<"$store_refs"; then
    echo "  ✓ $want"
  else
    echo "  ✗ MISSING: $want" >&2; missing=1
  fi
done
[ "$missing" -eq 0 ] || die "one or more required images are not staged — rebuild/transfer the bundle (see KIND-AIRGAP-RUNBOOK.md troubleshooting)"

# ---- 5. hand off to the (non-interactive, air-gapped) k8s deploy ------------
# PostgreSQL offline overrides: install from the vendored chart tgz with pinned image
# tags so imagePullPolicy=IfNotPresent matches the staged tags. postgres-tags.env is
# written by the bundle builder; fall back to bundle-relative defaults if absent.
export AIRGAP=true
export NON_INTERACTIVE=true
export STORAGE_MODE="${STORAGE_MODE:-local-hostpath}"

PG_TGZ="$(ls "$AIRGAP_DIR"/postgresql-*.tgz 2>/dev/null | head -1 || true)"
[ -n "$PG_TGZ" ] && export PG_CHART="$PG_TGZ"
[ -f "$AIRGAP_DIR/postgres-tags.env" ] && source "$AIRGAP_DIR/postgres-tags.env"
export PG_IMAGE_TAG="${PG_IMAGE_TAG:-}"
export PG_OSSHELL_TAG="${PG_OSSHELL_TAG:-}"

log "Handing off to deploy_studio_k8s.sh (AIRGAP, non-interactive, STORAGE_MODE=$STORAGE_MODE)"
echo "  PG_CHART=${PG_CHART:-<online>}  PG_IMAGE_TAG=${PG_IMAGE_TAG:-<chart default>}"
exec ./deploy_studio_k8s.sh
