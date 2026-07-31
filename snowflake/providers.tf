# AWS - only used here if use_airflow = true. Credential validation is skipped
# entirely when Airflow isn't deployed, so a pure Snowflake + Fivetran client
# needs no AWS account at all.
provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = !local.needs_aws
  skip_region_validation      = !local.needs_aws
  skip_requesting_account_id  = !local.needs_aws
}

provider "snowflake" {
  account  = var.snowflake_account_identifier
  user     = var.snowflake_username
  password = var.snowflake_password
  role     = var.snowflake_role
}

# Fivetran - only used when use_fivetran = true
provider "fivetran" {
  api_key    = var.use_fivetran ? var.fivetran_api_key : "unused"
  api_secret = var.use_fivetran ? var.fivetran_api_secret : "unused"
}

# Random provider - always needed for generated passwords
provider "random" {
}
