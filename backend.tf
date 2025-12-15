# Remote backend configuration
# ============================
#
# Uncomment ONLY ONE of the sections below depending on your client's preference.
# Remote state is ESSENTIAL for real client work: collaboration, locking, backup.
#
# For clients who want to avoid any cloud provider entirely → use Terraform Cloud (HCP Terraform).
# It's the most convenient zero-ops option with a generous free tier.

terraform {

  # ------------------------------
  # OPTION 1: AWS S3 + DynamoDB (most common for AWS clients)
  # ------------------------------
#   backend "s3" {
#     bucket         = "client-name-terraform-state"      # Required: existing S3 bucket
#     key            = "warehouse-fivetran/prod.tfstate"  # Path inside bucket
#     region         = "us-east-1"                        # Bucket region
#     dynamodb_table = "terraform-locks"                  # Optional but recommended for state locking
#     encrypt        = true                               # Server-side encryption
#   }

  # ------------------------------
  # OPTION 2: Azure Blob Storage (azurerm backend)
  # ------------------------------
#   backend "azurerm" {
#     resource_group_name  = "terraform-state-rg"         # Existing resource group
#     storage_account_name = "tfstateprod123"             # Existing storage account
#     container_name       = "tfstate"                    # Existing container
#     key                  = "prod.terraform.tfstate"     # Blob name
#     # use_azuread_auth = true                           # Optional: use Azure AD instead of keys
#   }

  # ------------------------------
  # OPTION 3: Google Cloud Storage (gcs backend)
  # ------------------------------
  # backend "gcs" {
  #   bucket  = "client-name-terraform-state"             # Existing GCS bucket
  #   prefix  = "warehouse-fivetran/prod"                 # Optional folder path inside bucket
  #   # credentials = "/path/to/service-account.json"     # Optional if not using default ADC
  # }

  # ------------------------------
  # OPTION 4: Terraform Cloud / HCP Terraform (recommended for non-AWS/Azure/GCP clients)
  # ------------------------------
  # NOTE: Do NOT use a "backend" block for Terraform Cloud.
  # Instead, add a "cloud" block in main.tf (we'll add this later) like:
  #
  # cloud {
  #   organization = "your-org-name"
  #   workspaces {
  #     name = "warehouse-fivetran-prod"
  #   }
  # }
  #
  # Benefits: No infra to manage, free tier, built-in locking, remote runs, collaboration.
  # Clients just need a free HCP Terraform account → create org + workspace → fill in.

  # ------------------------------
  # FALLBACK: Local backend (only for solo dev/testing – never for clients)
  # ------------------------------
  # backend "local" {
  #   path = "terraform.tfstate"
  # }

}