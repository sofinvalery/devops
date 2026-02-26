# devops

DevOps project: build + packaging (`.deb`), CI/CD, Docker image publishing, Kubernetes deployment with Helm, Prometheus/Grafana monitoring, and HPA autoscaling.

## What the program does

The core algorithm processes a 7x7 matrix:
1. Counts zeros above the main diagonal.
2. Counts positive values below the secondary diagonal.
3. If counts are equal, zeroes the matrix.

Runtime modes:
1. Default mode (`./reverse`): single run, prints matrix/result, exits.
2. Server mode (`./reverse --server --port 8080`): long-running HTTP service with:
   - `/healthz`
   - `/metrics` (Prometheus format)

## Labs coverage

1. Assignment 1 (build/distribution/dependencies)
- `matrix.c`
- `Makefile` build flow
- `.deb` packaging (`make deb-build`, `ci/package.sh`)

2. Assignment 2 (CI/CD)
- Build/test/package scripts in `ci/`
- GitHub Actions pipeline in `.github/workflows/ci.yml`
- release asset publishing on tags `v*`

3. Assignment 3 (container deployment)
- `Dockerfile` based on Ubuntu
- pipeline image build check
- Docker Hub push on tags `v*`

4. Assignment 4 (Kubernetes + monitoring)
- Helm chart: `helm/reverse`
- K8s resources: Deployment/Service/ServiceMonitor/HPA
- Prometheus+Grafana install script
- dashboard JSON + deployment/verification scripts

## Repository layout

```text
.
├── matrix.c
├── Makefile
├── Dockerfile
├── ci/
│   ├── build.sh
│   ├── test.sh
│   └── package.sh
├── .github/workflows/ci.yml
├── helm/reverse/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── servicemonitor.yaml
│       └── hpa.yaml
└── ops/
    ├── k8s/
    │   ├── deploy-app.sh
    │   └── verify.sh
    ├── monitoring/
    │   ├── install-monitoring.sh
    │   └── kube-prometheus-stack-values.yaml
    └── grafana/
        └── reverse-dashboard.json
```

## Local build and run

### Build and single-run mode

```bash
git clone https://github.com/sofinvalery/devops.git && cd devops
make
./reverse
```

### Server mode (health + metrics)

```bash
./reverse --server --port 8080
```

In another shell:

```bash
curl -fsS http://127.0.0.1:8080/healthz
curl -fsS http://127.0.0.1:8080/metrics | head -n 20
```

## Debian package

```bash
ci/package.sh
```

Artifact:
- `dist/reverse_<version>_<arch>.deb`

## CI/CD pipeline details

Workflow: `.github/workflows/ci.yml`

Triggers:
1. `push` to `main`
2. `pull_request` to `main`
3. tag `v*`

Jobs:
1. `build` -> compiles binary and uploads artifact
2. `test` -> validates output format/logic
3. `package` -> builds `.deb` artifact
4. `deploy` -> builds Docker image from `.deb`, runs container validation
5. `release` -> publishes `.deb` asset on tags `v*`

Docker Hub push in `deploy` job on `v*` tags requires secrets:
1. `DOCKERHUB_USERNAME`
2. `DOCKERHUB_TOKEN`

## Docker usage

Pull by tag:

```bash
docker pull sofinvalery/devops:v1.0.2
```

Run server mode inside container:

```bash
docker run --rm -p 8080:8080 sofinvalery/devops:v1.0.2 --server --port 8080
```

Check:

```bash
curl -fsS http://127.0.0.1:8080/healthz
curl -fsS http://127.0.0.1:8080/metrics | head -n 20
```

## Kubernetes deployment (k3s + Helm)

### Prerequisites

```bash
kubectl get nodes
helm version
```

### Install monitoring stack

```bash
./ops/monitoring/install-monitoring.sh
kubectl -n monitoring get pods
```

### Deploy app chart

```bash
IMAGE_TAG=v1.0.2 ./ops/k8s/deploy-app.sh
kubectl -n reverse rollout status deploy/reverse --timeout=300s
```

### Verify app stack

```bash
./ops/k8s/verify.sh
kubectl -n reverse get deploy,po,svc,hpa,servicemonitor
```

## Prometheus and Grafana verification

### Prometheus

Open:
- `http://<NODE_IP>:32090`

Check:
1. `Status -> Targets` contains `reverse` with `UP`.
2. Queries return data:

```bash
curl -fsS "http://<NODE_IP>:32090/api/v1/query?query=reverse_iterations_total"
curl -fsS "http://<NODE_IP>:32090/api/v1/query?query=rate(reverse_iterations_total%5B1m%5D)"
```

### Grafana

Open:
- `http://<NODE_IP>:32000`

Credentials from secret:

```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-user}' | base64 -d; echo
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Dashboard:
- `Reverse App Metrics`
- source file: `ops/grafana/reverse-dashboard.json`

If dashboard is empty:
1. Set time range to `Last 1 hour`.
2. Refresh.
3. Confirm Prometheus target is `UP`.

## HPA verification

Watch autoscaler:

```bash
kubectl -n reverse get hpa -w
```

Generate CPU load:

```bash
POD=$(kubectl -n reverse get pod -l app.kubernetes.io/name=reverse -o jsonpath='{.items[0].metadata.name}')
kubectl -n reverse exec "$POD" -- sh -c 'nohup yes > /dev/null 2>&1 &'
```

Stop load:

```bash
for p in $(kubectl -n reverse get pod -l app.kubernetes.io/name=reverse -o jsonpath='{.items[*].metadata.name}'); do
  kubectl -n reverse exec "$p" -- sh -c 'pkill yes || true' || true
done
```

Expected behavior:
1. replicas increase under sustained load
2. replicas return down after stabilization window

## Networking notes

Current working NodePorts:
1. App: `30080`
2. Prometheus: `32090`
3. Grafana: `32000`

## Links

1. GitHub: `https://github.com/sofinvalery/devops`
2. Docker Hub: `https://hub.docker.com/r/sofinvalery/devops`
