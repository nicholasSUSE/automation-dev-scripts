terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 1.10.6"
    }
  }
}

provider "rancher2" {
  api_url = "https://192.168.1.10:8443/v3"
  access_key = "token-9dvrb"
  secret_key = "mvcrwlfzcm7nx4m66hfk8scsl6zpm4lp9jmcvg7bvklffqf2c2cn2g"
  insecure = true 
}

data "rancher2_cluster" "cluster" {
  name = "local" 
}

# data "rancher2_cluster" "cluster2" {
#   name = "ubu" 
# }

resource "rancher2_project" "project" {
  name = "terraproject"
  cluster_id = data.rancher2_cluster.cluster.id
  description = "My new project for debugging"
}

# resource "rancher2_project" "project2" {
#   name = "terraproject"
#   cluster_id = data.rancher2_cluster.cluster2.id
#   description = "My new project for debugging"
# }

resource "rancher2_namespace" "namespace" {
  name = "terraspace"
  project_id = rancher2_project.project.id
  description = "My new namespace for debugging"
}

resource "rancher2_namespace" "namespace2" {
  name = "terraspace-3"
  project_id = rancher2_project.project.id
}