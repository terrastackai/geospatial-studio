#!/usr/bin/env bash
#
# load-airgap-images.sh — run on the AIR-GAPPED host(s). Linux only.
#
# Loads the .tar / .tar.zst bundles produced by build-airgap-bundle.sh into
# whatever container runtime is actually running the cluster:
#   - kind       -> `kind load image-archive` (loads into every kind node
#                    container automatically — no ssh, no manual containerd
#                    calls; this is the mode you want for a local kind cluster)
#   - k3s        -> k3s's embedded containerd, via `k3s ctr images import`
#   - containerd -> via `ctr -n k8s.io images import` (needs sudo/root)
#   - docker     -> via `docker load` (only works if the cluster's kubelet
#                    is actually configured to use the Docker/cri-dockerd
#                    runtime — most modern clusters use containerd directly)
#
# Works for three topologies:
#   kind   - local kind cluster (single- or multi-node). `kind load
#            image-archive` pushes each tar into every node container in
#            the named cluster for you — this replaces both "local" and
#            "remote" modes for kind.
#   local  - single bare-metal/VM node (or you're running this ON each
#            node yourself). Images are imported directly into the local
#            runtime.
#   remote - multi-node bare-metal/VM cluster. Copies each bundle to every
#            node in NODES_FILE via scp and runs the same import remotely
#            via ssh. Requires passwordless SSH (key-based) to each node as
#            a user that can reach the runtime socket (or sudo without a
#            password prompt).
#
# Usage:
#   ./load-airgap-images.sh --mode kind [--cluster-name kind]
#   ./load-airgap-images.sh --mode local
#   ./load-airgap-images.sh --mode remote --nodes ./nodes.txt --user ubuntu
#
# Env overrides:
#   BUNDLE_DIR    Directory containing the *.tar / *.tar.zst bundles
#                 (default: ~/studio-data/airgap-images)
#   RUNTIME       Force runtime detection: k3s | containerd | docker
#   CLUSTER_NAME  kind cluster name for --mode kind (default: kind)
#   SSH_KEY       Path to SSH private key for remote mode (optional,
#                 default uses ssh-agent / default key)
#   REMOTE_DIR    Scratch dir on remote nodes to stage tarballs
#                 (default: /tmp/airgap-images)
set -euo pipefail

BUNDLE_DIR="${BUNDLE_DIR:-$HOME/studio-data/airgap-images}"
REMOTE_DIR="${REMOTE_DIR:-/tmp/airgap-images}"
MODE=""
NODES_FILE=""
SSH_USER="${SSH_USER:-}"
RUNTIME="${RUNTIME:-}"
CLUSTER_NAME="${CLUSTER_NAME:-kind}"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }

# ---- arg parsing --------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --nodes) NODES_FILE="$2"; shift 2 ;;
    --user) SSH_USER="$2"; shift 2 ;;
    --bundle-dir) BUNDLE_DIR="$2"; shift 2 ;;
    --runtime) RUNTIME="$2"; shift 2 ;;
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,33p' "$0"; exit 0 ;;
    *) err "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$MODE" ]; then
  err "Must pass --mode local|remote"
  exit 1
fi

if [ ! -d "$BUNDLE_DIR" ]; then
  err "Bundle dir not found: $BUNDLE_DIR (set BUNDLE_DIR or --bundle-dir)"
  exit 1
fi

# Collect bundle files up front so both modes share the same list.
mapfile -t BUNDLE_FILES < <(find "$BUNDLE_DIR" -maxdepth 1 -type f \( -name '*.tar' -o -name '*.tar.zst' \) | sort)
if [ "${#BUNDLE_FILES[@]}" -eq 0 ]; then
  err "No .tar/.tar.zst files found in $BUNDLE_DIR"
  exit 1
fi
log "Found ${#BUNDLE_FILES[@]} bundle file(s) in $BUNDLE_DIR:"
printf '  - %s\n' "${BUNDLE_FILES[@]##*/}"

# ---- runtime detection (used for local mode; remote mode detects per-node) --
detect_runtime() {
  if [ -n "$RUNTIME" ]; then
    echo "$RUNTIME"; return
  fi
  if command -v k3s >/dev/null 2>&1; then
    echo "k3s"; return
  fi
  if command -v ctr >/dev/null 2>&1 && [ -S /run/containerd/containerd.sock ]; then
    echo "containerd"; return
  fi
  if command -v docker >/dev/null 2>&1; then
    echo "docker"; return
  fi
  echo "unknown"
}

# ---- import one bundle into the local runtime ---------------------------
# args: <runtime> <file>
import_one() {
  local rt="$1" f="$2" tmp=""
  case "$f" in
    *.tar.zst)
      command -v zstd >/dev/null 2>&1 || { err "zstd not installed, needed to decompress $f"; return 1; }
      tmp="$(mktemp)"
      zstd -dc "$f" > "$tmp"
      f_to_load="$tmp"
      ;;
    *)
      f_to_load="$f"
      ;;
  esac

  case "$rt" in
    k3s)
      # k3s ships its own ctr wrapper pointed at the embedded containerd.
      sudo k3s ctr images import "$f_to_load"
      ;;
    containerd)
      sudo ctr -n k8s.io images import "$f_to_load"
      ;;
    docker)
      docker load -i "$f_to_load"
      ;;
    *)
      err "Could not detect a supported runtime (k3s/containerd/docker) and none was forced with --runtime"
      [ -n "$tmp" ] && rm -f "$tmp"
      return 1
      ;;
  esac

  [ -n "$tmp" ] && rm -f "$tmp"
}

# ---- kind mode --------------------------------------------------------------
# `kind load image-archive` loads a docker/OCI tar into every node container
# in the named kind cluster in one shot — it's kind's own tool for exactly
# this job, so we don't touch ctr/docker or ssh at all here.
run_kind() {
  command -v kind >/dev/null 2>&1 || { err "'kind' CLI not found in PATH"; exit 1; }

  if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
    err "No kind cluster named '$CLUSTER_NAME' found. Existing clusters:"
    kind get clusters 2>/dev/null || echo "  (none)"
    err "Pass --cluster-name <name> if it's not called '$CLUSTER_NAME'."
    exit 1
  fi
  log "Loading into kind cluster: $CLUSTER_NAME"

  for f in "${BUNDLE_FILES[@]}"; do
    local load_file="$f" tmp=""
    case "$f" in
      *.tar.zst)
        command -v zstd >/dev/null 2>&1 || { err "zstd not installed, needed to decompress $f"; exit 1; }
        tmp="$(mktemp)"
        zstd -dc "$f" > "$tmp"
        load_file="$tmp"
        ;;
    esac
    log "kind load image-archive $(basename "$f")"
    kind load image-archive "$load_file" --name "$CLUSTER_NAME"
    [ -n "$tmp" ] && rm -f "$tmp"
  done
  log "kind import complete — images are now on every node in '$CLUSTER_NAME'."
}

# ---- local mode -----------------------------------------------------------
run_local() {
  local rt
  rt="$(detect_runtime)"
  log "Detected runtime: $rt"
  if [ "$rt" = "unknown" ]; then
    err "No supported runtime found. Install/start k3s, containerd, or docker, or pass --runtime explicitly."
    exit 1
  fi

  for f in "${BUNDLE_FILES[@]}"; do
    log "Importing $(basename "$f") into $rt ..."
    import_one "$rt" "$f"
  done
  log "Local import complete."
}

# ---- remote mode ------------------------------------------------------------
run_remote() {
  if [ -z "$NODES_FILE" ] || [ ! -f "$NODES_FILE" ]; then
    err "Remote mode requires --nodes <file> (one hostname/IP per line)"
    exit 1
  fi
  if [ -z "$SSH_USER" ]; then
    err "Remote mode requires --user <ssh-user>"
    exit 1
  fi

  local ssh_opts=(-o StrictHostKeyChecking=accept-new)
  [ -n "${SSH_KEY:-}" ] && ssh_opts+=(-i "$SSH_KEY")

  mapfile -t NODES < <(grep -v '^\s*#' "$NODES_FILE" | grep -v '^\s*$')
  if [ "${#NODES[@]}" -eq 0 ]; then
    err "No nodes listed in $NODES_FILE"
    exit 1
  fi
  log "Distributing to ${#NODES[@]} node(s): ${NODES[*]}"

  # Remote runtime-detect + import snippet, run once per node.
  # shellcheck disable=SC2016
  local remote_import_script='
    set -e
    RT="__FORCED_RUNTIME__"
    if [ -z "$RT" ]; then
      if command -v k3s >/dev/null 2>&1; then RT=k3s
      elif command -v ctr >/dev/null 2>&1 && [ -S /run/containerd/containerd.sock ]; then RT=containerd
      elif command -v docker >/dev/null 2>&1; then RT=docker
      else echo "no supported runtime found on $(hostname)" >&2; exit 1
      fi
    fi
    echo "  [$(hostname)] using runtime: $RT"
    for f in "'"$REMOTE_DIR"'"/*.tar "'"$REMOTE_DIR"'"/*.tar.zst; do
      [ -e "$f" ] || continue
      load="$f"
      case "$f" in
        *.tar.zst)
          command -v zstd >/dev/null 2>&1 || { echo "zstd missing on $(hostname)" >&2; exit 1; }
          tmp="$(mktemp)"; zstd -dc "$f" > "$tmp"; load="$tmp"
          ;;
      esac
      echo "  [$(hostname)] importing $(basename "$f")"
      case "$RT" in
        k3s)        sudo k3s ctr images import "$load" ;;
        containerd) sudo ctr -n k8s.io images import "$load" ;;
        docker)     docker load -i "$load" ;;
      esac
      [ "$load" != "$f" ] && rm -f "$load"
    done
  '
  remote_import_script="${remote_import_script/__FORCED_RUNTIME__/$RUNTIME}"

  for node in "${NODES[@]}"; do
    log "Node: $node"
    echo "  staging bundles -> $REMOTE_DIR"
    ssh "${ssh_opts[@]}" "${SSH_USER}@${node}" "mkdir -p '$REMOTE_DIR'"
    scp "${ssh_opts[@]}" "${BUNDLE_FILES[@]}" "${SSH_USER}@${node}:${REMOTE_DIR}/"
    echo "  running import on $node"
    ssh "${ssh_opts[@]}" "${SSH_USER}@${node}" "bash -s" <<< "$remote_import_script"
    ssh "${ssh_opts[@]}" "${SSH_USER}@${node}" "rm -rf '$REMOTE_DIR'"
  done
  log "Remote import complete on all nodes."
}

# ---- main -------------------------------------------------------------------
case "$MODE" in
  kind)   run_kind ;;
  local)  run_local ;;
  remote) run_remote ;;
  *) err "Unknown --mode '$MODE' (expected: kind|local|remote)"; exit 1 ;;
esac

log "Done. Verify with e.g.:"
if [ "$MODE" = "kind" ]; then
  echo "  docker exec ${CLUSTER_NAME}-control-plane crictl images | grep geospatial-studio"
else
  echo "  sudo k3s ctr images ls | grep geospatial-studio      # k3s"
  echo "  sudo ctr -n k8s.io images ls | grep geospatial-studio # containerd"
  echo "  docker images | grep geospatial-studio                # docker"
fi