output "mwaa_webserver_url" {
  description = "MWAA webserver URL"
  value       = aws_mwaa_environment.main.webserver_url
}

output "airflow_type" {
  description = "Airflow deployment type"
  value       = "mwaa"
}
