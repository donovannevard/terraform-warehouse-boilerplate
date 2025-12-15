variable "environment" {
  description = "Deployment environment: 'production' or 'development' (uses tiny/free-tier resources for development/PoC)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "development"], lower(var.environment))
    error_message = "environment must be 'production' or 'development'"
  }
}

variable "project_name" {
  description = "Short project/client name used for resource naming and tagging"
  type        = string
  default     = "data-platform"
}

variable "warehouse_type" {
  description = "Choose the data warehouse: 'snowflake', 'databricks', or 'redshift'"
  type        = string
  default     = "snowflake"

  validation {
    condition     = contains(["snowflake", "databricks", "redshift"], lower(var.warehouse_type))
    error_message = "warehouse_type must be one of: snowflake, databricks, redshift"
  }
}

variable "use_airflow" {
  description = "Set to true to provision Apache Airflow for orchestration (alternative/complement to Fivetran)"
  type        = bool
  default     = false
}

variable "airflow_type" {
  description = "When use_airflow = true, choose 'mwaa' (Managed Workflows) or 'ec2' (self-managed on EC2)"
  type        = string
  default     = "mwaa"

  validation {
    condition     = var.use_airflow ? contains(["mwaa", "ec2"], lower(var.airflow_type)) : true
    error_message = "airflow_type must be 'mwaa' or 'ec2' when use_airflow = true"
  }
}

variable "use_fivetran" {
  description = "Set to false if client wants to use only Airflow (or existing ingestion) instead of Fivetran"
  type        = bool
  default     = true
}

# ====================
# Snowflake variables
# ====================
variable "snowflake_account_identifier" {
  description = "Snowflake account identifier (e.g., xy12345.us-east-1)"
  type        = string
  default     = null
}

variable "snowflake_username" {
  description = "Snowflake admin username"
  type        = string
  default     = null
}

variable "snowflake_password" {
  description = "Snowflake admin password"
  type        = string
  sensitive   = true
  default     = null
}

variable "snowflake_role" {
  description = "Snowflake role to use"
  type        = string
  default     = "ACCOUNTADMIN"
}

# ====================
# Databricks variables
# ====================
variable "databricks_workspace_url" {
  description = "Databricks workspace URL"
  type        = string
  default     = null
}

variable "databricks_token" {
  description = "Databricks personal access token"
  type        = string
  sensitive   = true
  default     = null
}

# ====================
# Redshift variables
# ====================
variable "redshift_node_type" {
  description = "Redshift node type (e.g., ra3.4xlarge)"
  type        = string
  default     = "ra3.4xlarge"
}

variable "redshift_number_of_nodes" {
  description = "Number of compute nodes"
  type        = number
  default     = 2
}

variable "redshift_database_name" {
  description = "Default database name"
  type        = string
  default     = "analytics"
}

# ====================
# Airflow variables (required if use_airflow = true)
# ====================
variable "airflow_admin_password" {
  description = "Airflow webserver admin password (for both MWAA and EC2)"
  type        = string
  sensitive   = true
  default     = null
}

# Optional: for EC2 Airflow (instance type, etc.)
variable "airflow_ec2_instance_type" {
  description = "EC2 instance type for production self-managed Airflow"
  type        = string
  default     = "m6i.xlarge"  # Good default for production
}

# ====================
# Fivetran variables
# ====================
variable "fivetran_api_key" {
  description = "Fivetran API key"
  type        = string
  sensitive   = true
}

variable "fivetran_api_secret" {
  description = "Fivetran API secret"
  type        = string
  sensitive   = true
}

variable "fivetran_group_id" {
  description = "Fivetran group ID"
  type        = string
}

variable "sample_google_sheet_id" {
  description = "Google Sheet ID for sample connector (optional)"
  type        = string
  default     = ""
}