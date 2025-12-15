# providers.tf

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.92.0"  # Latest stable as of Dec 2025
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.56.0"   # Latest stable as of Dec 2025
    }
    fivetran = {
      source  = "fivetran/fivetran"
      version = "~> 1.9.17"   # Latest stable as of Dec 2025
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

# Snowflake provider — active only when warehouse_type = "snowflake"
provider "snowflake" {
  count = local.use_snowflake ? 1 : 0

  account  = var.snowflake_account_identifier
  username = var.snowflake_username
  password = var.snowflake_password
  role     = var.snowflake_role
}

# Databricks provider — active only when warehouse_type = "databricks"
provider "databricks" {
  count = local.use_databricks ? 1 : 0

  host  = var.databricks_workspace_url
  token = var.databricks_token
}

# Redshift uses the AWS provider (no dedicated Redshift provider needed)
# AWS provider is always active since Redshift resources are in AWS
provider "aws" {
  count = local.use_redshift ? 1 : 0

  region = var.aws_region  # Assume you have var.aws_region defined
  # Add access_key/secret_key or role assumption if needed
}

# Fivetran provider — always active (controlled separately by use_fivetran)
provider "fivetran" {
  count = var.use_fivetran ? 1 : 0

  api_key    = var.fivetran_api_key
  api_secret = var.fivetran_api_secret
}