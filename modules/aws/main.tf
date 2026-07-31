terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.79"
    }
    redshift = {
      source  = "brainly/redshift"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

locals {
  # Redshift requires lowercase alphanumeric + underscores/dollar signs only.
  database_name = "${lower(var.aws_prefix)}_database"
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.9"

  name = "${var.aws_prefix}-vpc"
  cidr = var.aws_vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = var.private_subnet_ids
  public_subnets  = var.public_subnet_ids

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Redshift cluster
resource "random_password" "admin" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()_+-="
}
resource "aws_redshift_subnet_group" "main" {
  count       = var.warehouse_type == "redshift" ? 1 : 0
  name        = "${var.aws_prefix}-redshift-subnet-group"
  description = "Subnet group for Redshift cluster"
  subnet_ids  = var.aws_private_subnet_ids
}
resource "aws_redshift_cluster" "main" {
  count              = var.warehouse_type == "redshift" ? 1 : 0
  cluster_identifier = "${var.aws_prefix}-redshift"
  database_name      = local.database_name
  master_username    = var.admin_user_name
  master_password    = random_password.admin.result

  node_type       = var.redshift_node_type
  cluster_type    = "multi-node"
  number_of_nodes = var.redshift_node_count

  publicly_accessible       = false
  encrypted                 = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.aws_prefix}-redshift-final"

  vpc_security_group_ids    = [aws_security_group.redshift[0].id]
  cluster_subnet_group_name = aws_redshift_subnet_group.main[0].name

  automated_snapshot_retention_period = 7
}
resource "aws_security_group" "redshift" {
  count       = var.warehouse_type == "redshift" ? 1 : 0
  name        = "${var.aws_prefix}-redshift-sg"
  description = "Security group for Redshift cluster"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow inbound from Fivetran / Airflow / dbt"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.redshift_inbound_cidr_restriction]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# S3 bucket for DAGs
resource "random_id" "bucket" {
  byte_length = 8
}
resource "aws_s3_bucket" "airflow" {
  count  = var.use_airflow == true ? 1 : 0
  bucket = "${var.aws_prefix}-airflow-dags-${random_id.bucket.hex}"
}
resource "aws_s3_bucket_versioning" "airflow" {
  count  = var.use_airflow == true ? 1 : 0
  bucket = aws_s3_bucket.airflow[0].id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "airflow" {
  count  = var.use_airflow == true ? 1 : 0
  bucket = aws_s3_bucket.airflow[0].bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
