# outputs.tf

output "selected_warehouse" {
  description = "The warehouse type that was provisioned"
  value       = var.warehouse_type
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

# Snowflake outputs
output "snowflake_account_identifier" {
  description = "Snowflake account identifier"
  value       = local.use_snowflake ? var.snowflake_account_identifier : null
}

output "snowflake_database" {
  description = "Snowflake default database"
  value       = local.use_snowflake ? var.snowflake_database_name : null
}

output "snowflake_etl_user" {
  description = "Snowflake ETL user for Fivetran/Airflow"
  value       = local.use_snowflake ? snowflake_user.etl[0].name : null
}

output "snowflake_etl_password" {
  description = "Auto-generated password for Snowflake ETL user (save this!)"
  value       = local.use_snowflake ? random_password.snowflake[0].result : null
  sensitive   = true
}

# Databricks outputs
output "databricks_workspace_url" {
  description = "Databricks workspace URL"
  value       = local.use_databricks ? var.databricks_workspace_url : null
}

output "databricks_catalog" {
  description = "Databricks Unity Catalog name"
  value       = local.use_databricks ? databricks_catalog.main[0].name : null
}

# Redshift outputs
output "redshift_endpoint" {
  description = "Redshift cluster endpoint"
  value       = local.use_redshift ? aws_redshift_cluster.main[0].endpoint : null
}

output "redshift_database" {
  description = "Redshift default database"
  value       = local.use_redshift ? var.redshift_database_name : null
}

output "redshift_etl_user_password" {
  description = "Auto-generated password for Redshift ETL user"
  value       = local.use_redshift ? random_password.redshift[0].result : null
  sensitive   = true
}

# Fivetran outputs
output "fivetran_destination_id" {
  description = "Fivetran destination ID (if Fivetran enabled)"
  value       = var.use_fivetran ? fivetran_destination.warehouse[0].id : "Fivetran not enabled"
}

# Airflow outputs
output "airflow_type" {
  description = "Airflow deployment type"
  value       = var.use_airflow ? var.airflow_type : "Airflow not enabled"
}

output "mwaa_webserver_url" {
  description = "MWAA webserver URL"
  value       = local.use_mwaa ? aws_mwaa_environment.main[0].webserver_url : null
}

output "ec2_airflow_web_url" {
  description = "EC2 Airflow web UI URL (via ALB)"
  value       = local.use_ec2_airflow ? "https://${aws_lb.airflow[0].dns_name}" : null
}

output "ec2_airflow_ssm_command" {
  description = "SSM command to access EC2 Airflow instance"
  value       = local.use_ec2_airflow ? "aws ssm start-session --target ${aws_instance.airflow[0].id}" : null
}

# General instructions
output "next_steps" {
  description = "What to do after apply"
  value = <<EOT
1. Save any sensitive outputs (passwords) in a secure location.
2. If using Fivetran: add connectors in the Fivetran UI using destination ID.
3. If using Airflow: create a separate git repo for DAGs and sync to:
   - MWAA: S3 bucket ${local.use_mwaa ? aws_s3_bucket.mwaa[0].bucket : "N/A"}
   - EC2: SCP/rsync to instance (use SSM command above)
4. Connect BI tools (Sigma, Looker, Tableau, Power BI) to the warehouse.
EOT
}