# Warehouses/redshift.tf
# Resources only created when use_redshift = true

locals {
  is_redshift = var.use_redshift
}

resource "aws_redshift_cluster" "main" {
  count = local.is_redshift ? 1 : 0

  cluster_identifier  = "${local.project_name}-redshift"
  database_name       = var.redshift_database_name
  master_username     = "etl_user"
  master_password     = random_password.redshift[0].result
  node_type           = var.redshift_node_type
  cluster_type        = "multi-node"
  number_of_nodes     = var.redshift_number_of_nodes

  publicly_accessible = false
  encrypted           = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${local.project_name}-redshift-final"

  vpc_security_group_ids = [aws_security_group.redshift[0].id]
  cluster_subnet_group_name = module.vpc.redshift_subnet_group_name

  automated_snapshot_retention_period = 7
  tags = local.tags
}

resource "random_password" "redshift" {
  count = local.is_redshift ? 1 : 0

  length  = 20
  special = true
  override_special = "!@#$%&*()-_=+[]{}<>:?"
}

# ETL role & user for Fivetran/Airflow
resource "aws_redshift_user" "etl" {
  count = local.is_redshift ? 1 : 0

  name     = "${local.project_name}_etl_user"
  password = random_password.redshift[0].result
}

# Basic grants for ETL user
resource "aws_redshift_grant" "etl_usage" {
  count = local.is_redshift ? 1 : 0

  user_name     = aws_redshift_user.etl[0].name
  object_type   = "database"
  object_name   = var.redshift_database_name
  privilege     = "USAGE"
}

# Security group for Redshift
resource "aws_security_group" "redshift" {
  count = local.is_redshift ? 1 : 0

  name        = "${local.project_name}-redshift-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow Fivetran/Airflow to Redshift"
    from_port       = 5439
    to_port         = 5439
    protocol        = "tcp"
    security_groups = [aws_security_group.fivetran[0].id]  # or your Airflow/EC2 SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}