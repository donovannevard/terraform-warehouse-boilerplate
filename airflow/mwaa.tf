# Managed Workflows for Apache Airflow (MWAA) — only created when use_airflow = true and airflow_type = "mwaa"
resource "aws_sagemaker_domain" "mwaa" {
  count = local.use_mwaa ? 1 : 0

  domain_name = "${local.project_name}-mwaa-domain"
  auth_mode   = "IAM"  # or SSO if you want

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  default_user_settings {
    execution_role = aws_iam_role.mwaa_execution[0].arn

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = var.environment == "development" ? "ml.t3.medium" : "ml.m5.large"
      }
    }
  }

  tags = local.tags
}

# MWAA Environment
resource "aws_mwaa_environment" "main" {
  count = local.use_mwaa ? 1 : 0

  name               = "${local.project_name}-airflow"
  execution_role_arn = aws_iam_role.mwaa_execution[0].arn

  dag_s3_path          = "dags/"  # Folder in S3 bucket for DAGs
  source_bucket_arn    = aws_s3_bucket.mwaa[0].arn
  airflow_configuration_options = {
    "airflow.core.dag_concurrency" = "32"
    "airflow.core.parallelism"     = "32"
    "airflow.core.max_active_runs_per_dag" = "5"
    "airflow.core.load_examples"   = "False"  # No example DAGs
  }

  environment_class = var.environment == "development" ? "mw1.small" : "mw1.medium"

  network_configuration {
    security_group_ids = [aws_security_group.mwaa[0].id]
    subnet_ids         = module.vpc.private_subnets
  }

  max_workers = var.environment == "development" ? 5 : 10

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.mwaa_execution_s3,
    aws_iam_role_policy_attachment.mwaa_execution_logs,
    aws_iam_role_policy_attachment.mwaa_execution_sagemaker
  ]
}

# S3 bucket for DAGs, requirements, plugins
resource "aws_s3_bucket" "mwaa" {
  count = local.use_mwaa ? 1 : 0

  bucket = "${local.project_name}-mwaa-${random_id.bucket.hex}"
}

resource "random_id" "bucket" {
  count = local.use_mwaa ? 1 : 0

  byte_length = 8
}

resource "aws_s3_bucket_versioning" "mwaa" {
  count  = local.use_mwaa ? 1 : 0
  bucket = aws_s3_bucket.mwaa[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mwaa" {
  count  = local.use_mwaa ? 1 : 0
  bucket = aws_s3_bucket.mwaa[0].bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload example DAGs (optional - client can upload their own)
resource "aws_s3_object" "example_dag" {
  count = local.use_mwaa ? 1 : 0

  bucket = aws_s3_bucket.mwaa[0].id
  key    = "dags/example_dag.py"
  source = "${path.module}/dags/example_dag.py"  # Optional: include a simple example

  etag = filemd5("${path.module}/dags/example_dag.py")
}

# IAM Role for MWAA Execution
resource "aws_iam_role" "mwaa_execution" {
  count = local.use_mwaa ? 1 : 0

  name = "${local.project_name}-mwaa-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "airflow.amazonaws.com",
            "airflow-env.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# MWAA Execution Policies
resource "aws_iam_role_policy_attachment" "mwaa_execution_s3" {
  count      = local.use_mwaa ? 1 : 0
  role       = aws_iam_role.mwaa_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"  # Tighten for prod
}

resource "aws_iam_role_policy_attachment" "mwaa_execution_logs" {
  count      = local.use_mwaa ? 1 : 0
  role       = aws_iam_role.mwaa_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonMWAAFullAccess"
}

resource "aws_iam_role_policy_attachment" "mwaa_execution_sagemaker" {
  count      = local.use_mwaa ? 1 : 0
  role       = aws_iam_role.mwaa_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"  # If using Sagemaker
}

# Additional policy for Redshift access (if use_redshift = true)
resource "aws_iam_role_policy" "mwaa_redshift" {
  count = local.use_mwaa && local.use_redshift ? 1 : 0

  name = "${local.project_name}-mwaa-redshift"
  role = aws_iam_role.mwaa_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "redshift-data:DescribeTable",
          "redshift-data:ExecuteStatement",
          "redshift-data:ListDatabases",
          "redshift-data:ListSchemas",
          "redshift-data:ListTables",
          "redshift-data:GetStatementResult"
        ]
        Resource = [
          aws_redshift_cluster.main[0].arn,
          "${aws_redshift_cluster.main[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = "redshift:GetClusterCredentials"
        Resource = aws_redshift_cluster.main[0].arn
      }
    ]
  })
}

# Security Group for MWAA
resource "aws_security_group" "mwaa" {
  count  = local.use_mwaa ? 1 : 0
  name   = "${local.project_name}-mwaa-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Airflow webserver access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR - adjust for your VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# Output
output "mwaa_webserver_url" {
  description = "MWAA webserver URL for DAG management"
  value       = local.use_mwaa ? aws_mwaa_environment.main[0].webserver_url : null
}