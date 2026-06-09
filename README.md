# GitOps Platform

Declarative Kubernetes platform using **Argo CD** and **Kustomize**. Helm charts are rendered in CI (or via `make render`) to plain YAML for predictable, reviewable syncs.

**Setup commands, Docker/Helm/Argo install, migration, and troubleshooting:** see [docs/runbook.md](docs/runbook.md).

## Structure

```
gitops-platform/
├── bootstrap/           # Root Application (app-of-apps entrypoint)
├── apps/
│   ├── dev/             # Argo CD Application manifests (split per component)
│   ├── uat/
│   └── prod/
├── projects/            # Argo CD AppProjects (infra + apps RBAC)
├── helm-values/         # Helm values only (source of truth for chart config)
│   ├── dev/
│   └── prod/
├── infrastructure/      # Rendered manifests + Kustomize overlays
│   ├── namespaces/
│   ├── prometheus-operator-crds/
│   ├── alloy-crds/
│   ├── cert-manager/
│   ├── ingress-nginx/
│   ├── loki/
│   ├── kube-prometheus-stack/
│   └── k8s-monitoring/
├── workloads/           # Application manifests (Kustomize base + overlays)
└── scripts/
    └── render-charts.sh # Renders helm-values → infrastructure/*/base/
```

## Monitoring stack

| Component | Role |
|-----------|------|
| **kube-prometheus-stack** | Prometheus, Grafana, Alertmanager, node-exporter |
| **Loki** | Log storage (single-binary, filesystem) |
| **k8s-monitoring** | Grafana Alloy collectors → pod logs & cluster events to Loki |

Grafana UI: `http://<node-ip>:32001`

**Username:** `admin`

**Password:**

```bash
kubectl get secret kube-prometheus-stack-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo
```

## Bootstrap

```bash
kubectl apply -f bootstrap/argocd-app.yml
```

This creates the `platform-dev` Application, which syncs all apps under `apps/dev/`:

| App | Sync wave | Namespace |
|-----|-----------|-----------|
| projects | -3 | argocd |
| namespaces | -1 | — |
| prometheus-operator-crds | 0 | monitoring |
| cert-manager | 1 | cert-manager |
| ingress-nginx | 2 | ingress-nginx |
| loki | 3 | monitoring |
| kube-prometheus-stack | 4 | monitoring |
| alloy-crds | 4 | monitoring |
| k8s-monitoring | 5 | monitoring |
| devops-lab | 10 | devops-lab |

## Updating infrastructure

1. Edit values in `helm-values/dev/`
2. Re-render manifests:

```bash
make render
```

3. Commit both values and rendered `infrastructure/*/base/manifests.yaml`
4. Argo CD syncs automatically

## Prerequisites (manual, once per cluster)

```bash
# Cloudflare token for cert-manager DNS-01
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=YOUR_TOKEN \
  -n cert-manager

# Image pull secret for devops-lab
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=YOURUSER \
  --docker-password=YOURPASS \
  --namespace devops-lab
```

## Production notes

- Enable PVCs + `storageClassName` in `helm-values/prod/`
- Replace `grafana.adminPassword: changeme` with External Secrets / Sealed Secrets
- Use `apps/prod/` with HA replica counts and resource limits
- Do not use `emptyDir` for Loki/Prometheus in production

## Argo CD kustomize (legacy clusters)

If migrating from Helm-in-Kustomize, ensure `argocd-cm` no longer requires `--enable-helm` for this repo.
