locals {
  project_name = lower(replace(var.project_name, " ", "-"))

  warehouse_type = lower(var.warehouse_type)
  use_snowflake  = local.warehouse_type == "snowflake"
  use_databricks = local.warehouse_type == "databricks"
  use_redshift   = local.warehouse_type == "redshift"

  airflow_type   = var.use_airflow ? lower(var.airflow_type) : null
  use_mwaa       = var.use_airflow && local.airflow_type == "mwaa"
  use_ec2_airflow = var.use_airflow && local.airflow_type == "ec2"

  # Airflow EC2 instance type
  airflow_ec2_instance_type = var.environment == "development" ? "t3.micro" : var.airflow_ec2_instance_type

  # Redshift node type (only if use_redshift)
  redshift_node_type = var.environment == "development" ? "dc2.large" : var.redshift_node_type  # dc2.large is cheapest
  redshift_number_of_nodes = var.environment == "development" ? 1 : var.redshift_number_of_nodes

  tags = {
    Environment = "production"
    Project     = local.project_name
    ManagedBy   = "terraform"
  }
}