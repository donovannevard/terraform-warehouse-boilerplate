terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.79"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# IAM Role + minimal policies
resource "aws_iam_role" "mwaa_execution" {
  name = "${var.aws_prefix}-mwaa-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "airflow.amazonaws.com"
      }
    }]
  })
}
resource "aws_iam_role_policy" "mwaa_s3" {
  name = "${var.aws_prefix}-mwaa-s3"
  role = aws_iam_role.mwaa_execution.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
      Resource = [var.aws_s3_bucket_arn, "${var.aws_s3_bucket_arn}/*"]
    }]
  })
}
resource "aws_iam_role_policy" "mwaa_logs" {
  name = "${var.aws_prefix}-mwaa-logs"
  role = aws_iam_role.mwaa_execution.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "*"
    }]
  })
}
resource "aws_iam_role_policy" "mwaa_redshift" {
  count = var.warehouse_type == "redshift" ? 1 : 0
  name  = "${var.aws_prefix}-mwaa-redshift"
  role  = aws_iam_role.mwaa_execution.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["redshift-data:ExecuteStatement", "redshift-data:GetStatementResult"]
      Resource = var.redshift_cluster_arn
    }]
  })
}
resource "aws_iam_policy" "mwaa_ui_access" {
  name = "${var.aws_prefix}-mwaa-ui-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "airflow:CreateWebLoginToken",
          "airflow:GetEnvironment"
        ]
        Resource = aws_mwaa_environment.main.arn
      }
    ]
  })
}

# Security Group
resource "aws_security_group" "mwaa" {
  name   = "${var.aws_prefix}-mwaa-sg"
  vpc_id = var.aws_vpc_id

  ingress {
    description = "Airflow UI (VPC only)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# MWAA Environment
resource "aws_mwaa_environment" "main" {
  name               = "${var.aws_prefix}-airflow"
  execution_role_arn = aws_iam_role.mwaa_execution.arn

  dag_s3_path       = "dags"
  source_bucket_arn = var.aws_s3_bucket_arn

  airflow_configuration_options = {
    "core.dag_concurrency"         = var.mwaa_dag_concurrency
    "core.parallelism"             = var.mwaa_parallelism
    "core.max_active_runs_per_dag" = var.mwaa_max_runs_per_dag
    "core.load_examples"           = "false"
  }

  environment_class = var.mwaa_environment
  max_workers       = var.mwaa_max_workers

  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = var.private_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy.mwaa_s3,
    aws_iam_role_policy.mwaa_logs
  ]
}
