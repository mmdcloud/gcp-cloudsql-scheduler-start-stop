output "id" {
  description = "An identifier for the resource with format projects/{{project}}/locations/{{region}}/jobs/{{name}}"
  value       = google_cloud_scheduler_job.this.id
}

output "name" {
  description = "The name of the Cloud Scheduler job."
  value       = google_cloud_scheduler_job.this.name
}

output "state" {
  description = "State of the job (e.g., ENABLED, PAUSED, DISABLED)."
  value       = google_cloud_scheduler_job.this.state
}

output "schedule" {
  description = "The scheduled cron syntax."
  value       = google_cloud_scheduler_job.this.schedule
}

output "time_zone" {
  description = "The timezone configured for the job."
  value       = google_cloud_scheduler_job.this.time_zone
}

output "region" {
  description = "The region where the Cloud Scheduler job is provisioned."
  value       = google_cloud_scheduler_job.this.region
}

output "target_type" {
  description = "The active target type configured for this job (http, pubsub, or app_engine)."
  value = (
    var.http_target != null ? "http" :
    var.pubsub_target != null ? "pubsub" :
    var.app_engine_http_target != null ? "app_engine" : null
  )
}

output "job" {
  description = "The full google_cloud_scheduler_job resource object for advanced consumers."
  value       = google_cloud_scheduler_job.this
}