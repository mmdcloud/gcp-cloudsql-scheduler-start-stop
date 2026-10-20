module "carshub_db" {
  source                      = "./modules/cloud-sql"
  name                        = "db-instance"
  db_name                     = "db-instance"
  db_user                     = module.carshub_sql_username_secret.secret_data
  db_version                  = "MYSQL_8_0"
  location                    = var.location
  tier                        = "db-f1-micro" # db-custom-2-8192
  availability_type           = "ZONAL"
  disk_size                   = 10 # GB
  disk_type                   = "PD_SSD"
  disk_autoresize             = true
  disk_autoresize_limit       = 50 # GB
  ipv4_enabled                = false
  deletion_protection_enabled = false # true for production

  backup_configuration = [
    {
      enabled                        = true
      binary_log_enabled             = true
      start_time                     = "03:00"
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
      value = "on"
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

  vpc_self_link = module.carshub_vpc.self_link
  vpc_id        = module.carshub_vpc.vpc_id
  password      = module.carshub_sql_password_secret.secret_data
  depends_on    = [module.carshub_sql_password_secret]
}

module "start_sql_trigger" {
  source = "./modules/eventarc"

  project_id      = var.project_id
  name            = "start-sql-trigger"
  location        = lower(var.bucket_location)
  service_account = google_service_account.eventarc.email
  labels          = var.labels

  matching_criteria = [
    {
      attribute = "type"
      value     = "google.cloud.storage.object.v1.finalized"
    },
    {
      attribute = "bucket"
      value     = local.unscanned_bucket_name
    }
  ]

  destination = {
    cloud_run_service = {
      service = module.scanner.service_name # your module's output, see below
      region  = var.region
      path    = "/"
    }
  }

  depends_on = [
    local.required_services,
    google_project_iam_member.gcs_pubsub_publisher,
    google_project_iam_member.eventarc_receiver,
    google_cloud_run_v2_service_iam_member.eventarc_run_invoker
  ]
}

module "stop_sql_trigger" {
  source = "./modules/eventarc"

  project_id      = var.project_id
  name            = "stop-sql-trigger"
  location        = lower(var.bucket_location)
  service_account = google_service_account.eventarc.email
  labels          = var.labels

  matching_criteria = [
    {
      attribute = "type"
      value     = "google.cloud.storage.object.v1.finalized"
    },
    {
      attribute = "bucket"
      value     = local.unscanned_bucket_name
    }
  ]

  destination = {
    cloud_run_service = {
      service = module.scanner.service_name # your module's output, see below
      region  = var.region
      path    = "/"
    }
  }

  depends_on = [
    local.required_services,
    google_project_iam_member.gcs_pubsub_publisher,
    google_project_iam_member.eventarc_receiver,
    google_cloud_run_v2_service_iam_member.eventarc_run_invoker
  ]
}

module "start_scheduler" {
  source = "./modules/scheduler"

  project          = var.project_id
  name             = "${var.prefix}-cvd-update-job"
  description      = "Triggers ClamAV Virus Database mirror synchronization on the Malware Scanner service"
  region           = var.region
  schedule         = var.cvd_update_schedule
  time_zone        = var.cvd_update_timezone
  attempt_deadline = "600s"

  retry_config = {
    retry_count          = 3
    max_retry_duration   = "300s"
    min_backoff_duration = "5s"
    max_backoff_duration = "60s"
  }

  http_target = {
    uri         = "${module.scanner.service_uri}/update"
    http_method = "POST"

    oidc_token = {
      service_account_email = google_service_account.scheduler[0].email
      audience              = module.scanner.service_uri
    }
  }

  depends_on = [
    local.required_services,
    google_cloud_run_v2_service_iam_member.scheduler_run_invoker
  ]
}

module "stop_scheduler" {
  source = "./modules/scheduler"

  project          = var.project_id
  name             = "${var.prefix}-cvd-update-job"
  description      = "Triggers ClamAV Virus Database mirror synchronization on the Malware Scanner service"
  region           = var.region
  schedule         = var.cvd_update_schedule
  time_zone        = var.cvd_update_timezone
  attempt_deadline = "600s"

  retry_config = {
    retry_count          = 3
    max_retry_duration   = "300s"
    min_backoff_duration = "5s"
    max_backoff_duration = "60s"
  }

  http_target = {
    uri         = "${module.scanner.service_uri}/update"
    http_method = "POST"

    oidc_token = {
      service_account_email = google_service_account.scheduler[0].email
      audience              = module.scanner.service_uri
    }
  }

  depends_on = [
    local.required_services,
    google_cloud_run_v2_service_iam_member.scheduler_run_invoker
  ]
}

module "start_topic" {
  source     = "./modules/pubsub"
  project_id = var.project_id
  topic_name = "finops-resource-sweeper-dlq-topic"

  topic_iam = {
    members = [
      {
        role   = "roles/pubsub.publisher"
        member = "serviceAccount:${local.pubsub_service_account_email}"
      }
    ]
  }

  subscriptions = {
    finops-resource-sweeper-dlq-sub = {
      subscription_name          = "finops-resource-sweeper-dlq-sub"
      message_retention_duration = "604800s"
      ttl                        = ""
      retain_acked_messages      = false
      ack_deadline_seconds       = 60
    }
  }
}

module "stop_topic" {
  source     = "./modules/pubsub"
  project_id = var.project_id
  topic_name = "finops-resource-sweeper-dlq-topic"

  topic_iam = {
    members = [
      {
        role   = "roles/pubsub.publisher"
        member = "serviceAccount:${local.pubsub_service_account_email}"
      }
    ]
  }

  subscriptions = {
    finops-resource-sweeper-dlq-sub = {
      subscription_name          = "finops-resource-sweeper-dlq-sub"
      message_retention_duration = "604800s"
      ttl                        = ""
      retain_acked_messages      = false
      ack_deadline_seconds       = 60
    }
  }
}