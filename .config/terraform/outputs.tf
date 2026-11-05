output "project_id" {
  description = "ID of the created GCP project"
  value       = google_project.app_project.project_id
}

output "project_number" {
  description = "Number of the created GCP project"
  value       = google_project.app_project.number
}

output "region" {
  description = "Region of Cloud Run and Artifact Registry"
  value       = var.GCP_REGION
}

output "service_urls" {
  description = "Public URL of every deployed service"
  value       = { for name, svc in local.services : name => "https://${svc.domain}" }
}
