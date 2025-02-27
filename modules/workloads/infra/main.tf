resource "helm_release" "kube_state_metrics" {
  count            = var.enable_kube_state_metrics ? 1 : 0
  chart            = var.ksm_config.helm_chart_name
  create_namespace = var.ksm_config.create_namespace
  namespace        = var.ksm_config.k8s_namespace
  name             = var.ksm_config.helm_release_name
  version          = var.ksm_config.helm_chart_version
  repository       = var.ksm_config.helm_repo_url

  dynamic "set" {
    for_each = var.ksm_config.helm_settings
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "helm_release" "kube_cost" {
  count            = var.enable_kube_cost ? 1 : 0
  chart            = var.kc_config.helm_chart_name
  create_namespace = var.kc_config.create_namespace
  namespace        = var.kc_config.k8s_namespace
  name             = var.kc_config.helm_release_name
  version          = var.kc_config.helm_chart_version
  repository       = var.kc_config.helm_repo_url
  set {
    name  = "amp.enabled"
    value = "true"
  }
  set {
    name  = "amp.prometheusServerEndpoint"
    value = "http://localhost:8005/workspaces/ws-109ee092-56e2-4c17-ae69-b6c6ab29936d"
    type  = "string"
  }
  set {
    name  = "amp.remoteWriteService"
    value = "https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-109ee092-56e2-4c17-ae69-b6c6ab29936d/api/v1/remote_write"
    type  = "string"
  }
  set {
    name  = "amp.sigv4.region"
    value = "us-east-1"
    type  = "string"
  }
  set {
    name  = "amp.sigv4.region"
    value = "us-east-1"
    type  = "string"
  }

  set {
    name  = "sigV4Proxy.region"
    value = "us-east-1"
    type  = "string"
  }

  set {
    name  = "sigV4Proxy.host"
    value = "aps-workspaces.us-east-1.amazonaws.com"
    type  = "string"
  }

  dynamic "set" {
    for_each = var.kc_config.helm_settings
    content {
      name  = set.key
      value = set.value
    }
  }
} 
resource "helm_release" "prometheus_node_exporter" {
  count            = var.enable_node_exporter ? 1 : 0
  chart            = var.ne_config.helm_chart_name
  create_namespace = var.ne_config.create_namespace
  namespace        = var.ne_config.k8s_namespace
  name             = var.ne_config.helm_release_name
  version          = var.ne_config.helm_chart_version
  repository       = var.ne_config.helm_repo_url

  dynamic "set" {
    for_each = var.ne_config.helm_settings
    content {
      name  = set.key
      value = set.value
    }
  }
}

module "helm_addon" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints/modules/kubernetes-addons/helm-addon"

  helm_config = merge(
    {
      name        = local.name
      chart       = "${path.module}/otel-config"
      version     = "0.2.0"
      namespace   = local.namespace
      description = "ADOT helm Chart deployment configuration"
    },
    var.helm_config
  )

  set_values = [
    {
      name  = "ampurl"
      value = "${var.managed_prometheus_workspace_endpoint}api/v1/remote_write"
    },
    {
      name  = "region"
      value = var.managed_prometheus_workspace_region
    },
    {
      name  = "prometheusMetricsEndpoint"
      value = "metrics"
    },
    {
      name  = "prometheusMetricsPort"
      value = 8888
    },
    {
      name  = "scrapeInterval"
      value = "15s"
    },
    {
      name  = "scrapeTimeout"
      value = "10s"
    },
    {
      name  = "scrapeSampleLimit"
      value = 1000
    },
    {
      name  = "ekscluster"
      value = local.context.eks_cluster_id
    },
  ]

  irsa_config = {
    create_kubernetes_namespace       = true
    kubernetes_namespace              = local.namespace
    create_kubernetes_service_account = true
    kubernetes_service_account        = try(var.helm_config.service_account, local.name)
    irsa_iam_policies                 = ["arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"]
  }

  addon_context = local.context
}
