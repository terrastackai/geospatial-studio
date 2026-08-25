# Geospatial Studio — Air-Gapped Deployment Runbook (kind / Linux / amd64)

Deploy the full studio onto a local **kind** (Kubernetes-in-Docker) cluster on an
**offline Linux x86_64** machine, with a single command: `./deploy_studio_kind.sh`.

This is the kind analogue of `AIRGAP-DEPLOY-RUNBOOK.md` (which targets Lima/k3s/arm64).
It reuses the same building blocks — vendored Helm charts, `imagePullPolicy: IfNotPresent`
everywhere, and the `docker.io → registry-1.docker.io` image alias — but stages images with
`kind load` instead of the k3s import dir, and uses the `kindest/node` image instead of a k3s
binary + `k3s-airgap-images` bundle.

---

## 0. The rules that make or break air-gap (read first)

1. **Every image must be in the cluster's containerd store before deploy.** `deploy_studio_kind.sh`
   `kind load`s the whole bundle and preflights key images before deploying.
2. **Every container uses `imagePullPolicy: IfNotPresent`** (already set in source on this branch).
3. **Image refs must match what the charts request.** The deploy aliases `docker.io/*` →
   `registry-1.docker.io/*` in every node automatically (containerd matches by literal ref).
4. **Helm chart deps are vendored** in `geospatial-studio/charts/*.tgz`; the deploy skips any
   online `helm dep` refresh when they're present.
5. **Storage mode is `local-hostpath`** — avoids the IBM COS s3fs/FUSE CSI path, which is fragile
   inside kind node containers.
6. All artifacts are **amd64**. Build them on a connected amd64 host.

---

## 1. Build the bundle — ONLINE (connected amd64 host)

Prereqs on the build host: `podman`, `helm`, `curl`, `docker`, `kind`.

```bash
git clone https://github.com/terrastackai/geospatial-studio.git
cd geospatial-studio
git checkout feat/airtight-deployment      # branch with the IfNotPresent + vendored-chart fixes

TARGET=kind ARCH=amd64 ./deployment-scripts/airgap/build-airgap-bundle.sh
```

This produces, in `~/studio-data/airgap-images/`:

| Artifact | Contents |
|---|---|
| `kind-node-amd64.tar` + `kind-node-image.txt` | the `kindest/node` image matching your `kind` binary |
| `csi-sidecars-amd64.tar` | IBM COS CSI driver + sidecars (deployed regardless of storage mode) |
| `studio-extra-images-amd64.tar` | postgres:13, pinned redis, pgbouncer, curl, busybox |
| `studio-app-images-amd64.tar` | minio, geoserver, keycloak, mlflow, gateway, ui, pipelines, terratorch, … |
| `postgres-pinned-amd64.tar` + `postgres-tags.env` | the exact PostgreSQL + os-shell image tags the chart wants |
| `postgresql-<ver>.tgz` | the Bitnami PostgreSQL chart (installed offline from this file) |

It also vendors `geospatial-studio/charts/*.tgz` into your checkout.

> It does **not** download the k3s image bundle (kind doesn't use it).

---

## 2. Also stage the offline CLI tools

`apt`/`yum` won't work offline, so carry these too:

- **Docker Engine** — must be pre-installed on the target (or carry its offline packages).
- Static binaries: `kind` (linux-amd64), `kubectl`, `helm` (v3.19+), `yq`, `jq`.
- Python deps for the deploy scripts: `pip download -r requirements.txt -d ~/studio-data/wheels`.

---

## 3. Transfer to the air-gapped host

Copy over:
- the **repo checkout** (with `geospatial-studio/charts/*.tgz` populated),
- the entire **`~/studio-data/airgap-images/`** directory,
- the CLI binaries + `~/studio-data/wheels` from step 2.

---

## 4. Deploy — OFFLINE (air-gapped host)

Put `docker/kind/kubectl/helm/yq/jq` on `PATH`, then set up Python and run the one command:

```bash
cd geospatial-studio
python3 -m venv venv && source venv/bin/activate
pip install --no-index --find-links ~/studio-data/wheels -r requirements.txt

./deploy_studio_kind.sh
```

`deploy_studio_kind.sh` will:
1. `docker load` the node image and `kind create cluster --name studio` (control-plane + worker) — skipped if it already exists;
2. `kind load` every image archive into the cluster's containerd;
3. alias `docker.io/*` → `registry-1.docker.io/*` in every node;
4. preflight that keycloak / minio / geoserver / gateway / ui / redis / postgresql images are present;
5. hand off to `deploy_studio_k8s.sh` with `AIRGAP=true NON_INTERACTIVE=true STORAGE_MODE=local-hostpath`
   and the pinned PostgreSQL chart/tags — deploying MinIO → CSI driver → PostgreSQL → Keycloak →
   GeoServer → the Studio Helm chart.

Overridable env: `AIRGAP_DIR` (default `~/studio-data/airgap-images`), `KIND_CLUSTER` (default `studio`),
`ARCH` (default `amd64`), `STORAGE_MODE` (default `local-hostpath`).

---

## 5. Access

The deploy sets up port-forwards. Add the internal cluster hostnames to `/etc/hosts`:

```bash
echo -e "127.0.0.1 keycloak.default.svc.cluster.local postgresql.default.svc.cluster.local minio.default.svc.cluster.local geofm-ui.default.svc.cluster.local geofm-gateway.default.svc.cluster.local geofm-geoserver.default.svc.cluster.local" | sudo tee -a /etc/hosts
```

| Service | URL | Login |
|---|---|---|
| Studio UI | https://localhost:4180 | `testuser` / `testpass123` |
| Studio API | https://localhost:4181 | X-API-Key (printed in deploy summary) |
| Keycloak | http://localhost:8080 | `admin` / `admin` |
| MinIO console | https://localhost:9001 | `minioadmin` / `minioadmin` |
| MLflow | http://localhost:5000 | none |

> **Remote host?** The port-forwards bind to the host's `localhost`. From your laptop:
> `ssh -L 4180:localhost:4180 -L 4181:localhost:4181 -L 5000:localhost:5000 user@target`.

Verify: `kubectl get pods -A` (all Running/Completed), `helm list -n default` (`studio` + `postgresql`).

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Deploy aborts at **preflight** ("MISSING: …") | an image isn't staged in the node store | confirm the archive is in `$AIRGAP_DIR`; re-run — it re-`kind load`s and re-aliases |
| Pod `ImagePullBackOff` / `no such host` | image not staged, or `docker.io` vs `registry-1.docker.io` ref | `kubectl describe pod` for the exact ref; add it to a bundle on the build host, re-transfer, re-run the deploy (the alias loop reruns) |
| **PostgreSQL** `ImagePullBackOff` on a specific tag | chart's pinned tag not staged | ensure `postgres-pinned-amd64.tar` + `postgres-tags.env` are present; the deploy exports `PG_IMAGE_TAG`/`PG_OSSHELL_TAG` from that file |
| `could not download oci://.../redis` during helm dep | helm trying to refresh deps online | non-fatal — charts are vendored in `charts/`; the deploy skips the online refresh |
| `kind create cluster` tries to pull the node image | `kind-node-image.txt` tag ≠ loaded image | ensure `docker load -i kind-node-amd64.tar` succeeded and the tag in the file matches `docker images kindest/node` |
| Keycloak `OOMKilled` (exit 137) | memory limit too low | `dev` tier sets Keycloak to 2Gi in `common_functions.sh`; raise if needed |
| Everything only works with networking ON | an image the charts need isn't staged and gets pulled | find it via `kubectl describe`, add it to the bundle, re-transfer, re-run |

---

## What the automation handles for you

| Concern | Where |
|---|---|
| kindest/node + pinned PostgreSQL staging | `build-airgap-bundle.sh` (`TARGET=kind`) |
| Create cluster + `kind load` + alias + preflight | `deploy_studio_kind.sh` |
| Non-interactive node name + storage mode | `deploy_studio_k8s.sh` (gated on `NON_INTERACTIVE`) |
| Skip online bitnami repo + helm dep refresh | `deploy_studio_k8s.sh` (gated on `AIRGAP` / vendored charts) |
| PostgreSQL offline chart + pinned tags | `install-postgres.sh` (`PG_CHART` / `PG_IMAGE_TAG` / `PG_OSSHELL_TAG`) |
| `IfNotPresent` on every container | source manifests + repackaged `charts/*.tgz` |

See `AIRGAP-CHANGES.md` for the rationale behind the shared air-gap fixes.
