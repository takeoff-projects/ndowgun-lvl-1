terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

variable "project" {
  default     = "roi-takeoff-user92"
  type        = string
  description = "Google Cloud Platform Project ID"
}

provider "google" {
  credentials = file("~/skills_project/roi-takeoff-user92-7077302636ba.json")

  project = var.project
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_project_service" "crm" {
  service                    = "cloudresourcemanager.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
}

resource "google_project_service" "iam" {
  service                    = "iam.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
}

resource "google_project_service" "run" {
  service                    = "run.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
}

resource "google_project_service" "cloudbuild" {
  service                    = "cloudbuild.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
}

resource "google_project_service" "datastore" {
  service                    = "datastore.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
  depends_on = [
    google_project_service.crm
  ]
}

resource "google_project_service" "usage" {
  service                    = "serviceusage.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
  depends_on = [
    google_project_service.crm
  ]
}

resource "google_project_service" "cloudtrace" {
  service                    = "cloudtrace.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
  depends_on = [
    google_project_service.crm
  ]
}

resource "google_project_service" "compute" {
  service                    = "compute.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
  depends_on = [
    google_project_service.crm
  ]
}

resource "google_project_service" "container_registry" {
  service                    = "containerregistry.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
  depends_on = [
    google_project_service.crm
  ]
}

resource "google_project_service" "cloudapis" {
  service                    = "cloudapis.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = true
  depends_on = [
    google_project_service.datastore
  ]
}

resource "google_cloud_run_service" "default" {
  name     = "pets-srv"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/roi-takeoff-user92/go-pets:latest"
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.run
  ]
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
  depends_on  = [google_cloud_run_service.default]
}

# Create a service account
resource "google_service_account" "tf_gen_sa" {
  account_id   = "tf-gen-sa"
  display_name = "Terraform generated SA"
  depends_on = [
    google_project_service.iam
  ]
}

resource "google_service_account_key" "tf_gen_sa_key" {
  service_account_id = google_service_account.tf_gen_sa.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Set permissions
resource "google_project_iam_binding" "service_permissions" {
  for_each = toset([
    "run.admin",
    "datastore.owner",
    "appengine.appAdmin",
  ])

  role       = "roles/${each.key}"
  members    = ["serviceAccount:${google_service_account.tf_gen_sa.email}"]
  depends_on = [google_service_account.tf_gen_sa, google_project_service.crm]
}