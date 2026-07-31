terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 0.92.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Configure a warehouse for each stage for cost-optimization purposes
resource "snowflake_warehouse" "extract" {
  name                = "EXTRACT_WH"
  warehouse_size      = var.snowflake_extract_wh_size
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Warehouse for Fivetran extract"
}
resource "snowflake_warehouse" "transform" {
  name                = "TRANSFORM_WH"
  warehouse_size      = var.snowflake_transform_wh_size
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Warehouse for dbt transformations"
}
resource "snowflake_warehouse" "analysis" {
  name                = "ANALYSIS_WH"
  warehouse_size      = var.snowflake_analysis_wh_size
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "Warehouse for analysis, BI tools & analysts"
}

# Configure databases within warehouses
resource "snowflake_database" "extract" {
  name    = "EXTRACT"
  comment = "Fivetran extract database (raw data)"
}
resource "snowflake_database" "transform" {
  name    = "TRANSFORM"
  comment = "dbt transformation database"
}
resource "snowflake_database" "analysis" {
  name    = "ANALYSIS"
  comment = "Analysis / BI / analyst-facing database"
}

# Configure schemas
resource "snowflake_schema" "extract" {
  name     = var.extract_schema
  database = snowflake_database.extract.name
  comment  = "Fivetran landing schema"
}
resource "snowflake_schema" "transform" {
  name     = var.transform_schema
  database = snowflake_database.transform.name
  comment  = "dbt model schema"
}
resource "snowflake_schema" "analysis" {
  name     = var.analysis_schema
  database = snowflake_database.analysis.name
  comment  = "Final forms for BI tools"
}

# Create the roles for handling permissions
resource "snowflake_role" "admin" {
  name    = "ADMIN_ROLE"
  comment = "Admin group - read access across all 3 DBs (senior analysts)"
}
resource "snowflake_role" "extract" {
  name    = "EXTRACT_ROLE"
  comment = "Role for Fivetran extract into the DB"
}
resource "snowflake_role" "transform" {
  name    = "TRANSFORM_ROLE"
  comment = "Role for dbt transformations"
}
resource "snowflake_role" "load" {
  name    = "LOAD_ROLE"
  comment = "Role for BI tool connections to the DB"
}
resource "snowflake_role" "analyst" {
  name    = "ANALYST_ROLE"
  comment = "Analyst group - read access to analysis DB only"
}

# Create the service users
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
resource "snowflake_user" "admin" {
  name                 = var.admin_user_name
  password             = random_password.admin.result
  default_role         = snowflake_role.admin.name
  default_warehouse    = snowflake_warehouse.analysis.name
  must_change_password = false
  comment              = "Admin user for full access"
}
resource "snowflake_user" "extract" {
  name                 = "EXTRACT"
  password             = random_password.extract.result
  default_role         = snowflake_role.extract.name
  default_warehouse    = snowflake_warehouse.extract.name
  must_change_password = false
  comment              = "Fivetran extract user"
}
resource "snowflake_user" "transform" {
  name                 = "TRANSFORM"
  password             = random_password.transform.result
  default_role         = snowflake_role.transform.name
  default_warehouse    = snowflake_warehouse.transform.name
  must_change_password = false
  comment              = "dbt transform user"
}
resource "snowflake_user" "load" {
  name                 = "LOAD"
  password             = random_password.load.result
  default_role         = snowflake_role.load.name
  default_warehouse    = snowflake_warehouse.analysis.name
  must_change_password = false
  comment              = "BI tool / load user for reading from the analysis database"
}

# Assign roles to users
resource "snowflake_grant_account_role" "admin_user" {
  role_name = snowflake_role.admin.name
  user_name = snowflake_user.admin.name
}
resource "snowflake_grant_account_role" "extract_user" {
  role_name = snowflake_role.extract.name
  user_name = snowflake_user.extract.name
}
resource "snowflake_grant_account_role" "transform_user" {
  role_name = snowflake_role.transform.name
  user_name = snowflake_user.transform.name
}
resource "snowflake_grant_account_role" "load_user" {
  role_name = snowflake_role.load.name
  user_name = snowflake_user.load.name
}

# Assign permissions to roles
# Extract role (Fivetran)
resource "snowflake_grant_privileges_to_account_role" "extract_wh" {
  privileges        = ["USAGE", "OPERATE"]
  account_role_name = snowflake_role.extract.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.extract.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "extract_db" {
  privileges        = ["USAGE", "CREATE SCHEMA", "CREATE TABLE"]
  account_role_name = snowflake_role.extract.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.extract.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "extract_schema" {
  privileges        = ["CREATE TABLE", "INSERT", "UPDATE", "DELETE", "USAGE"]
  account_role_name = snowflake_role.extract.name
  on_schema {
    schema_name = snowflake_database.extract.name
  }
}

# Transform role (dbt)
resource "snowflake_grant_privileges_to_account_role" "transform_wh1" {
  privileges        = ["USAGE", "OPERATE"]
  account_role_name = snowflake_role.transform.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.transform.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "transform_wh2" {
  privileges        = ["USAGE", "OPERATE"]
  account_role_name = snowflake_role.transform.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.extract.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "transform_dbs1" {
  privileges        = ["USAGE", "CREATE SCHEMA", "CREATE TABLE", "CREATE VIEW"]
  account_role_name = snowflake_role.transform.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.transform.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "transform_dbs2" {
  privileges        = ["USAGE", "SELECT"]
  account_role_name = snowflake_role.transform.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.extract.name
  }
}

# Analysis/BI role
resource "snowflake_grant_privileges_to_account_role" "load_wh" {
  privileges        = ["USAGE"]
  account_role_name = snowflake_role.load.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.analysis.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "load_db" {
  privileges        = ["USAGE"]
  account_role_name = snowflake_role.load.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.analysis.name
  }
}

# Analyst role
resource "snowflake_grant_privileges_to_account_role" "analysis_wh" {
  privileges        = ["USAGE"]
  account_role_name = snowflake_role.analyst.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.analysis.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "analysis_db" {
  privileges        = ["USAGE", "SELECT"]
  account_role_name = snowflake_role.analyst.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.analysis.name
  }
}

# Admin role (read access across all 3 databases)
resource "snowflake_grant_privileges_to_account_role" "admin_whs1" {
  privileges        = ["USAGE", "OPERATE"]
  account_role_name = snowflake_role.admin.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.extract.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "admin_whs2" {
  privileges        = ["USAGE", "OPERATE"]
  account_role_name = snowflake_role.admin.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.transform.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "admin_whs3" {
  privileges        = ["USAGE"]
  account_role_name = snowflake_role.admin.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.analysis.name
  }
}
resource "snowflake_grant_privileges_to_account_role" "admin_dbs" {
  for_each = {
    extract   = snowflake_database.extract.name
    transform = snowflake_database.transform.name
    analysis  = snowflake_database.analysis.name
  }
  privileges        = ["USAGE", "SELECT"]
  account_role_name = snowflake_role.admin.name
  on_account_object {
    object_type = "DATABASE"
    object_name = each.value
  }
}
