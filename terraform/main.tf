locals {
  scheduler_agent   = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
  sql_instance_name = "db-instance"
}

data "vault_generic_secret" "sql" {
  path = "secret/sql"
}

data "google_project" "project" {}

module "vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  subnets                         = []
  firewall_data                   = []
}

module "sql_username_secret" {
  source              = "./modules/secret-manager"
  is_regional         = false
  deletion_protection = false
  secret_data         = tostring(data.vault_generic_secret.sql.data["username"])
  secret_id           = "db-username-secret"
}

module "sql_password_secret" {
  source              = "./modules/secret-manager"
  is_regional         = false
  deletion_protection = false
  secret_data         = tostring(data.vault_generic_secret.sql.data["password"])
  secret_id           = "db-password-secret"
}

module "db" {
  source                      = "./modules/cloud-sql"
  name                        = local.sql_instance_name
  db_name                     = "db-instance"
  db_user                     = module.sql_username_secret.secret_data
  db_version                  = "MYSQL_8_0"
  location                    = var.location
  tier                        = "db-f1-micro" # db-custom-2-8192
  availability_type           = "ZONAL"
  disk_size                   = 10 # GB
  disk_type                   = "PD_SSD"
  disk_autoresize             = true
  disk_autoresize_limit       = 50 # GB
  ipv4_enabled                = false
  deletion_protection_enabled = false

  backup_configuration = [
    {
      enabled                        = true
      binary_log_enabled             = true
      start_time                     = "06:00"
      location                       = var.location
      point_in_time_recovery_enabled = false
      backup_retention_settings = [
        {
          retained_backups = 30
          retention_unit   = "COUNT"
        }
      ]
    }
  ]

  database_flags = [
    {
      name  = "general_log"
      value = "off"
    },
    {
      name  = "log_queries_not_using_indexes"
      value = "off"
    },
    {
      name  = "skip_show_database"
      value = "on"
    },
    {
      name  = "slow_query_log"
      value = "on"
    },
    {
      name  = "long_query_time"
      value = "2"
    },
    {
      name  = "log_output"
      value = "FILE"
    }
  ]

  vpc_self_link = module.vpc.self_link
  vpc_id        = module.vpc.vpc_id
  password      = module.sql_password_secret.secret_data
  depends_on    = [module.sql_password_secret, module.sql_username_secret]
}

resource "google_service_account" "eventarc" {
  account_id   = "eventarc-sa"
  display_name = "Eventarc Trigger Service Account"
  project      = var.project_id
  description  = "Dedicated identity for Eventarc to invoke the Cloud Run function"
}

# Eventarc Event Receiver Role
resource "google_project_iam_member" "eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc.email}"
}

resource "google_cloud_run_service_iam_member" "eventarc_invoker" {
  project  = var.project_id
  location = var.location
  service  = module.handler_function.function_name # 2nd gen function's Cloud Run service shares the name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.eventarc.email}"
}

module "start_sql_trigger" {
  source = "./modules/eventarc"

  project_id      = var.project_id
  name            = "start-sql-trigger"
  location        = var.location
  service_account = google_service_account.eventarc.email
  labels          = var.labels

  matching_criteria = [
    {
      attribute = "type"
      value     = "google.cloud.pubsub.topic.v1.messagePublished"
    }
  ]

  transport = {
    pubsub = {
      topic = module.start_topic.topic_id
    }
  }

  destination = {
    cloud_run_service = {
      service = module.handler_function.function_name
      region  = var.location
    }
  }

  depends_on = [
    module.handler_function,
    module.start_topic,
    google_project_iam_member.eventarc_receiver,
    google_cloud_run_service_iam_member.eventarc_invoker,
  ]
}

module "stop_sql_trigger" {
  source = "./modules/eventarc"

  project_id      = var.project_id
  name            = "stop-sql-trigger"
  location        = var.location
  service_account = google_service_account.eventarc.email
  labels          = var.labels

  matching_criteria = [
    {
      attribute = "type"
      value     = "google.cloud.pubsub.topic.v1.messagePublished"
    }
  ]

  transport = {
    pubsub = {
      topic = module.stop_topic.topic_id
    }
  }

  destination = {
    cloud_run_service = {
      service = module.handler_function.function_name
      region  = var.location
    }
  }

  depends_on = [
    module.handler_function,
    module.start_topic,
    google_project_iam_member.eventarc_receiver,
    google_cloud_run_service_iam_member.eventarc_invoker,
  ]
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "sql-schedule-alerts"
  type         = "email"
  labels       = { email_address = var.alert_email }
}

resource "google_monitoring_alert_policy" "sql_schedule_failures" {
  display_name = "Cloud SQL start/stop failures"
  combiner     = "OR"

  conditions {
    display_name = "handler errors"
    condition_matched_log {
      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"handler-function\" AND severity>=ERROR"
    }
  }
  conditions {
    display_name = "scheduler job errors"
    condition_matched_log {
      filter = "resource.type=\"cloud_scheduler_job\" AND severity>=ERROR"
    }
  }

  alert_strategy {
    notification_rate_limit { period = "300s" }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
}

module "start_scheduler" {
  source = "./modules/scheduler"

  project          = var.project_id
  name             = "start-cloudsql-job"
  description      = "Scheduler to start cloudsql instance"
  region           = var.location
  schedule         = "0 9 * * 1-5"
  time_zone        = "Asia/Kolkata"
  attempt_deadline = "600s"

  retry_config = {
    retry_count          = 3
    max_retry_duration   = "300s"
    min_backoff_duration = "5s"
    max_backoff_duration = "60s"
  }

  pubsub_target = {
    topic_name = module.start_topic.topic_id
    data       = base64encode(jsonencode({ action = "start", label = "env=dev" }))
  }


}

module "stop_scheduler" {
  source = "./modules/scheduler"

  project          = var.project_id
  name             = "stop-cloudsql-job"
  description      = "Scheduler to stop cloudsql instance"
  region           = var.location
  schedule         = "0 17 * * 1-5"
  time_zone        = "Asia/Kolkata"
  attempt_deadline = "600s"

  retry_config = {
    retry_count          = 3
    max_retry_duration   = "300s"
    min_backoff_duration = "5s"
    max_backoff_duration = "60s"
  }

  pubsub_target = {
    topic_name = module.stop_topic.topic_id
    data       = base64encode(jsonencode({ action = "stop", label = "env=dev" }))
  }
  
  depends_on = [
    module.stop_topic,
  ]
}

module "start_topic" {
  source     = "./modules/pubsub"
  project_id = var.project_id
  topic_name = "start-instance-event"

  topic_iam = {
    members = [
      {
        role   = "roles/pubsub.publisher"
        member = local.scheduler_agent
      }
    ]
  }
}

module "stop_topic" {
  source     = "./modules/pubsub"
  project_id = var.project_id
  topic_name = "stop-instance-event"

  topic_iam = {
    members = [
      {
        role   = "roles/pubsub.publisher"
        member = local.scheduler_agent
      }
    ]
  }
}

module "handler_function_bucket_code" {
  source     = "./modules/gcs"
  project_id = var.project_id
  location   = var.location
  name       = "${var.project_id}-handler-function-code"
  cors       = []
  contents = [
    {
      name        = "handler_function_bucket_code.zip"
      source_path = "${path.root}/files/handler_function_bucket_code.zip"
      content     = ""
    }
  ]
  force_destroy               = true # false for production
  uniform_bucket_level_access = true
}

resource "google_project_iam_custom_role" "sql_start_stop" {
  role_id     = "cloudSqlStartStop"
  title       = "Cloud SQL Start/Stop"
  permissions = ["cloudsql.instances.get", "cloudsql.instances.list", "cloudsql.instances.update"]
}

module "function_app_service_account" {
  source        = "./modules/service-account"
  account_id    = "function-app-sa"
  display_name  = "Service Account for handler function"
  project_id    = var.project_id
  member_prefix = "serviceAccount"
  permissions = [
    google_project_iam_custom_role.sql_start_stop.name,
    "roles/artifactregistry.reader"
  ]
}

module "handler_function" {
  source               = "./modules/cloud-run-function/event-function"
  function_name        = "handler-function"
  function_description = "A function to manage the status of the cloud sql instance based on pubsub payload"
  location             = var.location
  project_id           = var.project_id

  build_config = {
    handler = "handler"
    runtime = "python312"
    storage_source = {
      bucket = module.handler_function_bucket_code.bucket_name
      object = module.handler_function_bucket_code.bucket_objects["handler_function_bucket_code.zip"].name
    }
  }

  service_config = {
    max_instance_count               = 2
    min_instance_count               = 0
    available_memory                 = "256M"
    timeout_seconds                  = 60
    max_instance_request_concurrency = 80
    service_environment_variables = {
      PROJECT_ID    = var.project_id
      INSTANCE_NAME = local.sql_instance_name
    }
    available_cpu                  = "1"
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = module.function_app_service_account.sa_email
  }

  depends_on = [module.function_app_service_account]
}
