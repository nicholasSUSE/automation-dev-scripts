terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.11.0"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 1.10.6"
    }
  }
}
# RANCHER RESOURCE PROVIDER

provider "rancher2" {
  api_url = "https://192.168.1.10:8443/v3"
  access_key = "token-6rk25"
  secret_key = "gnqbkvwhrbghmzmwxxk5r8w54hc65xzp8vgkq74cmn2rpfqb5rh9bt"
  insecure = true 
}

data "rancher2_cluster" "cluster" {
  name = "local" 
}

variable "projects" {
  description = "Projects to be created"
  type = map(object({
    name = string,
    description = string
  }))
  default = {
    "project1" = { name = "terraproject-1", description = "My 1st project for debugging" },
    "project2" = { name = "terraproject-2", description = "My 2nd project for debugging" }
  }
}

resource "rancher2_project" "projects" {
  for_each = var.projects

  name = each.value.name
  cluster_id = data.rancher2_cluster.cluster.id
  description = each.value.description
}

# KUBERNETES RESOURCE PROVIDER
provider "kubernetes" {
  config_path    = "~/.kube/config"   # Modify this to your actual config file
}



variable "namespaces" {
  description = "Namespaces to be created"
  type = map(object({
    project = string
  }))
  default = {
    "namespace1" = { project = "project1" },
    "namespace2" = { project = "project2" }
  }
}


resource "kubernetes_namespace" "namespaces" {
  for_each = var.namespaces
  metadata {
    annotations = {
      "lifecycle.cattle.io/create.namespace-auth" = "true"
      "field.cattle.io/projectId"                = "${rancher2_project.projects[each.value.project].id}" 
    }
    labels = {
      "terraform/project" = "${each.value.project}"
    }
    name = each.key
  }

  lifecycle {
    ignore_changes = [
        metadata[0].annotations["cattle.io/status"],
        metadata[0].labels["field.cattle.io/projectId"]
    ]
  }
}


