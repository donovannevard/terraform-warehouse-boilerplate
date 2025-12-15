# Resources only created when use_databricks = true

# Unity Catalog catalog (equivalent to Snowflake database)
resource "databricks_catalog" "main" {
  count = local.is_databricks ? 1 : 0

  name         = local.catalog_name
  comment      = "Main catalog for ${local.project_name}"
  connection   = null  # External connections optional
  storage_root = null  # Use default workspace storage

  # Tags not directly supported on catalog yet – use metastore-level if needed
}

# Default schema (volume + database equivalent)
resource "databricks_schema" "main" {
  count = local.is_databricks ? 1 : 0

  name         = "main"
  catalog_name = databricks_catalog.main[0].name
  comment      = "Default schema for raw and transformed data"
}

# Service Principal for ETL tools (Fivetran, Airflow, dbt)
resource "databricks_service_principal" "etl" {
  count = local.is_databricks ? 1 : 0

  application_id = random_uuid.etl[0].result  # Generates a UUID as client ID
  display_name   = local.etl_user_name
}

resource "random_uuid" "etl" {
  count = local.is_databricks ? 1 : 0
}

# Secret scope for storing the service principal secret (for Fivetran/Airflow)
resource "databricks_secret_scope" "etl" {
  count = local.is_databricks ? 1 : 0

  name = "${local.project_name}-etl-secrets"
}

# Generate and store application secret (client secret)
resource "databricks_secret" "etl_secret" {
  count = local.is_databricks ? 1 : 0

  key                  = "etl-service-principal-secret"
  string_value         = random_password.etl_databricks[0].result
  scope                = databricks_secret_scope.etl[0].name
}

resource "random_password" "etl_databricks" {
  count = local.is_databricks ? 1 : 0

  length  = 32
  special = false  # Databricks service principal secrets allow limited chars
}

# Optional: Small all-purpose cluster (auto-terminates to save cost)
# Comment out if client prefers job-only clusters
resource "databricks_cluster" "etl" {
  count = local.is_databricks ? 1 : 0

  cluster_name            = local.warehouse_name
  spark_version           = data.databricks_spark_version.latest[0].id
  node_type_id            = data.databricks_node_type.smallest[0].id
  driver_node_type_id     = data.databricks_node_type.smallest[0].id
  autotermination_minutes = 20
  num_workers             = 1

  spark_conf = {
    "spark.databricks.cluster.profile" = "singleNode"
    "spark.master"                     = "local[*]"
  }

  custom_tags = local.tags
}

# Data sources for latest Spark version and cheapest node type
data "databricks_spark_version" "latest" {
  count = local.is_databricks ? 1 : 0
}

data "databricks_node_type" "smallest" {
  count     = local.is_databricks ? 1 : 0
  local_disk = true
}

# Grants: Give service principal access to catalog/schema
resource "databricks_grants" "catalog" {
  count = local.is_databricks ? 1 : 0

  catalog = databricks_catalog.main[0].name

  grant {
    principal  = databricks_service_principal.etl[0].display_name
    privileges = ["USE CATALOG", "CREATE SCHEMA", "CREATE TABLE"]
  }
}

resource "databricks_grants" "schema" {
  count = local.is_databricks ? 1 : 0

  schema = "${databricks_catalog.main[0].name}.main"

  grant {
    principal  = databricks_service_principal.etl[0].display_name
    privileges = ["USE SCHEMA", "CREATE TABLE", "MODIFY"]
  }
}