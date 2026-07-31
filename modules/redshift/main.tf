terraform {
  required_providers {
    redshift = {
      source  = "brainly/redshift"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Create database
resource "redshift_database" "main" {
  name  = var.database_name
  owner = var.admin_user_name
}

# Create schemas
resource "redshift_schema" "extract" {
  name  = var.extract_schema
  owner = var.admin_user_name
}
resource "redshift_schema" "transform" {
  name  = var.transform_schema
  owner = var.admin_user_name
}
resource "redshift_schema" "analysis" {
  name  = var.analysis_schema
  owner = var.admin_user_name
}

# Create service users
resource "random_password" "admin" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()_+-="
}
resource "random_password" "extract" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()_+-="
}
resource "random_password" "transform" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()_+-="
}
resource "random_password" "load" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()_+-="
}
resource "redshift_user" "admin" {
  name     = var.admin_user_name
  password = random_password.admin.result
}
resource "redshift_user" "extract" {
  name     = "EXTRACT"
  password = random_password.extract.result
}
resource "redshift_user" "transform" {
  name     = "TRANSFORM"
  password = random_password.transform.result
}
resource "redshift_user" "load" {
  name     = "LOAD"
  password = random_password.load.result
}

# Create groups and assign membership natively (no external psql step required)
resource "redshift_group" "admin" {
  name  = "admin_group"
  users = [redshift_user.admin.name]
}
resource "redshift_group" "extract" {
  name  = "extract_group"
  users = [redshift_user.extract.name]
}
resource "redshift_group" "transform" {
  name  = "transform_group"
  users = [redshift_user.transform.name]
}
resource "redshift_group" "load" {
  name  = "load_group"
  users = [redshift_user.load.name]
}
resource "redshift_group" "analyst" {
  name = "analyst_group"
}

# Assign permissions to groups
# Extract group (Fivetran writes to extract schema)
resource "redshift_grant" "extract_schema" {
  group       = redshift_group.extract.name
  schema      = redshift_schema.extract.name
  object_type = "schema"
  privileges  = ["CREATE", "USAGE", "INSERT", "UPDATE", "DELETE", "SELECT"]
}

# Transform group (read extract, write transform)
resource "redshift_grant" "transform_extract" {
  group       = redshift_group.transform.name
  schema      = redshift_schema.extract.name
  object_type = "schema"
  privileges  = ["USAGE", "SELECT"]
}
resource "redshift_grant" "transform_schema" {
  group       = redshift_group.transform.name
  schema      = redshift_schema.transform.name
  object_type = "schema"
  privileges  = ["CREATE", "USAGE"]
}
resource "redshift_grant" "transform_db" {
  group       = redshift_group.transform.name
  object_type = "database"
  privileges  = ["CREATE", "USAGE", "INSERT", "UPDATE", "DELETE", "SELECT"]
}

# Analysis / BI role (read analysis)
resource "redshift_grant" "load_analysis" {
  group       = redshift_group.load.name
  schema      = redshift_schema.analysis.name
  object_type = "schema"
  privileges  = ["USAGE", "SELECT"]
}

# Analyst group (read-only analysis — assign manually to human users)
resource "redshift_grant" "analyst_analysis" {
  group       = redshift_group.analyst.name
  schema      = redshift_schema.analysis.name
  object_type = "schema"
  privileges  = ["USAGE", "SELECT"]
}

# Admin group — read access across all schemas (mirrors the Snowflake ADMIN_ROLE design)
resource "redshift_grant" "admin_schemas" {
  for_each = toset([
    redshift_schema.extract.name, redshift_schema.transform.name,
    redshift_schema.analysis.name,
  ])
  group       = redshift_group.admin.name
  schema      = each.key
  object_type = "schema"
  privileges  = ["USAGE", "SELECT"]
}
