# # NOTE: Only module.scanner.service_name / service_uri are confirmed by your
# # config. The other module outputs below assume common names (connection_name,
# # instance_name, private_ip_address, trigger_id, job_id, topic_name, ...).
# # Adjust them to match the outputs.tf of your own modules.

# ############################################
# # Cloud SQL
# ############################################
# output "carshub_db_instance_name" {
#   description = "Cloud SQL instance name"
#   value       = module.carshub_db.instance_name
# }

# output "carshub_db_connection_name" {
#   description = "Cloud SQL connection name (project:region:instance)"
#   value       = module.carshub_db.connection_name
# }

# output "carshub_db_private_ip" {
#   description = "Private IP of the Cloud SQL instance"
#   value       = module.carshub_db.private_ip_address
# }

# ############################################
# # Malware scanner
# ############################################
# output "scanner_service_name" {
#   description = "Cloud Run malware scanner service name"
#   value       = module.scanner.service_name
# }

# output "scanner_service_uri" {
#   description = "Cloud Run malware scanner URI"
#   value       = module.scanner.service_uri
# }

# ############################################
# # Eventarc
# ############################################
# output "start_sql_trigger_id" {
#   description = "Eventarc trigger ID (start)"
#   value       = module.start_sql_trigger.id
# }

# output "stop_sql_trigger_id" {
#   description = "Eventarc trigger ID (stop)"
#   value       = module.stop_sql_trigger.id
# }

# ############################################
# # Cloud Scheduler
# ############################################
# output "start_scheduler_job_id" {
#   description = "Scheduler job ID (start)"
#   value       = module.start_scheduler.id
# }

# output "stop_scheduler_job_id" {
#   description = "Scheduler job ID (stop)"
#   value       = module.stop_scheduler.id
# }

# ############################################
# # Pub/Sub
# ############################################
# output "start_topic_name" {
#   description = "Pub/Sub topic name (start)"
#   value       = module.start_topic.topic_name
# }

# output "stop_topic_name" {
#   description = "Pub/Sub topic name (stop)"
#   value       = module.stop_topic.topic_name
# }