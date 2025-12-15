#!/bin/bash
set -e

yum update -y
amazon-linux-extras install docker -y
service docker start
usermod -a -G docker ec2-user

curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

mkdir -p /opt/airflow
cd /opt/airflow

cat > docker-compose.yml <<EOF
version: '3.8'
services:
  airflow:
    image: apache/airflow:2.9.3
    restart: always
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__WEBSERVER__SECRET_KEY: supersecretchangeinprod
      AIRFLOW__WEBSERVER__WEB_SERVER_PORT: 8080
    ports:
      - "8080:8080"
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
    command: standalone
EOF

docker-compose up -d