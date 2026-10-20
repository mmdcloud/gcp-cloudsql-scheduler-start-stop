variable "project" {
  description = "The ID of the project to create the scheduler job in. If omitted, the provider default project is used."
  type        = string
  default     = null
}

variable "name" {
  description = "The name of the job."
  type        = string
}

variable "schedule" {
  description = "Cron or App Engine schedule syntax."
  type        = string

  validation {
    condition     = length(split(" ", var.schedule)) >= 5 || can(regex("^(every|first|second)", var.schedule))
    error_message = "Schedule must be standard 5-part cron syntax (e.g. '0 9 * * *') or App Engine syntax."
  }
}

variable "description" {
  description = "A human-readable description for the job."
  type        = string
  default     = null
}

variable "time_zone" {
  description = "Specifies the time zone to be used in interpreting schedule. Default is UTC."
  type        = string
  default     = "UTC"
}

variable "region" {
  description = "Region where the scheduler job resides."
  type        = string
  default     = null
}

variable "attempt_deadline" {
  description = "The deadline for job attempts in seconds, e.g. '320s'."
  type        = string
  default     = null
}

variable "paused" {
  description = "Sets the job to paused or running."
  type        = bool
  default     = false
}

variable "pubsub_target" {
  description = "Pub/Sub target configuration."
  type = object({
    topic_name = string
    attributes = optional(map(string))
    data       = optional(string) # Pass raw unencoded text; module handles base64 encoding.
  })
  default = null
}

variable "http_target" {
  description = "HTTP target configuration."
  type = object({
    uri         = string
    http_method = optional(string, "POST")
    headers     = optional(map(string))
    body        = optional(string) # Pass raw unencoded text; module handles base64 encoding.
    oauth_token = optional(object({
      service_account_email = string
      scope                 = optional(string)
    }))
    oidc_token = optional(object({
      service_account_email = string
      audience              = optional(string)
    }))
  })
  default = null

  validation {
    condition = var.http_target == null || !(
      try(var.http_target.oauth_token != null, false) &&
      try(var.http_target.oidc_token != null, false)
    )
    error_message = "Cannot configure both oauth_token and oidc_token on http_target."
  }

  validation {
    condition = var.http_target == null || !(
      contains(["GET", "HEAD"], try(var.http_target.http_method, "POST")) &&
      try(var.http_target.body != null, false)
    )
    error_message = "A request body cannot be specified when http_method is GET or HEAD."
  }
}

variable "app_engine_http_target" {
  description = "App Engine HTTP target configuration."
  type = object({
    relative_uri = string
    http_method  = optional(string, "POST")
    headers      = optional(map(string))
    body         = optional(string) # Pass raw unencoded text; module handles base64 encoding.
    app_engine_routing = optional(object({
      service  = optional(string)
      version  = optional(string)
      instance = optional(string)
    }))
  })
  default = null
}

variable "retry_config" {
  description = "Retry configuration for the job."
  type = object({
    retry_count          = optional(number)
    max_retry_duration   = optional(string)
    min_backoff_duration = optional(string)
    max_backoff_duration = optional(string)
    max_doublings        = optional(number)
  })
  default = null
}
