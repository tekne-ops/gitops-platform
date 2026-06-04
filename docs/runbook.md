# Runbook

Operational commands for **gitops-platform**. The main [README](../README.md) describes repo structure and the GitOps model; this file collects setup, day-two, and legacy commands.

Sections marked **(legacy)** were used before the refactor to pre-rendered manifests and split Argo apps. Prefer the **Current GitOps** sections for new clusters.

---

## Current GitOps — bootstrap

Prerequisites: Kubernetes cluster, Argo CD installed (see [Argo CD setup](#argocd-setup) below).

```bash
kubectl apply -f bootstrap/argocd-app.yml
```

This creates the `platform-dev` Application (app-of-apps → `apps/dev/`).

**Manual secrets** (create after the `namespaces` app syncs, before dependent apps need them):

```bash
# Cloudflare token for cert-manager DNS-01 (namespace must exist)
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=YOUR_TOKEN \
  -n cert-manager

# Image pull secret for devops-lab
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=YOURUSER \
  --docker-password=YOURPASS \
  --docker-email=YOUREMAIL \
  --namespace devops-lab
```

Replace placeholder values in `infrastructure/cert-manager/overlays/dev/cluster-issuer.yaml` (ACME email) and `workloads/devops-lab/base/ingress.yaml` (hostnames) before expecting TLS to work.

---

## Current GitOps — update infrastructure

```bash
# Edit helm-values/dev/*.yaml, then:
make render

# Commit values + infrastructure/*/base/manifests.yaml; Argo CD syncs automatically
```

Local Helm install (for `make render` / `scripts/render-charts.sh`):

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

## Current GitOps — Grafana (GitOps-managed stack)

Grafana is exposed via NodePort **32000** (`helm-values/dev/kube-prometheus-stack.yaml`). Default admin password in values is `changeme` (change for anything beyond lab).

```bash
# If using NodePort on the cluster node IP:
# http://<node-ip>:32000

# Password from Helm-rendered secret (release name kube-prometheus-stack):
kubectl get secret kube-prometheus-stack-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

---

## Migration from old layout

If upgrading a cluster that used the monolithic `infrastructure` Application or manual Helm installs:

```bash
# Remove old app-of-apps child (if still present)
kubectl delete application infrastructure -n argocd --ignore-not-found

# Remove manual Helm release that conflicts with GitOps (host port 9100, duplicate operators)
helm list -n monitoring
helm uninstall kube-prometheus -n monitoring   # example: old manual release name

# Bootstrap new layout
kubectl apply -f bootstrap/argocd-app.yml
```

**Argo CD:** this repo no longer needs Helm-in-Kustomize. Remove `--enable-helm` from `argocd-cm` if you added it earlier:

```bash
kubectl edit configmap argocd-cm -n argocd
# Remove kustomize.buildOptions: --enable-helm (plain YAML + Kustomize only)
```

---

## Docker build and push (devops-lab image)

```bash
cd app/
docker build -t ghcr.io/tekne-ops/devops-lab:latest .
```

```bash
echo "YOUR_GITHUB_PAT" | docker login ghcr.io -u dvaliente-tekne --password-stdin
```

```bash
docker push ghcr.io/tekne-ops/devops-lab:latest
```

```bash
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=YOURUSER \
  --docker-password=YOURPASS \
  --docker-email=YOUREMAIL \
  --namespace devops-lab
```

---

## Argo CD setup

Install Argo CD on a new cluster:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Credentials:** username is `admin`, password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Register Helm chart repos in Argo CD **(legacy — only if using `--enable-helm` in Argo)**:

```bash
argocd repo add https://kubernetes.github.io/ingress-nginx --type helm
argocd repo add https://prometheus-community.github.io/helm-charts --type helm
argocd repo add https://grafana.github.io/helm-charts --type helm
```

**(legacy)** Enable Helm inside Kustomize builds:

```bash
kubectl edit configmap argocd-cm -n argocd
# Add under data:
#   kustomize.buildOptions: --enable-helm --load-restrictor LoadRestrictionsNone
```

---

## Prometheus and Grafana — manual Helm install (legacy)

Do **not** use on clusters managed by this repo’s Argo apps (conflicts with `kube-prometheus-stack` / `loki` / `k8s-monitoring`). Kept for reference or one-off labs.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install kube-prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
helm install loki grafana/loki-stack -n monitoring
```

```bash
kubectl patch svc kube-prometheus-grafana -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'
```

```bash
kubectl get secret kube-prometheus-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

---

## Trivy security scanning

```bash
sudo pacman -Sy --needed trivy
trivy config .
trivy image ghcr.io/YOUR_USER/devops-lab:latest
trivy image --severity HIGH,CRITICAL ghcr.io/tekne-ops/devops-lab:latest
```

---

## Troubleshooting

```bash
# Argo CD application status
kubectl get applications -n argocd

# Sync a single app (CLI or patch)
argocd app sync k8s-monitoring
kubectl patch application k8s-monitoring -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check Alloy / monitoring pods
kubectl get pods -n monitoring
kubectl get alloy -n monitoring
kubectl get crd alloys.collectors.grafana.com
```

---

## Reference — sample Argo CD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-dev
  namespace: argocd
spec:
  project: apps
  destination:
    namespace: devops-lab
    server: https://kubernetes.default.svc
  source:
    repoURL: https://github.com/tekne-ops/gitops-platform
    path: workloads/devops-lab/overlays/dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Reference — folder roles (historical)

| Path | Role |
|------|------|
| `apps/` | Argo CD Application definitions per environment |
| `projects/` | AppProjects (RBAC, allowed repos/namespaces) |
| `infrastructure/` | Rendered cluster infra (Kustomize base + overlays) |
| `workloads/` | Application manifests (Kustomize base + overlays) |
| `bootstrap/` | Root app-of-apps entrypoint |
| `helm-values/` | Helm values; rendered by `scripts/render-charts.sh` |
