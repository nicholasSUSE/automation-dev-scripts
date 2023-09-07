// Originally using version 2.11.0, but are now at 2.20.0 which has not been tested
resource "kubernetes_namespace" "namespaces" {
    for_each = var.namespaces
    metadata {
        annotations = {
            "lifecycle.cattle.io/create.namespace-auth" = "true"
            // Maybe make this accept null somehow to avoid errors
            "field.cattle.io/projectId"                 = "${rancher2_project.projects[each.value.project].id}" //"${data.rancher2_project.ns_projects[each.value.project].id}"
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

/*
Data passed in via yaml from file:
projects:
  TEST40:
    description: Test Client Project
  SDLC40:
    description: SDLC Client Project 2

namespaces:
  sdlc-test:
    project: TEST40
*/