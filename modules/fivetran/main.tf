terraform {
  required_providers {
    fivetran = {
      source  = "fivetran/fivetran"
      version = "~> 1.9.17"
    }
  }
}

resource "fivetran_destination" "main" {
  group_id         = var.fivetran_group_id
  service          = var.warehouse_type
  region           = var.fivetran_region
  time_zone_offset = var.fivetran_time_zone_offset
}

resource "fivetran_connector" "snowflake_connector" {
  count = var.warehouse_type == "snowflake" ? 1 : 0

  group_id = fivetran_destination.main.id
  service  = "snowflake"
  config {
    account  = var.account
    user     = var.user
    password = var.password
    database = var.database
    role     = var.role
  }
}

resource "fivetran_connector" "redshift_connector" {
  count = var.warehouse_type == "redshift" ? 1 : 0

  group_id = fivetran_destination.main.id
  service  = "redshift"
  config {
    host     = var.host
    port     = var.port
    user     = var.user
    password = var.password
    database = var.database
  }
}
