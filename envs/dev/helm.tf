# ============================================================
# Déploiement Helm via OpenTofu — remplace helmfile sync
# Ordre : Gateway API CRDs → Istio → Monitoring → App
# ============================================================

# --- Namespaces ---------------------------------------------

resource "kubernetes_namespace" "istio_system" {
  metadata { name = "istio-system" }
  depends_on = [module.aks]
}

resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
  depends_on = [module.aks]
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
    labels = {
      "istio-injection" = "enabled"
    }
  }
  depends_on = [helm_release.istiod]
}

# --- Gateway API CRDs (kubectl apply via null_resource) -----
# Les CRDs Gateway API ne font pas partie des charts Istio,
# on les installe une fois avant tout le reste.

resource "terraform_data" "gateway_api_crds" {
  triggers_replace = [module.aks.cluster_name]

  provisioner "local-exec" {
    command = "kubectl apply --validate=false -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml"
  }

  depends_on = [module.aks]
}

# --- ServiceMonitor CRD -------------------------------------

resource "terraform_data" "servicemonitor_crd" {
  triggers_replace = [module.aks.cluster_name]

  provisioner "local-exec" {
    command = "kubectl apply --validate=false -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.75.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml"
  }

  depends_on = [module.aks]
}

# --- Istio --------------------------------------------------

resource "helm_release" "istio_base" {
  name             = "istio-base"
  namespace        = kubernetes_namespace.istio_system.metadata[0].name
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = "1.30.2"
  create_namespace = false

  values = [file("${path.module}/../../istio/base-values.yaml")]

  depends_on = [terraform_data.gateway_api_crds]
}

resource "helm_release" "istiod" {
  name             = "istiod"
  namespace        = kubernetes_namespace.istio_system.metadata[0].name
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  version          = "1.30.2"
  create_namespace = false

  values = [file("${path.module}/../../istio/istiod-values.yaml")]

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_mesh_config" {
  name             = "istio-mesh-config"
  namespace        = kubernetes_namespace.istio_system.metadata[0].name
  chart            = "${path.module}/../../istio/mesh-config"
  create_namespace = false

  set {
    name  = "gateway.enabled"
    value = "true"
  }

  depends_on = [helm_release.istiod]
}

# --- Prometheus ---------------------------------------------

resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = "29.14.0"
  create_namespace = false

  values = [file("${path.module}/../../monitoring/prometheus/values.yaml")]

  depends_on = [
    terraform_data.servicemonitor_crd,
    helm_release.istio_mesh_config,
  ]
}

# --- Loki ---------------------------------------------------

resource "helm_release" "loki" {
  name             = "loki"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  repository       = "https://grafana-community.github.io/helm-charts/"
  chart            = "loki"
  version          = "18.3.1"
  create_namespace = false

  values = [file("${path.module}/../../monitoring/loki/values.yaml")]

  depends_on = [helm_release.istio_mesh_config]
}

# --- Tempo --------------------------------------------------

resource "helm_release" "tempo" {
  name             = "tempo"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  repository       = "https://grafana-community.github.io/helm-charts/"
  chart            = "tempo"
  version          = "2.2.3"
  create_namespace = false

  values = [file("${path.module}/../../monitoring/tempo/values.yaml")]

  depends_on = [helm_release.prometheus]
}

# --- Alloy --------------------------------------------------

resource "helm_release" "alloy" {
  name             = "alloy"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "alloy"
  version          = "1.10.0"
  create_namespace = false

  values = [file("${path.module}/../../monitoring/alloy/values.yaml")]

  depends_on = [helm_release.loki]
}

# --- OpenTelemetry Collector --------------------------------

resource "helm_release" "otel_collector" {
  name             = "otel-collector"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = "0.162.0"
  create_namespace = false

  values = [file("${path.module}/../../monitoring/otel-collector/values.yaml")]

  depends_on = [
    helm_release.prometheus,
    helm_release.loki,
    helm_release.tempo,
  ]
}

# --- Grafana ------------------------------------------------

resource "helm_release" "grafana" {
  name             = "grafana"
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  repository       = "https://grafana-community.github.io/helm-charts/"
  chart            = "grafana"
  version          = "12.7.2"
  create_namespace = false

  values = [file("${path.module}/../../monitoring/grafana/values.yaml")]

  # Injecte le parentRef de la Gateway Istio (équivalent du template helmfile)
  set {
    name  = "route.main.parentRefs[0].name"
    value = "istio-gateway"
  }
  set {
    name  = "route.main.parentRefs[0].namespace"
    value = "istio-system"
  }
  set {
    name  = "route.main.parentRefs[0].sectionName"
    value = "web"
  }

  depends_on = [
    helm_release.istio_mesh_config,
    helm_release.prometheus,
    helm_release.loki,
    helm_release.tempo,
  ]
}

# --- Application TP (Frontend + Backend + PostgreSQL + HTTPRoutes) -----------

resource "helm_release" "tp_app" {
  name             = "tp-app"
  namespace        = kubernetes_namespace.demo.metadata[0].name
  chart            = "${path.module}/../../tp-app"
  create_namespace = false

  set {
    name  = "gatewayName"
    value = "istio-gateway"
  }
  set {
    name  = "gatewayNamespace"
    value = "istio-system"
  }

  depends_on = [
    helm_release.istio_mesh_config,
    kubernetes_namespace.demo,
  ]
}
