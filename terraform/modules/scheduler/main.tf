resource "google_cloud_scheduler_job" "this" {
  project          = var.project
  name             = var.name
  description      = var.description
  schedule         = var.schedule
  time_zone        = var.time_zone
  region           = var.region
  attempt_deadline = var.attempt_deadline
  paused           = var.paused

  dynamic "pubsub_target" {
    for_each = var.pubsub_target != null ? [var.pubsub_target] : []
    content {
      topic_name = pubsub_target.value.topic_name
      attributes = pubsub_target.value.attributes
      data       = pubsub_target.value.data != null ? base64encode(pubsub_target.value.data) : null
    }
  }

  dynamic "http_target" {
    for_each = var.http_target != null ? [var.http_target] : []
    content {
      uri         = http_target.value.uri
      http_method = http_target.value.http_method
      headers     = http_target.value.headers
      body        = http_target.value.body != null ? base64encode(http_target.value.body) : null

      dynamic "oauth_token" {
        for_each = http_target.value.oauth_token != null ? [http_target.value.oauth_token] : []
        content {
          service_account_email = oauth_token.value.service_account_email
          scope                 = oauth_token.value.scope
        }
      }

      dynamic "oidc_token" {
        for_each = http_target.value.oidc_token != null ? [http_target.value.oidc_token] : []
        content {
          service_account_email = oidc_token.value.service_account_email
          audience              = oidc_token.value.audience
        }
      }
    }
  }

  dynamic "app_engine_http_target" {
    for_each = var.app_engine_http_target != null ? [var.app_engine_http_target] : []
    content {
      relative_uri = app_engine_http_target.value.relative_uri
      http_method  = app_engine_http_target.value.http_method
      headers      = app_engine_http_target.value.headers
      body         = app_engine_http_target.value.body != null ? base64encode(app_engine_http_target.value.body) : null

      dynamic "app_engine_routing" {
        for_each = app_engine_http_target.value.app_engine_routing != null ? [app_engine_http_target.value.app_engine_routing] : []
        content {
          service  = app_engine_routing.value.service
          version  = app_engine_routing.value.version
          instance = app_engine_routing.value.instance
        }
      }
    }
  }

  dynamic "retry_config" {
    for_each = var.retry_config != null ? [var.retry_config] : []
    content {
      retry_count          = retry_config.value.retry_count
      max_retry_duration   = retry_config.value.max_retry_duration
      min_backoff_duration = retry_config.value.min_backoff_duration
      max_backoff_duration = retry_config.value.max_backoff_duration
      max_doublings        = retry_config.value.max_doublings
    }
  }

  lifecycle {
    precondition {
      condition = length([
        for t in [var.http_target, var.pubsub_target, var.app_engine_http_target] : t if t != null
      ]) == 1
      error_message = "Exactly one of var.http_target, var.pubsub_target, or var.app_engine_http_target must be specified."
    }
  }
}
