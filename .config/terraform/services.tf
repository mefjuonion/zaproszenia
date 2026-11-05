locals {
  repo_root = abspath("${path.module}/../..")

  # Every src/<name>/Dockerfile becomes a Cloud Run service built from src/<name>,
  # optionally configured by src/<name>/service.json.
  # "frontend" is served at <repo>.<domain>, any other service at <name>.<repo>.<domain>.
  service_names = toset([for f in fileset(local.repo_root, "src/*/Dockerfile") : split("/", f)[1]])

  service_domains = {
    for name in local.service_names : name => name == "frontend" ? local.base_domain : "${name}.${local.base_domain}"
  }

  # Injected into every service, e.g. FRONTEND_URL, API_URL.
  common_env = merge(
    { GOOGLE_CLOUD_PROJECT = google_project.app_project.project_id },
    { for name, domain in local.service_domains : "${upper(replace(name, "-", "_"))}_URL" => "https://${domain}" },
  )

  services = {
    for name in local.service_names : name => merge(
      {
        port          = 8080
        public        = true
        cpu           = "1"
        memory        = "512Mi"
        max_instances = 2
        env           = {}
        roles         = []
      },
      jsondecode(fileexists("${local.repo_root}/src/${name}/service.json") ? file("${local.repo_root}/src/${name}/service.json") : "{}"),
      {
        domain = local.service_domains[name]
        image  = "${var.GCP_REGION}-docker.pkg.dev/${google_project.app_project.project_id}/${google_artifact_registry_repository.app.repository_id}/${name}"
      },
    )
  }

  service_roles = {
    for pair in flatten([
      for name, svc in local.services : [for role in svc.roles : { service = name, role = role }]
    ]) : "${pair.service}/${pair.role}" => pair
  }
}

resource "google_artifact_registry_repository" "app" {
  project       = google_project.app_project.project_id
  location      = var.GCP_REGION
  repository_id = "app"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "2592000s"
    }
  }

  depends_on = [google_project_service.app_services]
}

resource "google_service_account" "service" {
  for_each = local.services

  project      = google_project.app_project.project_id
  account_id   = trim(substr("run-${each.key}", 0, 30), "-")
  display_name = "Cloud Run: ${each.key}"
}

resource "google_project_iam_member" "service" {
  for_each = local.service_roles

  project = google_project.app_project.project_id
  role    = each.value.role
  member  = google_service_account.service[each.value.service].member
}

resource "docker_image" "service" {
  for_each = local.services

  name = "${each.value.image}:${var.IMAGE_TAG}"

  build {
    context    = "${local.repo_root}/src/${each.key}"
    dockerfile = "Dockerfile"
    platform   = "linux/amd64"
  }
}

resource "docker_registry_image" "service" {
  for_each = local.services

  name          = docker_image.service[each.key].name
  keep_remotely = true

  triggers = {
    image_id = docker_image.service[each.key].image_id
  }
}

resource "google_cloud_run_v2_service" "service" {
  for_each = local.services

  project  = google_project.app_project.project_id
  location = var.GCP_REGION
  name     = each.key
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.service[each.key].email

    scaling {
      min_instance_count = 0
      max_instance_count = each.value.max_instances
    }

    containers {
      image = "${each.value.image}@${docker_registry_image.service[each.key].sha256_digest}"

      ports {
        container_port = each.value.port
      }

      resources {
        limits = {
          cpu    = each.value.cpu
          memory = each.value.memory
        }
        cpu_idle = true
      }

      dynamic "env" {
        for_each = merge(local.common_env, each.value.env)
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z][a-z0-9-]{0,47}[a-z0-9]$", each.key))
      error_message = "Directory src/${each.key} is not a valid Cloud Run service name (lowercase letters, digits and hyphens, starting with a letter)."
    }
  }

  depends_on = [google_project_service.app_services]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  for_each = { for name, svc in local.services : name => svc if svc.public }

  project  = google_cloud_run_v2_service.service[each.key].project
  location = google_cloud_run_v2_service.service[each.key].location
  name     = google_cloud_run_v2_service.service[each.key].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_domain_mapping" "service" {
  for_each = local.services

  project  = google_project.app_project.project_id
  location = var.GCP_REGION
  name     = each.value.domain

  metadata {
    namespace = google_project.app_project.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.service[each.key].name
  }
}

resource "google_dns_record_set" "service" {
  for_each = local.services

  project      = local.dns_project_id
  managed_zone = var.GCP_DNS_MANAGED_ZONE_NAME
  name         = "${each.value.domain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["ghs.googlehosted.com."]
}
