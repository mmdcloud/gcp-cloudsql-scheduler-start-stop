location    = "us-central1"
project_id  = "encoded-alpha-457108-e8"
environment = "dev"
prefix      = "carshub"

bucket_location = "ASIA-SOUTH1"

cvd_update_schedule = "0 */6 * * *"
cvd_update_timezone = "Asia/Kolkata"

labels = {
  project     = "carshub"
  environment = "dev"
  managed_by  = "terraform"
}