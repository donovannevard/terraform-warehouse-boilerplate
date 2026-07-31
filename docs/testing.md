# Testing guide

Everything in this repo has been verified with `terraform plan` against dummy
credentials (confirms the code is structurally correct — no more "invalid index"
or "unsupported attribute" errors) but **never with a real `terraform apply`**.
This guide walks through actually applying each combination once, checking it did
what it should, and tearing it down again. Budget roughly 15-20 minutes per
combination including teardown.

## Before you start

- **Use sandbox/trial accounts, not a real client's**, for this first pass:
  an AWS account you're happy to spin infrastructure up in, a Snowflake trial
  account, a Fivetran trial account. Nothing here is destructive to existing
  resources, but Redshift and MWAA both cost real money per hour while running.
- **Always run `terraform destroy` when you're done with a combination**
  before moving to the next one — Redshift clusters, MWAA environments, and
  NAT gateways are the expensive parts (NAT gateway alone runs ~$0.045/hr +
  data; a `dc2.large` Redshift node is ~$0.25/hr; MWAA `mw1.small` is ~$0.30/hr).
  Don't leave them running between sessions.
- **Never commit `terraform.tfvars` or `terraform.tfstate`** — both contain
  plaintext secrets once you apply for real. They're already gitignored.
- Work through `snowflake/` and `redshift/` as two entirely separate sessions —
  they don't share state or interact with each other.

## General flow for every combination

```bash
cd snowflake   # or redshift
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars for this combination — see checklist below
terraform init
terraform plan     # read it before applying — should match what you expect
terraform apply
# ... verify (see per-component checklists below) ...
terraform destroy  # tear down before moving to the next combination
```

If `terraform apply` ever fails partway through, re-run `terraform apply` again
before troubleshooting further — Terraform is safe to re-run and will pick up
where it left off.

---

## Combinations to run through

Suggested order: cheapest/fastest first, so you catch problems early without
burning time on expensive infra.

| # | Directory | `use_fivetran` | `use_airflow` | `airflow_type` | Notes |
|---|-----------|-----------------|-----------------|------------------|-------|
| 1 | `snowflake/` | `true` | `false` | — | The default/recommended combo — start here |
| 2 | `redshift/` | `true` | `false` | — | First combo that touches AWS |
| 3 | `snowflake/` | `true` | `true` | `mwaa` | |
| 4 | `redshift/` | `true` | `true` | `mwaa` | |
| 5 | `snowflake/` or `redshift/` | `true` | `true` | `ec2` | HTTP only (`airflow_ec2_enable_https = false`) — leave HTTPS for last |
| 6 | either | `false` | `false` | — | Confirms a bare warehouse-only deploy works with no ingestion tool |
| 7 | `redshift/` | `true` | `true` | `ec2` | `airflow_ec2_enable_https = true` — needs a real domain you control |

You don't strictly need all 7 — 1, 2, 3 (or 4), and 5 cover the combinations
most likely to be used with a real client. 6 and 7 are lower priority.

---

## Per-component verification

### Snowflake (combos 1, 3, 5, 6)
```bash
terraform output -json snowflake
```
Log into Snowflake as `ACCOUNTADMIN` (or your Terraform user) and confirm:
- [ ] Databases `EXTRACT`, `TRANSFORM`, `ANALYSIS` exist, each with the schema name you configured (default `extract`/`transform`/`analysis`)
- [ ] Warehouses `EXTRACT_WH` (X-SMALL), `TRANSFORM_WH` (MEDIUM), `ANALYSIS_WH` (X-SMALL), all `auto_suspend = 60`
- [ ] Roles `ADMIN_ROLE`, `EXTRACT_ROLE`, `TRANSFORM_ROLE`, `LOAD_ROLE`, `ANALYST_ROLE` exist
- [ ] Users `EXTRACT`, `TRANSFORM`, `LOAD` exist, each with `must_change_password = false`
- [ ] Log in as the `EXTRACT` user (credentials from the output above) and confirm it can create/write tables in `EXTRACT.extract` but gets a permission error touching `TRANSFORM` or `ANALYSIS`

### Redshift (combos 2, 4, 5, 7)
```bash
terraform output -json redshift
```
Connect with `psql` (or any SQL client) using the admin credentials from the
output — remember the cluster is private, so you'll need to be on a VPN/bastion
inside the VPC, or temporarily widen `redshift_inbound_cidr_restriction` to
your current IP for this test and narrow it again afterward.
- [ ] Database name is lowercase (e.g. `acme-co_database`) — this was a real bug, worth double-checking it actually applied
- [ ] Schemas `extract`, `transform`, `analysis` exist
- [ ] `SELECT groname, grolist FROM pg_group;` shows `extract_group`, `transform_group`, `load_group`, `admin_group`, `analyst_group`, each with the right user already a member (no manual `psql`/`ALTER GROUP` step needed — this replaced the old provisioner)
- [ ] Log in as the `EXTRACT` user and confirm it can write to the `extract` schema but not `transform`/`analysis`

### Fivetran (combos 1-5, 7)
```bash
terraform output fivetran_destination_id
```
- [ ] The destination appears in the Fivetran dashboard under your group, with the correct warehouse type (Snowflake or Redshift) and region
- [ ] It's configured with the `EXTRACT` service user, not an admin/master user — check the connection config in the Fivetran UI
- [ ] Try adding a real source connector against it and confirm the destination test/connection succeeds

### MWAA Airflow (combos 3, 4)
```bash
terraform output airflow_mwaa_webserver_url
```
- [ ] MWAA environment shows `AVAILABLE` in the AWS console (this can take 20-30 minutes to spin up — the slowest part of any MWAA test)
- [ ] `aws mwaa create-web-login-token --name <env-name>` (or just the console's "Open Airflow UI" button) gets you into the webserver
- [ ] Drop a test DAG file into the S3 bucket's `dags/` prefix and confirm it shows up in the Airflow UI within a few minutes
- [ ] If testing with Redshift: confirm the MWAA execution role's IAM policy includes `redshift-data:ExecuteStatement` (check the role in the IAM console) — this was previously dead code that never actually attached

### EC2 Airflow (combo 5, 7)
```bash
terraform output airflow_ec2_url
terraform output airflow_ec2_admin_username
terraform output airflow_ec2_admin_password
```
- [ ] The URL loads the Airflow login screen within a few minutes of apply completing (cloud-init takes a little while)
- [ ] The admin credentials above actually log you in — this exercises a real fix: the original script created the admin user but never started the Airflow containers, so this combination could not have worked before
- [ ] Drop a test DAG into the S3 bucket's `dags/` prefix and confirm it appears in the UI within 5 minutes (the instance polls on a cron)
- [ ] For combo 7 (HTTPS): confirm the ACM certificate shows `ISSUED` in the AWS console, and the URL loads over `https://` with a valid cert
- [ ] For combo 7 without a Route53 zone ID: confirm `terraform output airflow_ec2_acm_validation_record` gives you a real DNS record, add it with your DNS provider, wait for validation, then re-apply and confirm the listener comes up

---

## Troubleshooting

**Redshift-related "provider configuration" error on the very first apply of a
brand-new AWS account:** this hasn't been observed in testing, but if it ever
happens, run `terraform apply -target=module.aws` once to create the cluster,
then a plain `terraform apply` to finish the rest. See `redshift/providers.tf`
for why this is a defensive fallback rather than an expected step.

**Snowflake auth errors:** double check `snowflake_account_identifier` — it's
easy to paste the URL-style identifier (`abc12345.us-east-1`) instead of the
account-locator style (`ABC12345`) the provider expects, or vice versa depending
on your Snowflake edition.

**Redshift connection refused when verifying with `psql`:** the cluster is
`publicly_accessible = false` by design — you need to be inside the VPC (or
temporarily widen `redshift_inbound_cidr_restriction` to your IP, then narrow
it back).

Once you've been through this, note anything that didn't match this doc so it
can be corrected — this guide describes expected behavior based on `plan`-level
verification, not a live `apply` yet.
