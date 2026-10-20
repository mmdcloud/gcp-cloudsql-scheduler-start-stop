############################################
# Core
############################################
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region (Cloud Run, Scheduler, Pub/Sub)"
  type        = string
  default     = "asia-south1"
}

variable "location" {
  description = "Location for Cloud SQL instance and its backups"
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod). Used in resource naming"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "prefix" {
  description = "Prefix for resource names (eventarc triggers, scheduler jobs)"
  type        = string
}

variable "labels" {
  description = "Labels applied to supported resources"
  type        = map(string)
  default     = {}
}

############################################
# Storage / Eventarc
############################################
variable "bucket_location" {
  description = "Location of the GCS bucket; also used (lowercased) as the Eventarc trigger location"
  type        = string
  default     = "ASIA-SOUTH1"
}

############################################
# ClamAV CVD update scheduler
############################################
variable "cvd_update_schedule" {
  description = "Cron schedule for the ClamAV CVD mirror update job"
  type        = string
  default     = "0 */6 * * *"
}

variable "cvd_update_timezone" {
  description = "Time zone for the scheduler job"
  type        = string
  default     = "Asia/Kolkata"
}