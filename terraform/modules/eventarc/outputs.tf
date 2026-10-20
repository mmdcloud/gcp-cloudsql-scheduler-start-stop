output "id" {
  description = "Fully qualified ID of the Eventarc trigger (projects/{project}/locations/{location}/triggers/{name})."
  value       = google_eventarc_trigger.this.id
}

output "name" {
  description = "Name of the Eventarc trigger."
  value       = google_eventarc_trigger.this.name
}

output "location" {
  description = "Location of the Eventarc trigger."
  value       = google_eventarc_trigger.this.location
}

output "uid" {
  description = "Server-assigned unique ID of the trigger."
  value       = google_eventarc_trigger.this.uid
}

output "etag" {
  description = "Etag of the trigger."
  value       = google_eventarc_trigger.this.etag
}

output "conditions" {
  description = "Status conditions reported by Eventarc for the trigger."
  value       = google_eventarc_trigger.this.conditions
}

output "transport" {
  description = "Transport details, including the Pub/Sub topic Eventarc creates when none is supplied."
  value       = google_eventarc_trigger.this.transport
}