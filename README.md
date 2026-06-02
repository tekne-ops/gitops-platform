# GitOps Platform

This repository implements a **GitOps-based deployment model** for Kubernetes using **Argo CD**. It provides a clean, scalable, and environment-driven structure to manage both **applications** and **cluster infrastructure** declaratively.

---

## 📦 Recommended Structure (Clean & Scalable)

```
gitops-platform/
│
├── apps/
│   ├── dev/
│   │   └── my-app.yaml
│   ├── staging/
│   │   └── my-app.yaml
│   └── prod/
│       └── my-app.yaml
│
├── projects/
│   └── default-project.yaml
│
├── infrastructure/
│   ├── namespaces/
│   │   └── devops-lab.yaml
│   ├── ingress/
│   ├── cert-manager/
│   └── monitoring/
│
├── workloads/
│   └── my-app/
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           │   └── kustomization.yaml
│           ├── staging/
│           └── prod/
│
└── bootstrap/
    └── root-app.yaml
```

---

## 📁 Folder Breakdown

### apps/
Argo CD Application definitions (one per app per environment).
It does NOT contain resources itself, but points to them.

### projects/
Argo CD AppProjects for RBAC and governance.
  Which repos are allowed
  Which clusters/namespaces apps can deploy to
  Security boundaries (RBAC)
  Optional policies (sync, quotas, etc.)

### infrastructure/
Cluster-level resources like namespaces, ingress, and monitoring.

### workloads/
Application manifests using Kustomize (base + overlays).
Base should contain:
  Deployment
  Service
  ConfigMaps (generic)
  Labels
  Probes
  Default configuration
Base should contain:
  replicas (dev=1, prod=5)
  image tag (dev=latest, prod=stable)
  resources (dev=low, prod=high)
  env vars (debug=true in dev)
  ingress (maybe only in prod)

### bootstrap/
Root Argo CD app (App of Apps pattern).

---

## 🚀 Sample Argo CD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-dev
spec:
  destination:
    namespace: devops-lab
    server: https://kubernetes.default.svc
  source:
    repoURL: https://github.com/tekne-opsadvise/gitops-platform
    path: workloads/my-app/overlays/dev
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## ✅ Summary

Production-ready GitOps structure using Argo CD and Kustomize.

# modern-devops-platform

## Docker Build & Push

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

## Helm Setup

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

## ArgoCD Setup

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Credentials:** username is `admin`, password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

```bash
argocd repo add https://kubernetes.github.io/ingress-nginx --type helm
argocd repo add https://prometheus-community.github.io/helm-charts --type helm
argocd repo add https://grafana.github.io/helm-charts --type helm
```

```bash
kubectl edit configmap argocd-cm -n argocd
Add:
data:
  kustomize.buildOptions: --enable-helm
```

```bash
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=YOUR_TOKEN \
  -n cert-manager
```

## Prometheus & Grafana Setup

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus prometheus-community/kube-prometheus-stack
helm install loki grafana/loki-stack
```

```bash
kubectl patch svc kube-prometheus-grafana -n monitoring \
  -p '{"spec": {"type": "NodePort"}}'
```

```bash
kubectl get secret kube-prometheus-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

## Trivy Security Scanning

```bash
sudo pacman -Sy --needed trivy
trivy config .
trivy image ghcr.io/YOUR_USER/devops-lab:latest
trivy image --severity HIGH,CRITICAL ghcr.io/tekne-ops/devops-lab:latest
```