# Air-Gapped Lima Deployment — Change Log

This document records the changes made to run Geospatial Studio on an
**air-gapped, single-node Lima k3s (arm64/Apple Silicon)** environment, and why
each was needed. The recurring theme: the stack assumes internet access and an
IBM Cloud–style multi-node cluster, so it needed (a) all images preloaded
locally, (b) `imagePullPolicy: IfNotPresent` everywhere, and (c) single-node
fixes for storage and resources.

## Diagnostic cheat-sheet

When a pod is unhealthy, check `lastState.reason` / events **first**:

| Symptom | Meaning | Fix class |
|---|---|---|
| `ImagePullBackOff` / `no such host` | image not in store, or policy forces pull | preload image + `IfNotPresent` |
| `exitCode 137 / OOMKilled` | memory limit too low | raise limit |
| `no available topology found` | provisioner needs topology (Immediate binding) | `--immediate-topology=false` |
| `driver ... not found in registered CSI drivers` | node driver registrar crashlooping | add node region/zone labels |
| `Startup probe failed: connection refused` | usually a **symptom** of a dead process (OOM/crash), not a network bug | check `lastState` |

## 1. kubeconfig for the host (Lima)

`deploy_studio_lima.sh` reads `KUBECONFIG=$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml`.
That path is normally produced by the stock `template://k3s` base, which was
disabled for air-gap. Without it, kubectl falls back to `localhost:8080`
("connection refused").

- **`deployment-scripts/lima/studio.yaml`** — added a `copyToHost` block that
  copies the guest's `/etc/rancher/k3s/k3s.yaml` to that exact host path on
  every `limactl start`. Guest kubeconfig points at `127.0.0.1:6443`, which Lima
  forwards to the host as-is.

## 2. Image pull policy — `IfNotPresent` everywhere (air-gap core fix)

`:latest` tags default to `imagePullPolicy: Always`, which forces a registry
pull even when the image is already in the local containerd store — fatal
air-gapped. Every container spec was set to `IfNotPresent`.

- **`deployment-scripts/minio-deployment.yaml`** — added `IfNotPresent`
- **`deployment-scripts/keycloak-deployment.yaml`** — added `IfNotPresent`
- **`deployment-scripts/ibm-object-csi-driver/cos-s3-csi-driver.yaml`** — 2× `Always` → `IfNotPresent`
- **`deployment-scripts/ibm-object-csi-driver/cos-s3-csi-controller.yaml`** — 2× `Always` → `IfNotPresent`
- **`deployment-scripts/template/populate-buckets-with-initial-data.yaml`** — `Always` → `IfNotPresent`
- **`geospatial-studio/values.yaml`** — global `imagePullPolicy: Always` → `IfNotPresent`
- **`deployment-scripts/install-postgres.sh`** — added `--set global.imagePullPolicy=IfNotPresent` (+ per-image) to both helm installs
- **`deployment-scripts/template/.env.template`** — `image_pull_policy=Always` → `IfNotPresent`
  - NOTE: the studio Helm chart is installed with `--set global.imagePullPolicy=${image_pull_policy}`
    from `.env`, which **overrides** `values.yaml`. On an existing workspace the
    cached `workspace/lima/env/.env` also had to be updated to `IfNotPresent`.

### 2a. Subchart init containers (separate from the global policy)

`global.imagePullPolicy` only reaches container specs that reference it. Several
subchart **init containers** had no `imagePullPolicy` at all, so `:latest`-tagged
init images defaulted to `Always` and failed offline (main containers were fine).
Fixed each to `{{ .Values.image.pullPolicy | default .Values.global.imagePullPolicy }}`
and **repackaged the affected `.tgz`** (helm uses the packaged charts, and
`helm dep build` can't regenerate them offline):

- `geospatial-studio/charts/pgbouncer/templates/deployment.yaml` — `setup-config` → repackaged `pgbouncer-0.1.1.tgz`
- `geospatial-studio/charts/gfm-mlflow/templates/deployment.yaml` — `mlflow-db-migration` (`ghcr.io/mlflow/mlflow:latest`) → repackaged `gfm-mlflow-0.1.7.tgz`
- `geospatial-studio/charts/gfm-studio-gateway/templates/celery/deployments/{worker,beat}.yaml` — `wait-for-redis` (`busybox:1.36`) → repackaged `gfm-studio-gateway-0.1.8.tgz`

A full sweep confirmed every init container across all subcharts now sets
`imagePullPolicy`. **When editing any subchart template, `helm package` it back
into `geospatial-studio/charts/` or the change won't take effect offline.**

## 3. Keycloak OOMKilled (single-node resource sizing)

Keycloak 26 runs an in-container JVM auto-build on `start`; the `dev` tier's
1Gi limit OOM-killed it (`exit 137`). The `connection refused` startup-probe
errors were a symptom of the dead process, not a network issue.

- **`common_functions.sh`** (`dev` tier) — `KEYCLOAK_MEMORY_REQUEST` 512Mi → 1Gi,
  `KEYCLOAK_MEMORY_LIMIT` 1Gi → 2Gi (used for fresh installs)
- **`workspace/lima/env/env.sh`** — same values (the cached env used on upgrades)

## 4. IBM COS S3 CSI driver — two single-node topology fixes

The COS/s3fs driver (used for ReadWriteMany PVCs backed by MinIO buckets)
assumes an IBM Cloud multi-node cluster.

1. **Controller / external-provisioner** — `no available topology found` for
   Immediate-binding PVCs. Fixed in
   **`deployment-scripts/ibm-object-csi-driver/cos-s3-csi-controller.yaml`** by
   adding `--immediate-topology=false` to the `csi-provisioner` args.
2. **Node driver** — `NodeGetInfo` hard-requires
   `topology.kubernetes.io/region` + `topology.kubernetes.io/zone` node labels;
   the Lima node lacks them, so the registrar crashlooped and the driver never
   registered. Fixed in **`deploy_studio_lima.sh`** by labeling the node
   (`region=lima`, `zone=lima-a`) immediately before the CSI apply — idempotent,
   runs every deploy, so fresh VMs are covered.

## 5. Air-gap image bundle (`~/studio-data/airgap-images/`)

`~/studio-data` is mounted into the VM at `/data`, and `studio.yaml`'s
provisioning stages any `*.tar` / `*.tar.gz` / `*.tar.zst` archives here into
`/var/lib/rancher/k3s/agent/images/` so k3s auto-imports them into the `k8s.io`
containerd namespace on startup — no registry needed.

Contents (all **arm64**):
- **App images** (exported from the running VM): minio, geoserver, keycloak,
  postgresql, redis, mlflow, oauth2-proxy, kubectl, os-shell, yq, and the
  geostudio-* set.
- **`k3s-airgap-images-arm64.tar.zst`** — k3s system images (coredns, pause,
  traefik, metrics-server, local-path-provisioner, busybox, klipper). These
  could not be re-exported from the store (multi-arch manifest missing the
  alt-arch blob); fetched from the official k3s release for `v1.30.2+k3s1`.
- **`csi-sidecars-arm64.tar`** — `csi-node-driver-registrar:v2.13.0`,
  `csi-provisioner:v5.2.0`, `livenessprobe:v2.16.0` (retagged `k8s.gcr.io`
  where the manifests request it), plus `ibm-object-csi-driver:v0.1.19`.
- **`studio-extra-images-arm64.tar`** — images the studio Helm chart needs that
  weren't in the original export: `postgres:13` (gateway db-migration
  wait-for-db), `bitnamilegacy/redis:7.4.1-debian-12-r2` (pinned tag),
  `bitnamilegacy/pgbouncer:latest`, `alpine/curl:latest`, `busybox:1.36`.

### 5a. Images pulled with podman (the two bundles we built by hand)

The **app images** and **k3s system images** above came from the running VM /
the official k3s release. But two bundles — the CSI sidecars and the studio
"extra" images — were **not** in the store and had to be pulled fresh with
`podman` on a connected arm64 machine (Apple Silicon), then staged into
`~/studio-data/airgap-images/`. These are the exact commands used.

**Bundle 1 — `csi-sidecars-arm64.tar`** (IBM COS CSI driver + sidecars).
Note: pull from the live `registry.k8s.io`, then **retag** the two the manifests
request under the deprecated `k8s.gcr.io` name so `IfNotPresent` matches:

```bash
podman machine start 2>/dev/null || true

podman pull --platform linux/arm64 registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.13.0
podman pull --platform linux/arm64 registry.k8s.io/sig-storage/csi-provisioner:v5.2.0
podman pull --platform linux/arm64 registry.k8s.io/sig-storage/livenessprobe:v2.16.0
podman pull --platform linux/arm64 quay.io/containerstorage/ibm-object-csi-driver:v0.1.19

podman tag registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.13.0 k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.13.0
podman tag registry.k8s.io/sig-storage/csi-provisioner:v5.2.0            k8s.gcr.io/sig-storage/csi-provisioner:v5.2.0

podman save --multi-image-archive \
  -o ~/studio-data/airgap-images/csi-sidecars-arm64.tar \
  k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.13.0 \
  k8s.gcr.io/sig-storage/csi-provisioner:v5.2.0 \
  registry.k8s.io/sig-storage/livenessprobe:v2.16.0 \
  quay.io/containerstorage/ibm-object-csi-driver:v0.1.19
```

**Bundle 2 — `studio-extra-images-arm64.tar`** (studio Helm chart images missing
from the original export). Pull the *exact* tags the chart requests (note the
**pinned** redis tag — `:latest` will not satisfy it):

```bash
for r in \
  docker.io/library/postgres:13 \
  docker.io/bitnamilegacy/redis:7.4.1-debian-12-r2 \
  docker.io/bitnamilegacy/pgbouncer:latest \
  docker.io/alpine/curl:latest \
  docker.io/library/busybox:1.36; do
  podman pull --platform linux/arm64 "$r"
done

podman save --multi-image-archive \
  -o ~/studio-data/airgap-images/studio-extra-images-arm64.tar \
  docker.io/library/postgres:13 \
  docker.io/bitnamilegacy/redis:7.4.1-debian-12-r2 \
  docker.io/bitnamilegacy/pgbouncer:latest \
  docker.io/alpine/curl:latest \
  docker.io/library/busybox:1.36
```

**Why podman flags matter:**
- `--platform linux/arm64` — the VM is aarch64; without this you may pull amd64
  images that fail to run (`exec format error`).
- `--multi-image-archive` — required to put more than one image in a single
  `.tar` (docker's `save` does this implicitly; podman needs the flag). The
  output is a docker-archive tar, which `k3s ctr images import` reads fine.
- `podman save -o` writes to the **Mac** filesystem (the path given), not inside
  the podman VM — so it lands directly in the mounted staging folder.

**Loading into the running VM (no rebuild needed):**
```bash
limactl shell studio sudo k3s ctr -n k8s.io images import /data/airgap-images/csi-sidecars-arm64.tar
limactl shell studio sudo k3s ctr -n k8s.io images import /data/airgap-images/studio-extra-images-arm64.tar
```
On a fresh VM you can skip the manual import — `studio.yaml` provisioning
auto-imports every archive in this folder on boot.

### 5b. Rebuilding the whole bundle

The **app images** were exported from a populated store with
`k3s ctr -n k8s.io images export`. If you don't have a running store to export
from, pull them the same podman way as above (arm64, `--multi-image-archive`),
using the tags listed under "Contents". The k3s system images come from the
official release: `k3s-airgap-images-arm64.tar.zst` for `v1.30.2+k3s1`.

## 6. Helm chart dependencies — how they're vendored for offline use

The `geospatial-studio` umbrella chart has **6 dependencies** (see `Chart.yaml`).
Five are local; one (redis) is remote:

| Dependency | Version | Source in `Chart.yaml` | How it's obtained offline |
|---|---|---|---|
| `gfm-mlflow` | 0.1.7 | `file://charts/gfm-mlflow` | in-repo dir → `helm package` → `.tgz` |
| `gfm-studio-gateway` | 0.1.8 | `file://charts/gfm-studio-gateway` | in-repo dir → `helm package` → `.tgz` |
| `geofm-ui` | 0.1.4 | `file://charts/geofm-ui` | in-repo dir → `helm package` → `.tgz` |
| `geospatial-studio-pipelines` | 0.1.6 | `file://charts/geospatial-studio-pipelines` | in-repo dir → `helm package` → `.tgz` |
| `pgbouncer` | 0.1.1 | `file://charts/pgbouncer` | in-repo dir → `helm package` → `.tgz` |
| **`redis`** | 20.4.0 | **`https://charts.bitnami.com/bitnami` (remote)** | **`helm pull` from bitnami, then vendor the `.tgz`** |

### The problem

`deploy_studio_lima.sh` ran `helm dep update` + `helm dependency build`, which
**refresh dependencies from their repositories over the network**. The five
`file://` subcharts package locally with no internet, but `redis` resolves to
`oci://registry-1.docker.io/bitnamicharts/redis` (Bitnami migrated its HTTPS
index to OCI on Docker Hub) and fails air-gapped:

```
could not download oci://registry-1.docker.io/bitnamicharts/redis ...
dial tcp: lookup registry-1.docker.io: no such host
```

The `Unable to get an update from the "gitrepo"/"seaweedfs"/"bitnami" chart
repository` warnings are **harmless** — those are `helm repo` entries in the
local helm config, not chart dependencies, and nothing in `Chart.yaml` uses them.

### The fix

1. **Vendor all 6 `.tgz` into `geospatial-studio/charts/`** (they already live
   there). Note the `.tgz` files are **git-ignored**, so they are *not* in the
   repo — they must be shipped alongside the code or rebuilt on a connected
   machine (see below). The unpacked `file://` subchart *directories* **are**
   committed, so only `redis-20.4.0.tgz` truly originates from outside.
2. **Skip the online dep refresh when the charts are already vendored.**
   `deploy_studio_lima.sh` now guards it:
   ```bash
   if ls ./geospatial-studio/charts/*.tgz && ls ./geospatial-studio/charts/redis-*.tgz; then
       echo "Chart dependencies already vendored — skipping online 'helm dep' refresh"
   else
       helm dep update ./geospatial-studio/ ; helm dependency build ./geospatial-studio/
   fi
   ```
   With `charts/` populated and `Chart.lock` present, `helm install`/`template`
   resolve everything locally — verified with an offline
   `helm template` (93 objects, redis + all subcharts rendered).

### Rebuilding the chart bundle on a CONNECTED machine

Run once where there is internet, then copy the whole repo (with `charts/*.tgz`)
to the air-gapped host:

```bash
# 1. Package the five local file:// subcharts (no internet needed)
for c in gfm-mlflow gfm-studio-gateway geofm-ui geospatial-studio-pipelines pgbouncer; do
  helm package geospatial-studio/charts/$c -d geospatial-studio/charts/
done

# 2. Pull the one remote dependency (redis) from Bitnami's OCI registry
helm pull oci://registry-1.docker.io/bitnamicharts/redis --version 20.4.0 \
  -d geospatial-studio/charts/

# 3. Verify offline resolution
helm template studio ./geospatial-studio/ \
  -f workspace/lima/values/geospatial-studio/values-deploy.yaml >/dev/null && echo OK
```

> **Rule:** any edit to a subchart template only takes effect offline after you
> re-run `helm package <subchart> -d geospatial-studio/charts/` — `helm install`
> uses the packaged `.tgz`, and `helm dep build` can't regenerate it with no
> internet. (This is why the init-container fixes in §2a were each repackaged.)

## 7. Docker Hub ref mismatch — `docker.io` vs `registry-1.docker.io`

Bitnami charts render image refs as **`registry-1.docker.io/bitnamilegacy/...`**,
but the staged bundle (built with `podman pull docker.io/...`) imports them as
**`docker.io/bitnamilegacy/...`**. They're the same registry, but **containerd
matches images by literal ref string**, so with `imagePullPolicy: IfNotPresent`
the chart's `registry-1.docker.io` ref is "not present" → the pod tries to pull →
fails offline (`dial tcp: lookup registry-1.docker.io: no such host`).

Symptom seen on `postgresql-0` init container `init-chmod-data`
(`registry-1.docker.io/bitnamilegacy/os-shell:latest`) and would hit redis,
pgbouncer, kubectl, oauth2-proxy too.

**Fix:** alias every `docker.io/*` image to `registry-1.docker.io/*` in the k3s
store so both refs resolve locally (a `ctr images tag` alias — no data copy):

```bash
for ref in $(k3s ctr -n k8s.io images ls -q | grep '^docker.io/' | grep -v '@sha256:'); do
  k3s ctr -n k8s.io images tag "$ref" "registry-1.docker.io/${ref#docker.io/}"
done
```

Made durable in **`deploy_studio_lima.sh`** (runs this alias loop after
`KUBECONFIG` is set, before any component deploys — idempotent) and in
**`deployment-scripts/airgap/load-airgap-images.sh`** (after import). Alternative:
tag both refs at bundle-build time before `podman save`.

## 8. k3s binary ↔ airgap-images bundle version MUST match

The single most impactful air-gap failure: the k3s **binary** (`v1.30.2+k3s1`,
sandbox `pause:3.6`, coredns `1.10.1`, local-path `v0.0.27`, metrics-server
`v0.7.0`, traefik `2.10.7`) and the **k3s-airgap-images bundle** must be the same
version. A newer bundle (pause `3.10.2`, coredns `1.14.6`, …) does **not** contain
the images the v1.30.2 binary needs, so offline the cluster can't create pod
sandboxes or run coredns/local-path/metrics/traefik → PVCs never provision →
DB-creation is skipped → full cascade. Online it silently "works" because k3s
pulls the right versions.

**Guards added:**
- `build-airgap-bundle.sh` downloads the bundle for `K3S_VERSION` and now **verifies
  the bundle's pause version equals `K3S_PAUSE_IMAGE`**, aborting on mismatch.
- `deploy_studio_lima.sh` **preflights** the running k3s's `sandbox_image` against
  the store and aborts with a clear message if it's absent (bundle/binary mismatch).
- `AIRGAP-DEPLOY-RUNBOOK.md` §3.3b documents the manual version check.

Also staged `pause-3.6-arm64.tar` (the exact sandbox image the v1.30.2 binary
needs, both `docker.io` + `registry-1.docker.io` refs) as a belt-and-suspenders.

## Deploying from scratch (air-gapped)

```bash
export KUBECONFIG=$HOME/.lima/studio/copied-from-guest/kubeconfig.yaml
./uninstall.sh            # clean teardown (if a prior release exists)
./deploy_studio_lima.sh   # MinIO -> CSI (topology fixed) -> studio
kubectl get pods -A -w
```

## Known watch items

- **`terratorch`** (3.9 GB) may request GPU resources; on CPU-only Lima, use the
  deploy's "remove GPU config" prompt or it will stay `Pending`.
- The `helm dep update` network errors during the studio step are **noise** —
  the chart dependencies are already vendored in `geospatial-studio/charts/`.
- `FailedToRetrieveImagePullSecret (us-icr-pull-secret)` on some pods is
  harmless with `IfNotPresent` + preloaded images.
- The debug helper in the deploy scripts uses GNU `grep -P` (unsupported by
  macOS BSD grep) → harmless `invalid option -- P` spam. Not yet fixed.
