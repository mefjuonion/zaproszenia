resource "random_string" "project_suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  clean_name = trim(replace(lower(var.GITHUB_REPO_NAME), "/[^a-z0-9-]+/", "-"), "-")

  # 25-char prefix + "-" + 4-char suffix = 30, the GCP project_id limit.
  base_project_id = trim(substr(local.clean_name, 0, 25), "-")
  project_id      = "${local.base_project_id}-${random_string.project_suffix.result}"

  dns_label   = trim(substr(local.clean_name, 0, 63), "-")
  base_domain = "${local.dns_label}.${var.DNS_BASE_DOMAIN}"

  # Empty optional variables mean "not set".
  org_id         = var.GCP_ORG_ID != "" ? var.GCP_ORG_ID : null
  folder_id      = var.GCP_FOLDER_ID != "" ? var.GCP_FOLDER_ID : null
  dns_project_id = var.GCP_DNS_PROJECT_ID != "" ? var.GCP_DNS_PROJECT_ID : "vocal-gist-508519-h7"
}

resource "google_project" "app_project" {
  name            = substr(var.GITHUB_REPO_NAME, 0, 30)
  project_id      = local.project_id
  billing_account = var.GCP_BILLING_ACCOUNT_ID
  org_id          = local.org_id
  folder_id       = local.folder_id

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", local.project_id))
      error_message = "Computed project_id '${local.project_id}' is invalid (must start with a letter and be 6-30 characters long)."
    }
  }
}

resource "google_project_service" "app_services" {
  for_each = toset(var.GCP_SERVICES_TO_ENABLE)

  project = google_project.app_project.project_id
  service = each.value

  disable_on_destroy = false
}
