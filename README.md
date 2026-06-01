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

