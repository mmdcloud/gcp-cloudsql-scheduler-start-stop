variable "project_id" {
  description = "Project ID in which the Eventarc trigger is created."
  type        = string
}

variable "name" {
  description = "Name of the Eventarc trigger."
  type        = string
}

variable "location" {
  description = "Location of the trigger (e.g. us-central1, or a multi-region like us / eu for Cloud Storage events)."
  type        = string
}

variable "service_account" {
  description = "Email of the service account Eventarc uses to invoke the destination."
  type        = string
  default     = null
}

variable "channel" {
  description = "Optional full channel resource name (projects/{project}/locations/{location}/channels/{channel}) for third-party event sources."
  type        = string
  default     = null
}

variable "event_data_content_type" {
  description = "Content type of the event payload, e.g. application/json. Null uses the API default."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to apply to the trigger. managed_by = terraform is merged in automatically."
  type        = map(string)
  default     = {}
}

variable "matching_criteria" {
  description = "Event filters. Must include an attribute = \"type\" entry. operator can be \"match-path-pattern\" for path pattern matching; null means exact match."
  type = list(object({
    attribute = string
    value     = string
    operator  = optional(string)
  }))

  validation {
    condition     = length([for c in var.matching_criteria : c if c.attribute == "type"]) == 1
    error_message = "matching_criteria must contain exactly one entry with attribute = \"type\"."
  }
}

variable "destination" {
  description = <<-EOT
    Where events are delivered. Set exactly one of:
      - cloud_run_service: { service, region (optional, defaults to var.location), path (optional) }
      - cloud_function:    full resource name string (projects/{p}/locations/{l}/functions/{f})
      - gke:               { cluster, location, namespace, service, path (optional) }
      - workflow:          full resource name string (projects/{p}/locations/{l}/workflows/{w})
      - http_endpoint:     { uri }, optionally with network_config
  EOT
  type = object({
    cloud_run_service = optional(object({
      service = string
      region  = optional(string)
      path    = optional(string)
    }))
    cloud_function = optional(string)
    gke = optional(object({
      cluster   = string
      location  = string
      namespace = string
      service   = string
      path      = optional(string)
    }))
    workflow = optional(string)
    http_endpoint = optional(object({
      uri = string
    }))
    network_config = optional(object({
      network_attachment = string
    }))
  })
}

variable "transport" {
  description = "Optional transport config. Only needed when delivering via a specific Pub/Sub topic."
  type = object({
    pubsub = optional(object({
      topic = string
    }))
  })
  default = null
}