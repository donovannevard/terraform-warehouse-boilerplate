variable "warehouse_type" {
  description = "Which warehouse to deploy: snowflake or redshift"
  type        = string

  validation {
    condition     = contains(["snowflake", "redshift"], var.warehouse_type)
    error_message = "warehouse_type must be one of: snowflake or redshift"
  }
}
variable "use_airflow" {
  description = "Whether to provision Airflow"
  type        = bool
}
variable "admin_user_name" {
  description = "The name to use for the admin database user that is created"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
variable "aws_vpc_cidr" {
  description = "VPC CIDR for AWS"
  type        = string
}
variable "aws_private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}
variable "aws_prefix" {
  description = "AWS prefix for differentiating resources"
  type        = string
}

variable "redshift_node_type" {
  description = "Redshift node type (unused when warehouse_type != \"redshift\")"
  type        = string
  default     = "dc2.large"
}
variable "redshift_node_count" {
  description = "Number of nodes in the cluster (unused when warehouse_type != \"redshift\")"
  type        = number
  default     = 2
}
variable "redshift_inbound_cidr_restriction" {
  description = "Inbound CIDR restriction on the Redshift instance (unused when warehouse_type != \"redshift\")"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}
variable "public_subnet_ids" {
  description = "Public subnet IDs (for ALB)"
  type        = list(string)
}
