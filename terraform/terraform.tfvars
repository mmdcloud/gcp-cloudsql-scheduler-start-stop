project_id  = "your-gcp-project-id"
region      = "asia-south1"
location    = "asia-south1"
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