locals {
  common_labels = merge(
    var.labels,
    {
      managed_by = "terraform"
    }
  )
}

resource "google_eventarc_trigger" "this" {
  project                 = var.project_id
  name                    = var.name
  location                = var.location
  service_account         = var.service_account
  channel                 = var.channel
  event_data_content_type = var.event_data_content_type
  labels                  = local.common_labels

  dynamic "matching_criteria" {
    for_each = var.matching_criteria
    content {
      attribute = matching_criteria.value.attribute
      value     = matching_criteria.value.value
      operator  = matching_criteria.value.operator
    }
  }

  destination {
    dynamic "cloud_run_service" {
      for_each = var.destination.cloud_run_service != null ? [var.destination.cloud_run_service] : []
      content {
        service = cloud_run_service.value.service
        region  = coalesce(cloud_run_service.value.region, var.location)
        path    = cloud_run_service.value.path
      }
    }

    # Format: projects/{project}/locations/{location}/functions/{function}
    cloud_function = var.destination.cloud_function

    dynamic "gke" {
      for_each = var.destination.gke != null ? [var.destination.gke] : []
      content {
        cluster   = gke.value.cluster
        location  = gke.value.location
        namespace = gke.value.namespace
        service   = gke.value.service
        path      = gke.value.path
      }
    }

    workflow = var.destination.workflow

    dynamic "http_endpoint" {
      for_each = var.destination.http_endpoint != null ? [var.destination.http_endpoint] : []
      content {
        uri = http_endpoint.value.uri
      }
    }

    dynamic "network_config" {
      for_each = var.destination.network_config != null ? [var.destination.network_config] : []
      content {
        network_attachment = network_config.value.network_attachment
      }
    }
  }

  dynamic "transport" {
    for_each = var.transport != null ? [var.transport] : []
    content {
      dynamic "pubsub" {
        for_each = transport.value.pubsub != null ? [transport.value.pubsub] : []
        content {
          topic = pubsub.value.topic
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition = length([
        for d in [
          var.destination.cloud_run_service,
          var.destination.cloud_function,
          var.destination.gke,
          var.destination.workflow,
          var.destination.http_endpoint,
        ] : d if d != null
      ]) == 1
      error_message = "Exactly one of cloud_run_service, cloud_function, gke, workflow, or http_endpoint must be set in var.destination."
    }
  }
}