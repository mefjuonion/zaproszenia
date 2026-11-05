variable "GITHUB_REPO_NAME" {
  type        = string
  description = "GitHub repository name (e.g. github.event.repository.name)"
}

variable "GCP_BILLING_ACCOUNT_ID" {
  type        = string
  description = "Cloud Billing Account ID (format: XXXXXX-XXXXXX-XXXXXX)"

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.GCP_BILLING_ACCOUNT_ID))
    error_message = "GCP_BILLING_ACCOUNT_ID must match the format XXXXXX-XXXXXX-XXXXXX."
  }
}

# Optional variables come from GitHub secrets, where an unset secret is an empty
# string, so "" is treated the same as not set (see locals in main.tf).

variable "GCP_ORG_ID" {
  type        = string
  description = "GCP organization ID (optional, empty = none)"
  default     = ""
}

variable "GCP_FOLDER_ID" {
  type        = string
  description = "GCP folder ID (optional, empty = none)"
  default     = ""

  validation {
    condition     = var.GCP_FOLDER_ID == "" || var.GCP_ORG_ID == ""
    error_message = "Set either GCP_ORG_ID or GCP_FOLDER_ID, not both."
  }
}

variable "GCP_DNS_PROJECT_ID" {
  type        = string
  description = "ID of the project hosting the Cloud DNS zone (optional, empty = vocal-gist-508519-h7)"
  default     = ""
}

variable "GCP_DNS_MANAGED_ZONE_NAME" {
  type        = string
  description = "Name of the Cloud DNS managed zone for the base domain"

  validation {
    condition     = var.GCP_DNS_MANAGED_ZONE_NAME != ""
    error_message = "GCP_DNS_MANAGED_ZONE_NAME is required (is the GitHub secret set?)."
  }
}

variable "DNS_BASE_DOMAIN" {
  type        = string
  description = "Base domain under which app subdomains are created"
  default     = "mateuszcybulski.cv"
}

variable "GCP_SERVICES_TO_ENABLE" {
  type        = list(string)
  description = "APIs to enable in the new project"
  default = [
    "run.googleapis.com",
    "compute.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "aiplatform.googleapis.com",
  ]
}

variable "GCP_REGION" {
  type        = string
  description = "Region for Cloud Run and Artifact Registry (must support Cloud Run domain mappings)"
  default     = "europe-west1"
}

variable "IMAGE_TAG" {
  type        = string
  description = "Tag for built images (CI uses the commit SHA); a new value triggers rebuild and redeploy"
}
