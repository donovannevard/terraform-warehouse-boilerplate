variable "warehouse_type" {
  description = "Which warehouse is being used (snowflake or redshift)"
  type        = string
}

variable "fivetran_group_id" {
  description = "Fivetran group ID (create via fivetran_group resource or UI)"
  type        = string
}
variable "fivetran_region" {
  description = "Fivetran region"
  type        = string
}
variable "fivetran_time_zone_offset" {
  description = "Fivetran timezone offset"
  type        = string
}

variable "account" {
  description = "Snowflake account identifier (e.g. xy12345.us-east-1.aws)"
  type        = string
  default     = null
}
variable "database" {
  description = "Database name to use in the query connection string"
  type        = string
}
variable "host" {
  description = "Host for the connection string"
  type        = string
  default     = null
}
variable "port" {
  description = "Port for the connection string"
  type        = number
  default     = null
}
variable "user" {
  description = "Username for the database user that will perform the extract queries"
  type        = string
}
variable "password" {
  description = "Password for the database user that will perform the extract queries"
  type        = string
}
variable "role" {
  description = "User role for interacting with the data warehouse"
  type        = string
  default     = null
}
