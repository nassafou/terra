variable "yoz-ns" {}
variable "yoz-port" {}
variable "yoz-img" {}
variable "yoz-lbl-app" {}
variable "yoz-lbl-env" {}
variable "yoz-path" {} 

provider "kubernetes" {
  load_config_file = true
}

resource "kubernetes_namespace" "yoz" {
  metadata {
    name = var.yoz-ns
    labels = {
      env = var.yoz-lbl-env
    }
  }
}
resource "kubernetes_pod" "monpremierpod" {
  metadata {
    name = "webserver"
    labels = {
      App = var.yoz-lbl-app
      env = var.yoz-lbl-env
    }
    namespace = kubernetes_namespace.yoz.metadata[0].name
  }

  spec {
    container {
      image = var.yoz-img
      name  = "mynginx"

      port {
        container_port = var.yoz-port
      }
    }
  }
}
resource "kubernetes_service" "monpremierservice" {
  metadata {
    name = "webserver-service"
    namespace = kubernetes_namespace.yoz.metadata[0].name
  }
  spec {
    selector = {
      App = kubernetes_pod.monpremierpod.metadata[0].labels.App
    }
    port {
      port = var.yoz-port
    }

    type = "NodePort"
  }
}
resource "kubernetes_service" "monsecondservice" {
  metadata {
    name = "webserver-service-inter"
  }
  spec {
    type = "ExternalName"
    external_name = "webserver-service.yoz.svc.cluster.local"
  }
}


resource "kubernetes_ingress" "monpremieringress" {
  metadata {
    name = "webserver-ingress"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    rule {
      http {
        path {
          backend {
            service_name = kubernetes_service.monsecondservice.metadata[0].name
            service_port = var.yoz-port
          }

          path = var.yoz-path
        }
      }
    }
  }
}

output "app" {
  value = {
    namespace	= kubernetes_namespace.yoz.metadata[0].name
    name 	= kubernetes_pod.monpremierpod.metadata[0].name
    container 	= kubernetes_pod.monpremierpod.spec[0].container[0].name
    service 	= kubernetes_service.monpremierservice.spec[0].port[0].node_port
    path 	= kubernetes_ingress.monpremieringress.spec[0].rule[0].http[0].path[0].path
  }
}

