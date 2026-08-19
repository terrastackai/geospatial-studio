#!/usr/bin/env bash
#
# build-airgap-bundle.sh — run on a CONNECTED arm64 machine (Apple Silicon).
#
# Produces the complete offline bundle for the air-gapped Lima/k3s deploy:
#   - k3s system images        (k3s-airgap-images-<arch>.tar.zst, from GitHub release)
#   - CSI driver + sidecars     (csi-sidecars-<arch>.tar,     via podman)
#   - studio "extra" images     (studio-extra-images-<arch>.tar, via podman)
#   - application images        (studio-app-images-<arch>.tar,   via podman)
#   - Helm chart dependencies   (geospatial-studio/charts/*.tgz)
#
# See AIRGAP-CHANGES.md and AIRGAP-DEPLOY-RUNBOOK.md for background.
#
# Usage:
#   deployment-scripts/airgap/build-airgap-bundle.sh [OUTPUT_DIR]
# Default OUTPUT_DIR: ~/studio-data/airgap-images
set -euo pipefail

# ---- config -----------------------------------------------------------------
ARCH="${ARCH:-arm64}"
PLATFORM="linux/${ARCH}"
K3S_VERSION="${K3S_VERSION:-v1.30.2+k3s1}"
# The pod-sandbox (pause) image the k3s BINARY expects. It MUST match your k3s
# version's containerd sandbox_image (check with:
#   grep sandbox_image /var/lib/rancher/k3s/agent/etc/containerd/config.toml ).
# The official k3s-airgap-images tarball sometimes carries a different pause
# version, so we stage this one explicitly (tagged both docker.io and
# registry-1.docker.io) — otherwise k3s pulls it from the internet and the whole
# cluster fails to create pod sandboxes offline.
K3S_PAUSE_IMAGE="${K3S_PAUSE_IMAGE:-rancher/mirrored-pause:3.6}"
REDIS_CHART_VERSION="${REDIS_CHART_VERSION:-20.4.0}"
OUTPUT_DIR="${1:-$HOME/studio-data/airgap-images}"

# Resolve repo root (this script lives in deployment-scripts/airgap/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHART_DIR="$REPO_ROOT/geospatial-studio"

CSI_SIDECARS=(
  registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.13.0
  registry.k8s.io/sig-storage/csi-provisioner:v5.2.0
  registry.k8s.io/sig-storage/livenessprobe:v2.16.0
  quay.io/containerstorage/ibm-object-csi-driver:v0.1.19
)
STUDIO_EXTRA=(
  docker.io/library/postgres:13
  docker.io/bitnamilegacy/redis:7.4.1-debian-12-r2
  docker.io/bitnamilegacy/pgbouncer:latest
  docker.io/alpine/curl:latest
  docker.io/library/busybox:1.36
  docker.io/library/busybox:latest   # gateway job wait-for-gateway init container default
)
APP_IMAGES=(
  quay.io/minio/minio:latest
  docker.osgeo.org/geoserver:2.28.1
  quay.io/keycloak/keycloak:26.4.5
  docker.io/bitnamilegacy/postgresql:latest
  docker.io/bitnamilegacy/redis:latest
  ghcr.io/mlflow/mlflow:latest
  docker.io/bitnamilegacy/oauth2-proxy:latest
  docker.io/bitnamilegacy/kubectl:latest
  docker.io/bitnamilegacy/os-shell:latest
  docker.io/linuxserver/yq:latest
  quay.io/geospatial-studio/geostudio-gateway:latest
  quay.io/geospatial-studio/geostudio-pipelines:latest
  quay.io/geospatial-studio/geostudio-ui:latest
  quay.io/geospatial-studio/terratorch:latest
)
LOCAL_SUBCHARTS=(gfm-mlflow gfm-studio-gateway geofm-ui geospatial-studio-pipelines pgbouncer)

# ---- helpers ----------------------------------------------------------------
log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' not found in PATH"; exit 1; }; }

pull_and_save() { # <output.tar> <image...>
  local out="$1"; shift
  local img
  for img in "$@"; do
    echo "  pulling $img"
    podman pull --platform "$PLATFORM" "$img"
  done
  echo "  saving -> $out"
  podman save --multi-image-archive -o "$out" "$@"
}

# ---- preflight --------------------------------------------------------------
need podman
need helm
need curl
podman machine start >/dev/null 2>&1 || true
mkdir -p "$OUTPUT_DIR"
log "Output dir: $OUTPUT_DIR   (arch=$ARCH, k3s=$K3S_VERSION)"

# ---- 1. k3s system images ---------------------------------------------------
log "1/5  k3s system images (k3s-airgap-images-${ARCH}.tar.zst)"
curl -fL -o "$OUTPUT_DIR/k3s-airgap-images-${ARCH}.tar.zst" \
  "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images-${ARCH}.tar.zst"

# Guard: the bundle's pause version MUST match the pause the k3s binary expects
# (K3S_PAUSE_IMAGE). A mismatch means K3S_VERSION doesn't match your k3s binary,
# and the offline cluster will fail to create pod sandboxes. Verify before continuing.
if command -v zstd >/dev/null 2>&1; then
  want_pause="${K3S_PAUSE_IMAGE##*:}"
  got_pause="$(zstd -dc "$OUTPUT_DIR/k3s-airgap-images-${ARCH}.tar.zst" 2>/dev/null \
    | tar -xO manifest.json 2>/dev/null | grep -oE 'mirrored-pause:[0-9.]+' | head -1 | cut -d: -f2)"
  if [ -n "$got_pause" ] && [ "$got_pause" != "$want_pause" ]; then
    echo "ERROR: k3s airgap bundle contains pause:$got_pause but k3s ${K3S_VERSION} expects pause:$want_pause." >&2
    echo "       The bundle version does not match the k3s binary you deploy with." >&2
    echo "       Set K3S_VERSION (and K3S_PAUSE_IMAGE) to match your k3s binary and re-run." >&2
    echo "       Check the binary's expectation with:" >&2
    echo "         grep sandbox_image /var/lib/rancher/k3s/agent/etc/containerd/config.toml" >&2
    exit 1
  fi
  echo "  bundle pause:${got_pause:-unknown} matches k3s ${K3S_VERSION} (expects pause:$want_pause) ✓"
else
  echo "  WARN: 'zstd' not found — skipping bundle/k3s pause-version match check"
fi

# ---- 2. CSI sidecars (with k8s.gcr.io retag) --------------------------------
log "2/5  CSI driver + sidecars (csi-sidecars-${ARCH}.tar)"
for img in "${CSI_SIDECARS[@]}"; do
  echo "  pulling $img"; podman pull --platform "$PLATFORM" "$img"
done
# retag the two the manifests request under the deprecated k8s.gcr.io name
podman tag registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.13.0 k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.13.0
podman tag registry.k8s.io/sig-storage/csi-provisioner:v5.2.0            k8s.gcr.io/sig-storage/csi-provisioner:v5.2.0
podman save --multi-image-archive -o "$OUTPUT_DIR/csi-sidecars-${ARCH}.tar" \
  k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.13.0 \
  k8s.gcr.io/sig-storage/csi-provisioner:v5.2.0 \
  registry.k8s.io/sig-storage/livenessprobe:v2.16.0 \
  quay.io/containerstorage/ibm-object-csi-driver:v0.1.19

# ---- 3. studio extra images -------------------------------------------------
log "3/5  studio extra images (studio-extra-images-${ARCH}.tar)"
pull_and_save "$OUTPUT_DIR/studio-extra-images-${ARCH}.tar" "${STUDIO_EXTRA[@]}"

# ---- 4. application images --------------------------------------------------
log "4/5  application images (studio-app-images-${ARCH}.tar)"
pull_and_save "$OUTPUT_DIR/studio-app-images-${ARCH}.tar" "${APP_IMAGES[@]}"

# ---- 5. Helm chart bundle ---------------------------------------------------
log "5/5  Helm chart dependencies -> $CHART_DIR/charts/"
for c in "${LOCAL_SUBCHARTS[@]}"; do
  echo "  packaging $c"
  helm package "$CHART_DIR/charts/$c" -d "$CHART_DIR/charts/" >/dev/null
done
echo "  pulling redis $REDIS_CHART_VERSION"
helm pull "oci://registry-1.docker.io/bitnamicharts/redis" --version "$REDIS_CHART_VERSION" -d "$CHART_DIR/charts/"

# Verify every dependency is vendored in charts/ (this is the offline requirement).
# NOTE: do NOT `helm template` the bare chart here — it fails redis's architecture
# validation because that value only comes from the deploy-time values file. The
# real check is simply that all dependency .tgz are present.
echo "  verifying vendored chart dependencies"
missing=0
for dep in gfm-mlflow gfm-studio-gateway geofm-ui geospatial-studio-pipelines pgbouncer redis; do
  if ls "$CHART_DIR"/charts/${dep}-*.tgz >/dev/null 2>&1; then
    echo "    ✓ $dep"
  else
    echo "    ✗ MISSING dependency: $dep" >&2; missing=1
  fi
done
[ "$missing" -eq 0 ] && echo "  charts OK (all deps vendored)" || { echo "  ERROR: missing chart deps" >&2; exit 1; }

# ---- summary ----------------------------------------------------------------
log "DONE. Bundle contents:"
ls -lh "$OUTPUT_DIR"/*.tar "$OUTPUT_DIR"/*.tar.zst 2>/dev/null
echo
echo "Next: copy the repo (with geospatial-studio/charts/*.tgz) and the contents of"
echo "  $OUTPUT_DIR"
echo "to the air-gapped host's ~/studio-data/airgap-images/, then follow AIRGAP-DEPLOY-RUNBOOK.md Part 3+."
