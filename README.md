# TP Cloud Computing — AKS Kubernetes B3 Ynov

Déploiement d'une infrastructure cloud complète sur Azure : IaC avec OpenTofu, cluster Kubernetes (AKS) avec Istio, application multi-tiers et stack d'observabilité.

## Architecture

```
Internet
    │
    ▼
Azure Load Balancer (IP: 172.189.23.10)
    │
    ▼
Istio Gateway (namespace: istio-system)
    │
    ├── /            → Frontend (nginx, namespace: demo)
    ├── /api         → Backend Node.js (namespace: demo)
    ├── /metrics     → Backend /metrics (Prometheus scrape)
    └── /grafana     → Grafana (namespace: monitoring)
    
Cluster AKS (francecentral)
├── namespace: demo
│   ├── frontend     (nginx + HTML statique)
│   ├── backend      (Node.js + prom-client)
│   └── postgres     (PostgreSQL)
└── namespace: monitoring
    ├── prometheus   (scrape métriques)
    ├── grafana      (dashboards)
    ├── loki         (logs)
    ├── tempo        (traces)
    ├── alloy        (collecteur Grafana)
    └── otel-collector (OpenTelemetry)
```

## Prérequis

- [OpenTofu](https://opentofu.org/) v1.8+
- [Azure CLI](https://docs.microsoft.com/cli/azure/) v2.87+
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/) v3.17+
- [Helmfile](https://helmfile.readthedocs.io/) v0.169+
- Un compte Azure avec une subscription active

## Structure du projet

```
.
├── envs/dev/              # Configuration OpenTofu (IaC)
│   ├── providers.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars   # (non commité - contient les secrets)
├── modules/
│   ├── network/           # Module Azure VNet + Subnet
│   └── aks/               # Module AKS cluster
├── monitoring/            # Valeurs Helm pour la stack observabilité
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   ├── tempo/
│   ├── alloy/
│   └── otel-collector/
├── istio/                 # Charts et config Istio
├── TP/
│   ├── api/               # Backend Node.js (server.js)
│   ├── frontend/          # Frontend (index.html)
│   └── k8s/               # Manifestes Kubernetes
│       ├── backend.yaml
│       ├── frontend.yaml
│       ├── postgres.yaml
│       ├── httproutes.yaml
│       └── servicemonitor.yaml
└── helmfile.yaml.gotmpl
```

## Déploiement

### 1. Authentification Azure

```bash
az login
az account set --subscription <subscription-id>
```

### 2. Provisionner l'infrastructure (OpenTofu)

```bash
cd envs/dev
tofu init
tofu plan
tofu apply
```

Récupérer les credentials AKS :

```bash
az aks get-credentials --resource-group rg-tp-iac --name aks-tp
```

### 3. Déployer toute la stack en une seule commande

```bash
cd envs/dev
tofu apply
```

OpenTofu déploie automatiquement dans le bon ordre :
1. Infrastructure Azure (RG, VNet, AKS)
2. CRDs Gateway API + ServiceMonitor
3. Istio (base → istiod → mesh-config + gateway)
4. Stack monitoring (Prometheus, Loki, Tempo, Alloy, OTel, Grafana)
5. Application demo (HTTPRoutes)

### 4. Déployer les manifestes applicatifs

```bash
kubectl apply -f TP/k8s/postgres.yaml
kubectl apply -f TP/k8s/backend.yaml
kubectl apply -f TP/k8s/frontend.yaml
kubectl apply -f TP/k8s/httproutes.yaml
```

### 5. Accès

| Service   | URL                              | Credentials  |
|-----------|----------------------------------|--------------|
| Frontend  | http://172.189.23.10/            | —            |
| API       | http://172.189.23.10/api/messages| —            |
| Grafana   | http://172.189.23.10/grafana     | admin / admin|

## Observabilité

### Métriques (Prometheus + Grafana)

Le backend expose des métriques Prometheus sur `/metrics` :
- `http_requests_total` — nombre total de requêtes
- `http_request_duration_seconds` — latence des requêtes

Dashboard Grafana **"TP Backend Monitoring"** avec 3 panels :
- Requêtes par seconde : `rate(http_requests_total{app="backend"}[1m])`
- Latence p95 : `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="backend"}[1m]))`
- Taux d'erreurs : `rate(http_requests_total{app="backend", status=~"4.."}[1m])`

### Logs (Loki + Alloy)

Alloy collecte les logs de tous les pods et les envoie à Loki.

### Traces (Tempo + OTel Collector)

OpenTelemetry Collector reçoit les traces OTLP et les transfère à Tempo.

## Technologies utilisées

| Outil | Version | Rôle |
|-------|---------|------|
| OpenTofu | 1.8.8 | IaC (Infrastructure as Code) |
| Azure AKS | K8s 1.35 | Cluster Kubernetes managé |
| Istio | latest | Service mesh + ingress |
| Prometheus | latest | Collecte de métriques |
| Grafana | 13.1.0 | Dashboards |
| Loki | 3.7.3 | Agrégation de logs |
| Tempo | 2.10.7 | Distributed tracing |
| Grafana Alloy | 1.17.0 | Collecteur d'observabilité |
| Node.js | 18 | Backend API |
| PostgreSQL | 15 | Base de données |
| nginx | alpine | Frontend |
