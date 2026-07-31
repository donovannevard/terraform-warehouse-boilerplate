#!/bin/bash
set -e

# Update instance and install docker
yum update -y
amazon-linux-extras install docker -y
yum install -y docker-compose-plugin
service docker start
usermod -a -G docker ec2-user
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Declare working variables
DAG_DIR="/opt/airflow/dags"
BUCKET="${dag_bucket}"
mkdir -p $DAG_DIR

# Initial sync
aws s3 sync s3://$BUCKET/dags $DAG_DIR

# Install cron job to keep updated
cat <<EOF > /etc/cron.d/airflow-dag-sync
*/5 * * * * root /usr/bin/aws s3 sync s3://$BUCKET/dags $DAG_DIR --region ${aws_region}
EOF

# Declare the docker compose file
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  postgres:
    image: postgres:13-alpine
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: ${admin_password}
      POSTGRES_DB: airflow
    volumes:
      - postgres_db:/var/lib/postgresql/data
    restart: always

  webserver:
    image: apache/airflow:2.9.3-python3.8
    command: webserver
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:${admin_password}@postgres/airflow
      AIRFLOW__CORE__FERNET_KEY: ""
      AIRFLOW__CORE__DAG_DIR_LIST_INTERVAL: 30
      AIRFLOW__CORE__LOAD_EXAMPLES: "false"
      AIRFLOW__WEBSERVER__EXPOSE_CONFIG: "true"
    volumes:
      - /opt/airflow/dags:/opt/airflow/dags
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    restart: always

  scheduler:
    image: apache/airflow:2.9.3-python3.8
    command: scheduler
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:${admin_password}@postgres/airflow
    volumes:
      - /opt/airflow/dags:/opt/airflow/dags
    depends_on:
      - postgres
    restart: always

volumes:
  postgres_db:
EOF

# Start containers
docker compose run --rm webserver airflow db init
docker compose run --rm webserver airflow users create \
  --email ${admin_email} \
  --username admin \
  --password ${admin_password} \
  --firstname admin \
  --lastname admin \
  --role Admin
docker compose up -d
echo "Airflow started! Web UI available via the ALB."
