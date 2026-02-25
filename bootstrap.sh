#!/usr/bin/env bash
set -euo pipefail

# -------- Pins ---------------------------------------------------------------
LIMA_VERSION="1.2.1"
HELM_VERSION="3.19.0"

# Canonical pinned locations (repo-scoped usage)
PINNED_BIN_DIR="/usr/local/geospatial-studio/bin"
PINNED_LIMACTL="${PINNED_BIN_DIR}/limactl"
PINNED_HELM="${PINNED_BIN_DIR}/helm"
PINNED_LIMA="${PINNED_BIN_DIR}/lima"


# -------- Functions ----------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1; }

ensure_homebrew_path() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  if ! need brew; then
    echo "⛔️ ERROR: Homebrew not found in PATH."
    echo "⚠️ Install Homebrew and rerun bootstrap.sh."
    exit 1
  fi
}

mac_resource_check() {
  echo "== Resource Check (Mac) =="

  local cpu mem_bytes mem_gb
  cpu="$(sysctl -n hw.ncpu)"
  mem_bytes="$(sysctl -n hw.memsize)"
  mem_gb="$(python3 - <<PY
print(round(int("$mem_bytes")/1024/1024/1024, 2))
PY
)"

  echo "CPU cores : $cpu"
  echo "RAM (GB)  : $mem_gb"

  python3 - <<PY
if int("$cpu") < 4:
  raise SystemExit("ERROR: Need >=4 CPU cores.")
if float("$mem_gb") < 8:
  raise SystemExit("ERROR: Need >=8GB RAM.")
print("OK: Host meets minimum requirements.")
PY
  echo
}

install_brew_tools() {
  echo "== Toolchain install (Homebrew) =="
  brew update

  # Brew-installed tools used by repo scripts + developer workflow.
  # NOTE: gettext provides envsubst; openssl@3 is requested for repo-local tooling.
  brew install jq yq k9s openshift-cli gettext direnv openssl@3

  # Keep envsubst available on PATH for general use.
  brew link --force gettext

  echo
}

install_repo_tools_symlinks() {
  echo "== Repo-local tool shims (.tools/bin) =="

  mkdir -p .tools/bin

  # Helper: symlink <formula> <src_rel_bin> <dest_name>
  # Uses brew --prefix to avoid hardcoding /opt/homebrew paths.
  link_bin() {
    local formula="$1"
    local src_rel="$2"
    local dest="$3"

    local prefix
    prefix="$(brew --prefix "$formula" 2>/dev/null || true)"
    if [[ -z "$prefix" ]]; then
      echo "⚠️  brew --prefix failed for $formula; skipping $dest"
      return 0
    fi

    local src="$prefix/$src_rel"
    if [[ ! -x "$src" ]]; then
      echo "⚠️  Missing executable: $src ; skipping $dest"
      return 0
    fi

    ln -sf "$src" ".tools/bin/$dest"
    echo "✅ .tools/bin/$dest -> $src"
  }

  link_bin jq            "bin/jq"        "jq"
  link_bin yq            "bin/yq"        "yq"
  link_bin k9s           "bin/k9s"       "k9s"
  link_bin openshift-cli "bin/oc"        "oc"
  link_bin direnv        "bin/direnv"    "direnv"
  link_bin gettext       "bin/envsubst"  "envsubst"
  link_bin openssl@3     "bin/openssl"   "openssl"

  echo
  echo "ℹ If your .envrc prepends .tools/bin, these will win in this repo:"
  echo "    PATH=\"\$(pwd)/.tools/bin:\$PATH\""
  echo
}

install_direnv_hooks() {
  echo "== direnv shell hooks (bash) =="

  if ! need direnv; then
    echo "⚠️  direnv not found on PATH; skipping hook installation."
    echo
    return 0
  fi

  local bashrc="$HOME/.bashrc"

  # Block markers specifying what GEO Studio installed
  local begin_marker="# >>> geospatial-studio direnv hook >>>"
  local end_marker="# <<< geospatial-studio direnv hook <<<"

  ensure_block() {
    local file="$1"
    local hook_line="$2"

    # Create file if missing
    if [[ ! -f "$file" ]]; then
      touch "$file"
    fi

    # If already present anywhere (even outside our block), do nothing.
    if grep -qF "$hook_line" "$file"; then
      echo "✅ Hook already present in $(basename "$file")"
      return 0
    fi

    # If our block exists, insert hook inside it (before end marker).
    if grep -qF "$begin_marker" "$file" && grep -qF "$end_marker" "$file"; then
      awk -v hook="$hook_line" -v end="$end_marker" '
        $0 == end { print hook }
        { print }
      ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
      echo "✅ Added hook inside existing block in $(basename "$file")"
      return 0
    fi

    # Otherwise append a new block.
    {
      echo
      echo "$begin_marker"
      echo "$hook_line"
      echo "$end_marker"
    } >> "$file"

    echo "✅ Added hook block to $(basename "$file")"
  }

  ensure_block "$bashrc" 'eval "$(direnv hook bash)"'

  echo
  echo "ℹ️  To apply in current shells:"
  echo "  bash: exec bash -l"
  echo
}

ensure_pinned_bin_dir() {
  if [[ ! -d "$PINNED_BIN_DIR" ]]; then
    echo "== Creating pinned bin dir =="
    sudo mkdir -p "$PINNED_BIN_DIR"
    sudo chmod 0755 "$PINNED_BIN_DIR"
    echo
  fi
}

install_lima_pinned() {
  echo "== Lima (pinned v${LIMA_VERSION}) =="

  if [[ -x "$PINNED_LIMACTL" ]]; then
    local current
    current="$("$PINNED_LIMACTL" --version | awk '{print $3}')"
    if [[ "$current" == "$LIMA_VERSION" ]]; then
      echo "✅ limactl already pinned at ${LIMA_VERSION}"
      echo
      return
    fi
  fi

  echo "⬇️  Installing Lima ${LIMA_VERSION} via tarball."

  local tmpdir url
  tmpdir="$(mktemp -d)"
  url="https://github.com/lima-vm/lima/releases/download/v${LIMA_VERSION}/lima-${LIMA_VERSION}-Darwin-arm64.tar.gz"

  curl -fL -o "$tmpdir/lima.tgz" "$url"
  tar -xzf "$tmpdir/lima.tgz" -C "$tmpdir"

  local limactl_bin lima_bin
  limactl_bin="$(find "$tmpdir" -type f -name limactl | head -n 1 || true)"
  lima_bin="$(find "$tmpdir" -type f -name lima | head -n 1 || true)"

  if [[ -z "$limactl_bin" || -z "$lima_bin" ]]; then
    echo "⛔️ ERROR: Could not find limactl/lima binaries in extracted archive."
    echo "Try: tar -tzf \"$tmpdir/lima.tgz\" | head -n 60"
    rm -rf "$tmpdir"
    exit 1
  fi

  sudo install -m 0755 "$limactl_bin" "$PINNED_LIMACTL"
  sudo install -m 0755 "$lima_bin" "$PINNED_LIMA"

  sudo mkdir -p /usr/local/share
  sudo rsync -a "$tmpdir/share/" /usr/local/share/

  sudo mkdir -p /usr/local/share/lima

  if [[ ! -f /usr/local/share/lima/lima-guestagent.Linux-aarch64.gz ]]; then
    echo "⛔️ ERROR: Lima guestagent gzip not found after installing share assets:"
    echo "    /usr/local/share/lima/lima-guestagent.Linux-aarch64.gz"
    echo "Check the archive contents with:"
    echo "  tar -tzf \"$tmpdir/lima.tgz\" | grep -n 'guestagent' | head"
    rm -rf "$tmpdir"
    exit 1
  fi

  sudo gunzip -c /usr/local/share/lima/lima-guestagent.Linux-aarch64.gz \
    | sudo tee /usr/local/share/lima/lima-guestagent.Linux-aarch64 >/dev/null

  sudo chmod 0755 /usr/local/share/lima/lima-guestagent.Linux-aarch64

  rm -rf "$tmpdir"

  echo -n "limactl (pinned): " && "$PINNED_LIMACTL" --version
  echo
}

install_helm_pinned() {
  echo "== Helm (pinned v${HELM_VERSION}) =="

  if [[ -x "$PINNED_HELM" ]]; then
    local current
    current="$("$PINNED_HELM" version --short | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
    if [[ "$current" == "$HELM_VERSION" ]]; then
      echo "✅ Helm already pinned at ${HELM_VERSION}"
      echo
      return
    fi
  fi

  echo "⬇️  Installing helm ${HELM_VERSION} via tarball."

  local tmpdir url
  tmpdir="$(mktemp -d)"
  url="https://get.helm.sh/helm-v${HELM_VERSION}-darwin-arm64.tar.gz"

  curl -fL -o "$tmpdir/helm.tgz" "$url"
  tar -xzf "$tmpdir/helm.tgz" -C "$tmpdir"

  sudo install -m 0755 "$tmpdir/darwin-arm64/helm" "$PINNED_HELM"

  rm -rf "$tmpdir"

  "$PINNED_HELM" version --short
  echo
}

ensure_repo_envrc() {
  echo "== Repo direnv (.envrc) =="

  local envrc=".envrc"
  local begin="# >>> geospatial-studio pinned tools >>>"
  local end="# <<< geospatial-studio pinned tools <<<"

  [[ -f "$envrc" ]] || touch "$envrc"

  if grep -qF "$begin" "$envrc" && grep -qF "$end" "$envrc"; then
    echo "✅ .envrc already has pinned-tools block"
    echo
    return 0
  fi

  cat >> "$envrc" <<EOF

$begin
# Use pinned toolchain inside this repo.
# Supercedes exisiting pre-installed applications with different versions of required tools used by GEO Studio.
PATH_add "$PINNED_BIN_DIR"

# Optional: load repo-local env if present (kept generic)
# source_if_exists "workspace/\${DEPLOYMENT_ENV}/env/.env"

$end
EOF

  echo "✅ Added pinned-tools block to .envrc"
  echo
  echo "Next (one-time): direnv allow"
  echo
}

# Required for use of IPV4 instead of the standard IPV6, used by lima defacto.
prefetch_lima_images_ipv4() {
  echo "== Prefetch Lima images (IPv4 curl) =="

  local yaml="deployment-scripts/lima/studio.yaml"
  if [[ ! -f "$yaml" ]]; then
    echo "⚠️  studio.yaml not found at $yaml; skipping image prefetch."
    echo
    return 0
  fi

  local locations
  locations="$(awk '
    $1 ~ /^images:$/ {in_images=1; next}
    in_images && $1 ~ /^base:$/ {in_images=0}
    in_images && $1 ~ /^location:/ {print $2}
    in_images && $1 ~ /^-$/ && $2 ~ /^location:/ {print $3}
  ' "$yaml" | sed -E 's/^"|"$//g')"

  if [[ -z "$locations" ]]; then
    echo "No images.location entries found in $yaml; nothing to prefetch."
    echo
    return 0
  fi

  while IFS= read -r img_path; do
    [[ -z "$img_path" ]] && continue

    if [[ "$img_path" == "~/"* ]]; then
      img_path="${HOME}/${img_path#~/}"
    fi

    local img_dir img_file url
    img_dir="$(dirname "$img_path")"
    img_file="$(basename "$img_path")"

    mkdir -p "$img_dir"

    if [[ -f "$img_path" ]]; then
      echo "✅ Image already present: $img_path"
      continue
    fi

    if [[ "$img_file" =~ ^ubuntu-([0-9]{2}\.[0-9]{2})-server-cloudimg-arm64\.img$ ]]; then
      local ver="${BASH_REMATCH[1]}"
      url="https://cloud-images.ubuntu.com/releases/${ver}/release/${img_file}"
    else
      echo "⚠️  No URL mapping rule for: $img_file"
      echo "    Expected ubuntu-XX.XX-server-cloudimg-arm64.img"
      echo "    Skipping download. Add a mapping rule if you need other images."
      continue
    fi

    echo "⬇️  Downloading (IPv4): $url"
    echo "    -> $img_path"

    curl -4 -fL --retry 5 --retry-delay 2 -o "$img_path.part" "$url"
    mv -f "$img_path.part" "$img_path"

    echo "✅ Downloaded: $img_path"
  done <<< "$locations"

  echo
}

install_python_deps() {
  echo "== Python venv + deps =="

  if ! command -v python3 >/dev/null 2>&1; then
    echo "⛔️ ERROR: python3 not found"
    return 1
  fi

  # Repo-local python environment directory is venv
  python3 -m venv venv

  # Do NOT activate; install via explicit venv python/pip.
  ./venv/bin/python -m pip install --upgrade pip
  ./venv/bin/pip install -r requirements.txt

  echo "✅ the geospatial python virtual environment created -> venv"
  echo "⏯️ Run: source venv/bin/activate"
  echo
}

verify_toolchain() {
  echo "== Verify versions =="

  echo -n "limactl (pinned) : " && "$PINNED_LIMACTL" --version
  echo -n "helm    (pinned) : " && "$PINNED_HELM" version --short
  echo -n "oc              : " && oc version --client
  echo -n "kubectl         : " && kubectl version --client || true
  echo -n "jq              : " && jq --version
  echo -n "yq              : " && yq --version
  echo -n "k9s             : " && k9s version
  echo -n "openssl         : " && openssl version || true
  echo

  echo "Resolved PATH binaries (informational):"
  echo "  limactl -> $(command -v limactl || true)"
  echo "  helm    -> $(command -v helm || true)"
  echo "  kubectl -> $(command -v kubectl || true)"
  echo
}

# -------- Main ---------------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || { echo "ERROR: Mac-only bootstrap."; exit 1; }

ensure_homebrew_path
mac_resource_check
install_brew_tools
install_repo_tools_symlinks
install_direnv_hooks
ensure_pinned_bin_dir
install_lima_pinned
install_helm_pinned
ensure_repo_envrc
prefetch_lima_images_ipv4
install_python_deps
verify_toolchain

echo "✅ Bootstrap complete"
echo "Next:"
echo "direnv allow"
echo "source venv/bin/activate"
echo "limactl start --name=studio deployment-scripts/lima/studio.yaml"
echo "./deployment-scripts/images-pre-puller/deploy-image-prepuller.sh"
echo "./deploy_studio_lima.sh"
