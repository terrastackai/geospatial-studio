# Geospatial Studio — Air-Gapped Deployment Runbook (Lima / k3s / Apple Silicon arm64)

Complete, start-from-nothing, **skip-nothing** guide to deploy Geospatial Studio on an
**air-gapped** single-node Lima k3s VM. Written from hard-won experience — every step,
checkpoint, and known failure is here.

- **Part 1** runs on a machine **WITH internet** (download + build everything).
- **Parts 2–8** run on the **air-gapped host** (Apple Silicon Mac) with **Wi-Fi OFF**.
- If your build machine and deploy host are the same Mac: do Part 1 online, then turn
  Wi-Fi off and continue.
- **Everything is arm64.** Never introduce amd64 artifacts.
- Run every command from the **repo root** unless stated otherwise:
  `cd /Users/fionamurugi/Desktop/projects/geospatial-studio`

---

## 0. The rules that make or break air-gap (read first)

1. **Version lock.** The k3s **binary**, the k3s **airgap-images bundle**, and the pod
   **sandbox (pause) image** MUST be the same k3s version. This guide pins everything to
   **`v1.30.2+k3s1`** (pause `3.6`). Change the version in one place → change it everywhere.
2. **Every image must be in the local store before deploy.** The deploy waits for import.
3. **Every container uses `imagePullPolicy: IfNotPresent`** (already set in source).
4. **Image refs must match what charts request** — the deploy aliases `docker.io/*` to
   `registry-1.docker.io/*` automatically (containerd matches by literal ref).
5. **Edited Helm subchart templates must be `helm package`-d back into `charts/`.**
6. All artifacts are **arm64**.

Pinned versions used throughout:
```
K3S_VERSION       = v1.30.2+k3s1
K3S_PAUSE_IMAGE   = rancher/mirrored-pause:3.6
REDIS_CHART       = 20.4.0
```

---

## 1. Prerequisites (build machine)

Install these tools (Homebrew): `lima` (`limactl`), `kubectl`, `helm`, `podman`, `curl`, `zstd`.
Start the podman VM once:
```bash
podman machine start 2>/dev/null || true
```
Have the Geospatial Studio repo checked out.

---

## 2. Clean slate — wipe any previous attempt (air-gapped host)

```bash
# Delete the VM (and its entire image store)
limactl stop studio 2>/dev/null; limactl delete studio 2>/dev/null

# Remove all staged artifacts (images + k3s runtime)
rm -rf ~/studio-data

# Confirm
limactl list                       # no 'studio'
ls ~/studio-data 2>/dev/null || echo "clean"
```

---

## 3. Part 1 — Download & build everything (ONLINE)

All artifacts land in `~/studio-data/` (host-mounted into the VM at `/data`).

### 3.1 — k3s runtime (binary + installer)
```bash
mkdir -p ~/studio-data
K3S_VERSION="v1.30.2+k3s1"

curl -fL -o ~/studio-data/k3s \
  "https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64"
chmod +x ~/studio-data/k3s

curl -fL -o ~/studio-data/install.sh https://get.k3s.io
chmod +x ~/studio-data/install.sh

ls -lh ~/studio-data/k3s ~/studio-data/install.sh     # both must exist
```

### 3.2 — VM base image + containerd runtime
```bash
# Ubuntu arm64 cloud image
curl -fL -o ~/Downloads/ubuntu-24.04-server-cloudimg-arm64.img \
  https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img

# nerdctl-full arm64
curl -fL -o ~/Downloads/nerdctl-full-2.3.5-linux-arm64.tar.gz \
  https://github.com/containerd/nerdctl/releases/download/v2.3.5/nerdctl-full-2.3.5-linux-arm64.tar.gz
```
Then **edit `deployment-scripts/lima/studio.yaml`** so its `images:` `location:` and
`containerd.archives` `location:` point at the **exact absolute paths** of the two files
above. Verify:
```bash
grep -E "location:" deployment-scripts/lima/studio.yaml
ls -lh /Users/fionamurugi/Downloads/ubuntu-*.img /Users/fionamurugi/Downloads/nerdctl-full-*.tar.gz
```

### 3.3 — Build the image bundle (ONE script — do NOT run the helm commands by hand)
```bash
cd /Users/fionamurugi/Desktop/projects/geospatial-studio
K3S_VERSION="v1.30.2+k3s1" K3S_PAUSE_IMAGE="rancher/mirrored-pause:3.6" \
  ./deployment-scripts/airgap/build-airgap-bundle.sh
```
This single script:
- downloads the k3s airgap images bundle **and verifies its pause version == 3.6**
  (aborts on mismatch),
- pulls the CSI sidecars (retagged to `k8s.gcr.io` where manifests need it),
- pulls the studio "extra" images (postgres:13, pinned redis, pgbouncer, curl, busybox 1.36 + latest),
- pulls all application images (minio, geoserver, keycloak, mlflow, gateway, ui, pipelines, terratorch, …),
- packages the 5 local Helm subcharts and pulls the redis subchart into `geospatial-studio/charts/`.

Expected tail: `charts OK (all deps vendored)` and a `DONE. Bundle contents:` listing.

### 3.4 — Verify the bundle before going offline
```bash
ls -lh ~/studio-data/airgap-images/*.tar*
# pause in the bundle MUST equal what the k3s binary expects (3.6):
zstd -dc ~/studio-data/airgap-images/k3s-airgap-images-arm64.tar.zst \
  | tar -xO manifest.json | grep -oE 'mirrored-pause:[0-9.]+' | head -1
```
You should have: `k3s-airgap-images-arm64.tar.zst`, `csi-sidecars-arm64.tar`,
`studio-extra-images-arm64.tar`, `studio-app-images-arm64.tar`, and `pause:3.6`.

---

## 4. Part 2 — Go offline

Turn **Wi-Fi OFF** now. Everything below is fully air-gapped.

---

## 5. Part 3 — Create the VM

```bash
cd /Users/fionamurugi/Desktop/projects/geospatial-studio
limactl start deployment-scripts/lima/studio.yaml
```
Provisioning runs automatically, in order:
1. stage every `~/studio-data/airgap-images/*` archive into k3s's auto-import dir,
2. install k3s from `/data/k3s` + `/data/install.sh` (no download),
3. export the kubeconfig; `copyToHost` copies it to
   `~/.lima/studio/copied-from-guest/kubeconfig.yaml`.

✅ **Checkpoint:** the last lines should show the kubeconfig copied and **no**
`copyToHost ... exit status 1` / `DEGRADED`. If DEGRADED appears, k3s didn't start —
see Troubleshooting.

---

## 6. Part 4 — Verify the cluster BEFORE deploying

```bash
export KUBECONFIG=$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml

# 6.1 node ready
kubectl get nodes                                  # lima-studio  Ready

# 6.2 CRITICAL: bundle pause must match the k3s binary's sandbox image
limactl shell studio sudo grep -hoE 'sandbox_image = "[^"]+"' \
  /var/lib/rancher/k3s/agent/etc/containerd/config.toml*     # e.g. mirrored-pause:3.6
limactl shell studio sudo k3s ctr -n k8s.io images ls -q | grep mirrored-pause

# 6.3 all k3s system pods Running (NO ImagePullBackOff)
kubectl get pods -n kube-system
```
✅ **Checkpoint:** every kube-system pod is `Running`. If any is `ImagePullBackOff`
(coredns / local-path / metrics-server / traefik / pause), your bundle version does not
match the k3s binary — **stop**, fix the bundle (3.3), rebuild the VM. Do not deploy on top.

---

## 7. Part 5 — Deploy the studio

```bash
export KUBECONFIG=$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml
./deploy_studio_lima.sh
```
Answer the prompts: press **enter** to accept the plan; `RESOURCE_MODE=dev`; **remove**
GPU config when asked (Lima is CPU-only).

The deploy automatically, before any component:
- **waits for image import to settle** (several minutes on first boot — the 17 GB of
  tars incl. 3.9 GB terratorch; this is expected, not a hang),
- **aliases** `docker.io/*` → `registry-1.docker.io/*`,
- **preflights** the sandbox image and **aborts** if the bundle/binary mismatch,
- **labels the node** for the COS CSI driver topology,

then deploys **MinIO → IBM COS CSI driver → PostgreSQL → Keycloak → GeoServer → Studio
Helm chart** (gateway, ui, redis, pgbouncer, mlflow, pipelines).

✅ **Checkpoint:** the run completes without you patching anything.

---

## 8. Part 6 — Bring up the pipelines (one-time VM restart)

The 8 `pipelines-*` pods mount COS s3fs (FUSE) volumes. On the **first** deploy, many
concurrent s3fs mounts can wedge kubelet and leave the pipelines pods stuck in
`PodInitializing` (core app is fine). A single VM restart clears this — on restart the
volumes are already provisioned, so the pipelines mount cleanly.

```bash
limactl stop studio
limactl start studio
export KUBECONFIG=$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml
kubectl get pods -A -w
```
Wait for the `pipelines-*` pods to go `1/1 Running`.

> If they still wedge after a clean restart, it's an s3fs-on-single-node scaling limit
> (not air-gap): give the VM more CPU/RAM in `studio.yaml`, or switch pipelines PVCs to
> `local-path` (see Troubleshooting).

---

## 9. Part 7 — Verify success

```bash
export KUBECONFIG=$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml
kubectl get pods -A          # everything Running / Completed
kubectl get pvc -A           # all Bound
helm list -n default         # 'studio' + 'postgresql' releases present
```
The full stack should be up: minio, postgresql, keycloak, geofm-geoserver, geofm-mlflow,
geofm-gateway (3/3), geofm-ui, geofm-pgbouncer, geofm-redis-master/replicas,
cos-s3-csi-controller/driver, and all `pipelines-*`.

Access (port-forward as the deploy sets up, or):
```bash
kubectl port-forward -n default svc/geofm-ui 4180:4180
# then open the UI locally
```

---

## 10. Troubleshooting (every failure we hit, and the fix)

Always run `kubectl describe pod <pod>` and check the container `lastState.reason` first.

| Symptom | Root cause | Fix |
|---|---|---|
| `kubectl` → `localhost:8080 connection refused` | kubeconfig not copied (k3s wasn't up at boot) | provisioning installs k3s then copies it; if DEGRADED, k3s failed to start (check `~/.lima/studio/ha.stderr.log`) |
| VM `DEGRADED`, `copyToHost ... exit status 1` | k3s not installed at boot | ensure `~/studio-data/k3s` + `install.sh` exist (3.1); provisioning auto-installs |
| `install.sh` → `k3s binary not found at /usr/local/bin/k3s` | `INSTALL_K3S_SKIP_DOWNLOAD` needs the binary pre-placed | provisioning copies `/data/k3s` first; manual: `sudo cp /data/k3s /usr/local/bin/k3s && chmod +x` then run install |
| kube-system pods `ImagePullBackOff` (coredns/local-path/metrics/pause) | **k3s bundle version ≠ binary version** | stage the airgap bundle matching your k3s version (3.3); rebuild VM |
| `FailedCreatePodSandBox ... mirrored-pause:3.x` | pause image missing/mismatched | same as above — pause must match the binary; the deploy preflights this |
| `ImagePullBackOff` / `no such host` on an app image | image not staged, or `docker.io` vs `registry-1.docker.io` ref | ensure it's in the bundle; the deploy's alias step handles the ref form |
| `OOMKilled` (exit 137), e.g. Keycloak | memory limit too low | Keycloak set to 2Gi in `common_functions.sh`; raise others similarly |
| `Startup probe failed: connection refused` | usually a **symptom** of a crashed/OOM process, not a network bug | check `lastState.reason` |
| PVC `Pending`: `no available topology found` | CSI provisioner requires topology | `--immediate-topology=false` (already in `cos-s3-csi-controller.yaml`) |
| `driver cos.s3.csi.ibm.io not found in registered CSI drivers` | node driver registrar crashloops (no topology labels) | deploy labels the node `topology.kubernetes.io/region|zone`; ensure that ran |
| COS PVC `PermissionDenied unable to create bucket` | MinIO self-signed cert is not a CA (TLS verify fails) | `CA:TRUE` in `minio-openssl.conf` (already in source) |
| keycloak `database "keycloak" does not exist` | DBs created while cluster was broken | happens only if you deployed onto a broken cluster; a clean run from Part 3 avoids it. Manual fix: exec into `postgresql-0` and run `psql -U postgres -c 'CREATE DATABASE <db>;'` for keycloak/geostudio/mlflow/geostudio_auth (supply the postgres password from the `postgresql` secret via the `PGPASSWORD` env var) |
| `could not download oci://.../redis` during helm dep | helm trying to refresh deps online | charts are vendored in `charts/`; deploy skips the online refresh (noise, non-fatal) |
| `pipelines-*` stuck `PodInitializing`, volumes mounted, init done | s3fs/FUSE mount wedge from many concurrent mounts | **restart the VM** (Part 6) |
| Everything only works with Wi-Fi ON | an image k3s/charts need isn't staged and gets pulled online | find it (`kubectl describe`), add it to the bundle; re-verify with an offline render |

**Switch pipelines off COS s3fs (optional, lighter for dev):** set the pipelines PVC
storage class to `local-path` instead of `cos-s3-csi-s3fs-sc` in the studio values. On a
single node, `local-path` RWO volumes are shareable by pods on that node and avoid FUSE
entirely — far more stable than 16+ s3fs mounts.

---

## 11. What the automation handles for you (so you don't patch by hand)

| Concern | Where it's handled |
|---|---|
| Kubeconfig to host | `studio.yaml` `copyToHost` |
| Stage + import images | `studio.yaml` provisioning (image preload) |
| Install k3s from local binary | `studio.yaml` provisioning (k3s-install step) |
| Wait for import + alias refs + preflight + node labels | `deploy_studio_lima.sh` (top) |
| `IfNotPresent` on every container (incl. subchart init containers) | source manifests + repackaged `charts/*.tgz` |
| Keycloak memory (2Gi) | `common_functions.sh` + `workspace/lima/env/env.sh` |
| CSI topology (controller flag + node labels) | `cos-s3-csi-controller.yaml` + `deploy_studio_lima.sh` |
| MinIO CA cert | `minio-openssl.conf` |
| Offline Helm chart deps | vendored `geospatial-studio/charts/*.tgz`; deploy skips online refresh |
| Bundle↔binary version guard | `build-airgap-bundle.sh` (build-time) + `deploy_studio_lima.sh` (preflight) |

See `AIRGAP-CHANGES.md` for the full rationale behind each fix.
