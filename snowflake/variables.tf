# Core choices
variable "use_fivetran" {
  description = "Whether to provision a Fivetran destination + connector"
  type        = bool
  default     = true
}
variable "use_airflow" {
  description = "Whether to provision Airflow"
  type        = bool
  default     = false
}
variable "airflow_type" {
  description = "Which Airflow deployment to use when use_airflow = true"
  type        = string
  default     = "mwaa"

  validation {
    condition     = contains(["mwaa", "ec2"], var.airflow_type)
    error_message = "airflow_type must be mwaa or ec2"
  }
}

# Database
variable "db_admin_user_name" {
  description = "The name to use for the admin database user that is created"
  type        = string
  default     = "etladmin"
}
variable "db_extract_schema" {
  description = "The schema name to use for the extract layer"
  type        = string
  default     = "extract"
}
variable "db_transform_schema" {
  description = "The schema name to use for the transform layer"
  type        = string
  default     = "transform"
}
variable "db_analysis_schema" {
  description = "The schema name to use for the analysis layer"
  type        = string
  default     = "analysis"
}

# Snowflake (required)
variable "snowflake_account_identifier" {
  description = "Snowflake account identifier (e.g. ABCDEF-UV12345)"
  type        = string
  sensitive   = true
}
variable "snowflake_username" {
  description = "Snowflake username for Terraform"
  type        = string
  sensitive   = true
}
variable "snowflake_password" {
  description = "Snowflake password for Terraform"
  type        = string
  sensitive   = true
}
variable "snowflake_role" {
  description = "Snowflake role to use"
  type        = string
  default     = "ACCOUNTADMIN"
}
variable "snowflake_extract_wh_size" {
  description = "Snowflake extract warehouse instance size"
  type        = string
  default     = "X-SMALL"
}
variable "snowflake_transform_wh_size" {
  description = "Snowflake transform warehouse instance size"
  type        = string
  default     = "MEDIUM"
}
variable "snowflake_analysis_wh_size" {
  description = "Snowflake analysis warehouse instance size"
  type        = string
  default     = "X-SMALL"
}

# Fivetran (required when use_fivetran = true)
variable "fivetran_api_key" {
  description = "Fivetran API key"
  type        = string
  sensitive   = true
  default     = null
}
variable "fivetran_api_secret" {
  description = "Fivetran API secret"
  type        = string
  sensitive   = true
  default     = null
}
variable "fivetran_group_id" {
  description = "Fivetran group ID"
  type        = string
  default     = null
}
variable "fivetran_region" {
  description = "Fivetran region (e.g. AWS_EU_WEST_1)"
  type        = string
  default     = null
}
variable "fivetran_time_zone_offset" {
  description = "Fivetran timezone offset"
  type        = string
  default     = "0"
}

# AWS (only required when use_airflow = true)
variable "aws_prefix" {
  description = "AWS prefix for differentiating resources"
  type        = string
  default     = "etl"
}
variable "aws_region" {
  description = "AWS region (only used when use_airflow = true)"
  type        = string
  default     = "us-east-1"
}
variable "aws_vpc_cidr" {
  description = "VPC CIDR for AWS"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.aws_vpc_cidr, 0))
    error_message = "aws_vpc_cidr must be a valid CIDR block."
  }
}
variable "private_subnet_ids" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "public_subnet_ids" {
  description = "Public subnet CIDRs (for ALB)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# Airflow/EC2-specific
variable "airflow_ec2_domain" {
  description = "Domain to assign to the Airflow webserver (required if airflow_ec2_enable_https = true)"
  type        = string
  default     = null
}
variable "airflow_ec2_admin_email" {
  description = "The email to use for the admin user for the EC2 Airflow instance"
  type        = string
  default     = null
}
variable "airflow_ec2_enable_https" {
  description = "Serve EC2 Airflow over HTTPS with an ACM certificate. Default false: plain HTTP behind the ALB, restricted to ec2_inbound_cidr_restriction — fastest path, no DNS wait."
  type        = bool
  default     = false
}
variable "airflow_ec2_route53_zone_id" {
  description = "Route53 hosted zone ID for airflow_ec2_domain. If set alongside airflow_ec2_enable_https, ACM DNS validation is fully automatic."
  type        = string
  default     = null
}
variable "ec2_inbound_cidr_restriction" {
  description = "CIDR allowed to reach the Airflow webserver (e.g. your office/VPN range). No default — pick a deliberate value, do not leave this open to 0.0.0.0/0."
  type        = string
  default     = null

  validation {
    condition     = !(var.use_airflow && var.airflow_type == "ec2") || (var.ec2_inbound_cidr_restriction != null && can(cidrhost(var.ec2_inbound_cidr_restriction, 0)))
    error_message = "ec2_inbound_cidr_restriction must be a valid CIDR block when use_airflow = true and airflow_type = \"ec2\"."
  }
}
variable "ec2_instance_type" {
  description = "Instance size for the EC2 instance running Airflow"
  type        = string
  default     = "t3.small"
}

# Airflow/MWAA-specific
variable "airflow_mwaa_environment" {
  description = "Instance size for the MWAA instance running Airflow"
  type        = string
  default     = "mw1.small"
}
