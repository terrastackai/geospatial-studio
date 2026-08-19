#!/usr/bin/env bash
#
# load-airgap-images.sh — run on the AIR-GAPPED host.
#
# Imports every image archive in the staging dir into the Lima VM's k3s
# containerd store (the k8s.io namespace kubelet uses). On a fresh VM this is
# usually unnecessary — studio.yaml provisioning auto-imports on boot — but this
# is useful to load newly-added archives into an already-running VM without a
# reboot, or to recover if auto-import didn't run.
#
# Usage:
#   deployment-scripts/airgap/load-airgap-images.sh [VM_NAME] [STAGING_DIR_IN_GUEST]
# Defaults: VM_NAME=studio, STAGING_DIR_IN_GUEST=/data/airgap-images
set -euo pipefail

VM_NAME="${1:-studio}"
GUEST_DIR="${2:-/data/airgap-images}"

command -v limactl >/dev/null 2>&1 || { echo "ERROR: limactl not found"; exit 1; }

echo "==> VM: $VM_NAME   staging dir (in guest): $GUEST_DIR"

# List archives visible inside the guest
mapfile -t ARCHIVES < <(limactl shell "$VM_NAME" sh -c \
  "ls $GUEST_DIR/*.tar $GUEST_DIR/*.tar.gz $GUEST_DIR/*.tar.zst 2>/dev/null" || true)

if [ "${#ARCHIVES[@]}" -eq 0 ]; then
  echo "No image archives found in $GUEST_DIR (inside VM). Nothing to import."
  exit 0
fi

echo "==> Found ${#ARCHIVES[@]} archive(s):"; printf '   %s\n' "${ARCHIVES[@]}"

for a in "${ARCHIVES[@]}"; do
  echo "==> importing $a"
  case "$a" in
    *.tar.zst)
      # k3s ctr import doesn't decompress zst; pipe through zstd
      limactl shell "$VM_NAME" sh -c "zstd -dc '$a' | sudo k3s ctr -n k8s.io images import -" \
        || echo "   WARN: failed to import $a"
      ;;
    *)
      limactl shell "$VM_NAME" sudo k3s ctr -n k8s.io images import "$a" \
        || echo "   WARN: failed to import $a"
      ;;
  esac
done

# Bitnami charts request "registry-1.docker.io/..." but images import as "docker.io/...".
# Alias so imagePullPolicy=IfNotPresent finds them offline. Idempotent.
echo "==> aliasing docker.io/* -> registry-1.docker.io/* for chart ref matching"
limactl shell "$VM_NAME" sudo sh -c '
for ref in $(k3s ctr -n k8s.io images ls -q | grep "^docker.io/" | grep -v "@sha256:"); do
  k3s ctr -n k8s.io images tag "$ref" "registry-1.docker.io/${ref#docker.io/}" >/dev/null 2>&1 || true
done'

echo "==> Done. Named images now in the store:"
limactl shell "$VM_NAME" sudo k3s ctr -n k8s.io images ls -q | grep -v '@sha256:' | sort
