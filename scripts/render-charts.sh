#!/usr/bin/env bash
# Render Helm charts to infrastructure/*/base/manifests.yaml (and crds.yaml where needed).
# Run locally or in CI when helm-values change.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALUES="${ROOT}/helm-values/dev"
HELM="${HELM:-helm}"

CHART_INGRESS_VERSION="4.10.0"
CHART_CERT_MANAGER_VERSION="v1.14.4"
CHART_PROMETHEUS_CRDS_VERSION="19.0.0"
CHART_KPS_VERSION="65.8.0"
CHART_LOKI_VERSION="5.43.0"
CHART_K8S_MONITORING_VERSION="4.1.3"

render() {
  local release=$1 chart=$2 version=$3 namespace=$4 values=$5 outdir=$6
  shift 6
  mkdir -p "${outdir}"
  echo "Rendering ${release} (${chart} ${version}) -> ${outdir}"
  "${HELM}" template "${release}" "${chart}" \
    --version "${version}" \
    --namespace "${namespace}" \
    -f "${values}" \
    "$@" \
    > "${outdir}/manifests.yaml"
}

"${HELM}" repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
"${HELM}" repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
"${HELM}" repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
"${HELM}" repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
"${HELM}" repo update >/dev/null

# Prometheus Operator CRDs (sync before kube-prometheus-stack)
mkdir -p "${ROOT}/infrastructure/prometheus-operator-crds/base"
"${HELM}" template prometheus-operator-crds prometheus-community/prometheus-operator-crds \
  --version "${CHART_PROMETHEUS_CRDS_VERSION}" \
  > "${ROOT}/infrastructure/prometheus-operator-crds/base/manifests.yaml"
cat > "${ROOT}/infrastructure/prometheus-operator-crds/base/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - manifests.yaml
EOF

render cert-manager jetstack/cert-manager "${CHART_CERT_MANAGER_VERSION}" cert-manager \
  "${VALUES}/cert-manager.yaml" "${ROOT}/infrastructure/cert-manager/base"

render ingress-nginx ingress-nginx/ingress-nginx "${CHART_INGRESS_VERSION}" ingress-nginx \
  "${VALUES}/ingress-nginx.yaml" "${ROOT}/infrastructure/ingress-nginx/base" --skip-crds

render loki grafana/loki "${CHART_LOKI_VERSION}" monitoring \
  "${VALUES}/loki.yaml" "${ROOT}/infrastructure/loki/base" --skip-crds

render kube-prometheus-stack prometheus-community/kube-prometheus-stack "${CHART_KPS_VERSION}" monitoring \
  "${VALUES}/kube-prometheus-stack.yaml" "${ROOT}/infrastructure/kube-prometheus-stack/base" --skip-crds

# Alloy CRDs from k8s-monitoring chart (sync before k8s-monitoring)
mkdir -p "${ROOT}/infrastructure/alloy-crds/base"
"${HELM}" show crds grafana/k8s-monitoring \
  --version "${CHART_K8S_MONITORING_VERSION}" \
  | awk 'BEGIN{first=1} /^apiVersion:/ { if (!first) print "---"; first=0 } { print }' \
  > "${ROOT}/infrastructure/alloy-crds/base/manifests.yaml"
cat > "${ROOT}/infrastructure/alloy-crds/base/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - manifests.yaml
EOF

render k8s-monitoring grafana/k8s-monitoring "${CHART_K8S_MONITORING_VERSION}" monitoring \
  "${VALUES}/k8s-monitoring.yaml" "${ROOT}/infrastructure/k8s-monitoring/base" --skip-crds

for dir in cert-manager ingress-nginx loki kube-prometheus-stack k8s-monitoring; do
  cat > "${ROOT}/infrastructure/${dir}/base/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - manifests.yaml
EOF
done

echo "Done. Review changes under infrastructure/*/base/ and commit."
