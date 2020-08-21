variable "mysql-password" {}
variable "mysql-dir" {}
variable "wordpress-dir" {}
variable "mysql-img" {}
variable "mysql-lbl" {}
variable "wordpress-port" {}
variable "wordpress-img" {}
variable "wordpress-host" {}
variable "wordpress-lbl" {}

provider "kubernetes" {
  load_config_file = true
}

resource "kubernetes_secret" "mysql" {
  metadata {
    name = "mysql-pass"
  }
  data = {
    password = var.mysql-password
  }
}
resource "kubernetes_deployment" "wp-dep-mysql" {
  metadata {
    name = "wp-dep-mysql"
    labels = {
      app = var.mysql-lbl
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = var.mysql-lbl
      }
    }

    template {
      metadata {
        labels = {
          app = var.mysql-lbl
        }
      }

      spec {
        container {
          image = var.mysql-img
          name  = "wp-mysql"
          env {
           name = "MYSQL_ROOT_PASSWORD"
           value_from {
             secret_key_ref {
               name = kubernetes_secret.mysql.metadata.0.name
               key = "password"
             }
           }
          }
          port {
            container_port = 3306
            name = "mysql"
          }
          volume_mount {
            name = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }
        }
        volume {
          name = "mysql-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wp-pvc-mysql.metadata.0.name
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "wp-svc-mysql" {
  metadata {
    name = "wp-mysql"
  }
  spec {
    selector = {
      app = var.mysql-lbl
    }
    port {
      port = 3306
    }
    cluster_ip = "None"
  }
}

resource "kubernetes_deployment" "wp-dep-wordpress" {
  metadata {
    name = "wp-dep-wordpress"
    labels = {
      app = var.wordpress-lbl
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = var.wordpress-lbl
      }
    }

    template {
      metadata {
        labels = {
          app = var.wordpress-lbl
        }
      }

      spec {
        container {
          image = var.wordpress-img
          name  = "wordpress"
          env {
            name = "WORDPRESS_DB_HOST"
            value = "wp-mysql"
          }

          env {
            name = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata.0.name
                key = "password"
              }
            }
          }


          port {
            container_port = var.wordpress-port
            name = "wordpress"
          }
          volume_mount {
            name = "wordpress-persistent-storage"
            mount_path = "/var/www/html"
          }
        }
        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wp-pvc-wordpress.metadata.0.name
          }
        }

      }
    }
  }
}
resource "kubernetes_service" "wp-svc-wordpress" {
  metadata {
    name = "wp-svc-wordpress"
  }
  spec {
    selector = {
      app = var.wordpress-lbl
    }
    port {
      port = var.wordpress-port
    }

    type = "NodePort"
  }
}
resource "kubernetes_ingress" "wp-ingress" {
  metadata {
    name = "wordpress-ingress"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    rule {
      host = var.wordpress-host
      http {
        path {
          backend {
            service_name = kubernetes_service.wp-svc-wordpress.metadata[0].name
            service_port = var.wordpress-port
          }
          path = "/"
        }
      }
    }
  }
}
output "summary" {
  value = {
     mysql-img           = kubernetes_deployment.wp-dep-mysql.spec[0].template[0].spec[0].container[0].image
     mysql-vol           = kubernetes_persistent_volume.wp-pv-mysql.spec[0].persistent_volume_source[0].host_path[0].path
     wordpress-img       = kubernetes_deployment.wp-dep-wordpress.spec[0].template[0].spec[0].container[0].image
     wordpress-vol       = kubernetes_persistent_volume.wp-pv-wordpress.spec[0].persistent_volume_source[0].host_path[0].path
     url                 = kubernetes_ingress.wp-ingress.spec[0].rule[0].host
  }
}



