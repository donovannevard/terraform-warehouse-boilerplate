output "vpc_id" {
  value = module.vpc.vpc_id
}

output "aws_s3_bucket" {
  value = {
    airflow = aws_s3_bucket.airflow
  }
}

output "redshift" {
  value = length(aws_redshift_cluster.main) > 0 ? {
    host     = aws_redshift_cluster.main[0].endpoint
    arn      = aws_redshift_cluster.main[0].arn
    port     = 5439
    database = aws_redshift_cluster.main[0].database_name
    username = var.admin_user_name
    password = random_password.admin.result
  } : null
  sensitive = true
}
