# Terraform Boilerplate: Modern Data Warehouse + Optional Ingestion (Fivetran or Airflow)

Quickly provisions a production-ready data warehouse with flexible ingestion options.

## Features

- **Warehouse choice** via single variable: `snowflake` (default), `databricks`, or `redshift`
- **Ingestion options**:
  - Fivetran (default) – fully configured destination + sample connector
  - Apache Airflow – toggleable, with choice of:
    - **MWAA** (AWS-managed, zero ops, auto-scaling workers)
    - **Self-managed on EC2** (single-node Docker Compose, full control, ALB + HTTPS, SSM access)
- **Development mode** – tiny/free-tier resources for testing/PoC (`environment = "development"`)
- Secure setup: ETL users/roles, encrypted storage, private subnets, IAM least-privilege
- Minimal ongoing cost: auto-suspend warehouses, auto-terminate clusters, $0 when idle where possible

## Prerequisites

- Terraform >= 1.6.0
- AWS account (required for all options)
- Snowflake account (if `warehouse_type = "snowflake"`)
- Databricks workspace + token (if `warehouse_type = "databricks"`)
- Fivetran account + API key/secret/group (if `use_fivetran = true`)

## Quick Start

1. **Clone the repo**

   ```Bash
   git clone https://github.com/donovannevard/terraform-warehouse-boilerplate.git
   cd terraform-warehouse-boilerplate
   ```

2. **Copy example vars**

   ```Bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars**

   Choose your warehouse and ingestion:
   ```hcl
   environment    = "development"   # or "production"

   warehouse_type = "snowflake"     # "snowflake", "databricks", or "redshift"

   use_fivetran   = true            # false if using only Airflow
   use_airflow    = false           # true to provision Airflow
   airflow_type   = "mwaa"          # "mwaa" or "ec2" (only if use_airflow = true)
   ```

4. **Configure remote backend (in `backend.tf`)**

   Uncomment your preferred option (S3 recommended for AWS clients).

5. **Apply**

   ```Bash
   terraform init
   terraform plan
   terraform apply
   ```

## Outputs (check after apply)

- Selected warehouse type & environment
- Warehouse connection details (endpoint, database/catalog, ETL credentials)
- Fivetran destination ID (if enabled)
- Airflow web UI URL (MWAA or EC2 ALB) and SSM access command (EC2 only)
- Next steps guide

## Customisation

- **Add/remove sources**: All staging folders are independent – delete unused ones freely.
- **Airflow DAGs**: Create a separate git repo for DAGs and sync to:
   - MWAA: S3 bucket (output provided) 
   - EC2: SCP/rsync or git pull on instanc   e
- **Switch to production**: Change `environment = "production"` and re-apply.

## Cost Notes (approximate)
- Snowflake
   - Development: X-SMALL warehouse (~$2/hr when running)
   - Production: Larger warehouse + concurrency scaling
- Databricks
   - Devlopment: Small all-purpose cluster
   - Production: Medium/large + job clusters
- Redshift
   - Devlopment: dc2.large x1 (~$0.25/hr)
   - Production: ra3.4xlarge x2+
- MWAA
   - mw1.small (~$0.50/hr)
   - mw1.medium/large
- EC2 Airflow
   - t3.micro (free-tier eligible)
   - t3.micro (free-tier eligible)
- Fivetran
   - Free tier for low volume
   - Paid connectors as needed

## Built for speed by a contractor who hates slow setups. 🚀