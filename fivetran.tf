# Fivetran resources – only created when use_fivetran = true

resource "fivetran_destination" "warehouse" {
  count = var.use_fivetran ? 1 : 0

  group_id = var.fivetran_group_id
  service  = local.is_snowflake ? "snowflake" : "databricks_delta_lake"

  time_zone_offset = "0"  # UTC; adjust as needed
  trust_certificates = true

  dynamic "config" {
    for_each = local.is_snowflake ? [1] : []
    content {
      host     = var.snowflake_account_identifier
      port     = 443
      database = snowflake_database.main[0].name
      auth     = "PASSWORD"
      user     = snowflake_user.etl[0].name
      password = random_password.etl[0].result
      role     = snowflake_role.etl[0].name
    }
  }

  dynamic "config" {
    for_each = local.is_databricks ? [1] : []
    content {
      # Databricks Delta Lake (Unity Catalog) config
      host            = var.databricks_workspace_url
      http_path       = "/sql/1.0/warehouses/${databricks_cluster.etl[0].id}"  # Use cluster if created; otherwise use serverless path
      catalog         = databricks_catalog.main[0].name
      auth_type       = "SERVICE_PRINCIPAL"
      client_id       = databricks_service_principal.etl[0].application_id
      client_secret   = random_password.etl_databricks[0].result
    }
  }
}

# Sample connector: Google Sheets (easy for quick testing)
# Skipped if sample_google_sheet_id is empty
resource "fivetran_connector" "sample" {
  count = var.use_fivetran && var.sample_google_sheet_id != "" ? 1 : 0

  group_id           = var.fivetran_group_id
  service            = "google_sheets"
  destination_schema {
    name = "google_sheets_sample"
  }

  config {
    sheet_id   = var.sample_google_sheet_id
    named_range = "A1:Z"  # Or specific range
  }

  depends_on = [fivetran_destination.warehouse]
}