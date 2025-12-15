# Resources only created when use_databricks = false

resource "snowflake_warehouse" "main" {
  count = local.is_snowflake ? 1 : 0

  name           = local.warehouse_name
  warehouse_size = "X-SMALL"      # ~$2/hour when running; scale up later
  auto_suspend   = 60             # Seconds – suspends quickly to save credits
  auto_resume    = true
  initially_suspended = true

  comment = "Main warehouse for ${local.project_name}"
  tags    = local.tags
}

resource "snowflake_database" "main" {
  count = local.is_snowflake ? 1 : 0

  name    = local.database_name
  comment = "Main database for ${local.project_name}"
}

resource "snowflake_schema" "main" {
  count = local.is_snowflake ? 1 : 0

  name     = "PUBLIC"
  database = snowflake_database.main[0].name
  comment  = "Default public schema"
}

# ETL role for tools like Fivetran or Airflow
resource "snowflake_role" "etl" {
  count = local.is_snowflake ? 1 : 0

  name    = local.etl_role_name
  comment = "Role for ETL ingestion and transformations"
}

resource "snowflake_user" "etl" {
  count = local.is_snowflake ? 1 : 0

  name         = local.etl_user_name
  password     = random_password.etl[0].result  # We'll add random_password next
  default_role = snowflake_role.etl[0].name
  default_warehouse = snowflake_warehouse.main[0].name
  comment      = "ETL service user for ${local.project_name}"
}

# Random password for the ETL user (secure + generated on apply)
resource "random_password" "etl" {
  count = local.is_snowflake ? 1 : 0

  length  = 20
  special = true
  override_special = "!@#$%&*()-_=+[]{}<>:?"
}

# Grants – give ETL role the necessary privileges
resource "snowflake_warehouse_grant" "etl_warehouse" {
  count = local.is_snowflake ? 1 : 0

  warehouse_name = snowflake_warehouse.main[0].name
  privilege      = "USAGE"
  roles          = [snowflake_role.etl[0].name]
}

resource "snowflake_database_grant" "etl_db" {
  count = local.is_snowflake ? 1 : 0

  database_name = snowflake_database.main[0].name
  privilege     = "USAGE"
  roles         = [snowflake_role.etl[0].name]
}

resource "snowflake_schema_grant" "etl_schema" {
  count = local.is_snowflake ? 1 : 0

  database_name = snowflake_database.main[0].name
  schema_name   = snowflake_schema.main[0].name
  privilege     = "CREATE TABLE"
  roles         = [snowflake_role.etl[0].name]

  # Add more privileges as needed (INSERT, SELECT, etc.)
}

# Additional common grants for loading data
resource "snowflake_schema_grant" "etl_schema_modify" {
  count = local.is_snowflake ? 1 : 0

  database_name = snowflake_database.main[0].name
  schema_name   = snowflake_schema.main[0].name
  privilege     = "MODIFY"
  roles         = [snowflake_role.etl[0].name]
}

# Assign the role to the user
resource "snowflake_role_grants" "etl_to_user" {
  count = local.is_snowflake ? 1 : 0

  role_name = snowflake_role.etl[0].name
  users     = [snowflake_user.etl[0].name]
}