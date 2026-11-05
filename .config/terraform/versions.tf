terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  # Configured at init time: -backend-config="bucket=..." -backend-config="prefix=apps/<repo>"
  backend "gcs" {}
}

provider "google" {}

data "google_client_config" "current" {}

provider "docker" {
  registry_auth {
    address  = "${var.GCP_REGION}-docker.pkg.dev"
    username = "oauth2accesstoken"
    password = data.google_client_config.current.access_token
  }
}
