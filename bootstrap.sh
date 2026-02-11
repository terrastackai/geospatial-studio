#!/usr/bin/env bash
set -euo pipefail

# -------- Pins ---------------------------------------------------------------
LIMA_VERSION="1.2.1"
HELM_VERSION="3.19.0"

# Canonical pinned locations (repo-scoped usage)
PINNED_BIN_DIR="/usr/local/bin"
PINNED_LIMACTL="${PINNED_BIN_DIR}/limactl"
PINNED_HELM="${PINNED_BIN_DIR}/helm"

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
  brew install jq yq k9s openshift-cli gettext direnv
  brew link --force gettext
  echo
}

install_direnv_hooks() {
  echo "== direnv shell hooks (bash + zsh) =="

  if ! need direnv; then
    echo "⚠️  direnv not found on PATH; skipping hook installation."
    echo
    return 0
  fi

  local bashrc="$HOME/.bashrc"
  local zshrc="$HOME/.zshrc"

  # Block markers so it’s easy to remove later.
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
      # Insert before end marker
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
  ensure_block "$zshrc"  'eval "$(direnv hook zsh)"'

  echo
  echo "ℹ️  To apply in current shells:"
  echo "  bash: exec bash -l"
  echo "  zsh : exec zsh -l"
  echo
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
  sudo install -m 0755 "$lima_bin" "${PINNED_BIN_DIR}/lima"

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

install_pinned_shortcuts() {
  echo "== Pinned shortcuts =="

  sudo tee "${PINNED_BIN_DIR}/limactl121" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/limactl "$@"
EOF
  sudo chmod 0755 "${PINNED_BIN_DIR}/limactl121"

  sudo tee "${PINNED_BIN_DIR}/lima121" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/lima "$@"
EOF
  sudo chmod 0755 "${PINNED_BIN_DIR}/lima121"

  sudo tee "${PINNED_BIN_DIR}/helm319" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec /usr/local/bin/helm "$@"
EOF
  sudo chmod 0755 "${PINNED_BIN_DIR}/helm319"

  echo "✅ Installed shortcuts:"
  echo "  limactl121 -> ${PINNED_LIMACTL}"
  echo "  lima121    -> ${PINNED_BIN_DIR}/lima"
  echo "  helm319    -> ${PINNED_HELM}"
  echo
}

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

  python3 -m venv venv
  source venv/bin/activate

  python -m pip install --upgrade pip
  pip install -r requirements.txt

  echo "✅ the geospatial python virtual environment created -> .geo-venv"
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
  echo

  echo "Resolved PATH binaries (informational):"
  echo "  limactl -> $(command -v limactl || true)"
  echo "  helm    -> $(command -v helm || true)"
  echo "  kubectl -> $(command -v kubectl || true)"
  echo
}

# -------- Main ---------------------------------------------------------------
# Check if the machine is linux core -> "Darwin"
[[ "$(uname -s)" == "Darwin" ]] || { echo "ERROR: Mac-only bootstrap."; exit 1; }

# Run defined functions (defined above)
ensure_homebrew_path
mac_resource_check
install_brew_tools
install_direnv_hooks
install_lima_pinned
install_helm_pinned
install_pinned_shortcuts
prefetch_lima_images_ipv4
install_python_deps
verify_toolchain

echo "✅ Bootstrap complete"
echo "Next:"
echo "  ${PINNED_BIN_DIR}/limactl121 start --name=studio deployment-scripts/lima/studio.yaml"
echo "  export KUBECONFIG=\"\$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml\""
echo "  k9s"
