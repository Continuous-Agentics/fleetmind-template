# Multi-Fleet Deployments

fleetmind supports running multiple independent fleets in a single AWS account via Terraform workspaces. The Terraform itself lives in the separate [`terraform-aws-fleetmind`](https://github.com/Continuous-Agentics/terraform-aws-fleetmind) module repo; operators consume it via the [`fleetmind-template`](https://github.com/Continuous-Agentics/fleetmind-template) starter.

**Idiomatic layout:** one clone of fleetmind-template with multiple `workspaces/<fleet>.tfvars` files — one per fleet. The template's backend `key` is intentionally omitted so Terraform workspaces auto-prefix state under `env:/<workspace>/`, which keeps each fleet's state isolated without a separate repo. Per-fleet clones also work if you need different `main.tf` overrides per fleet, but they're the exception.

Each Terraform workspace has its own state file, VPC, EC2 instances, IAM roles, S3 ledger bucket, DDB tasks table, and Secrets Manager namespace. Resource names are auto-prefixed by `var.fleet_name`, so a fleet named `fleet-a` and a fleet named `fleet-b` co-exist cleanly.

## One-time per AWS account: backend setup

### 1. Pick an S3 bucket for remote state

Use an existing account-level bucket or create a dedicated one:

```bash
aws s3api create-bucket \
  --bucket <YOUR-TFSTATE-BUCKET> \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

aws s3api put-bucket-versioning \
  --bucket <YOUR-TFSTATE-BUCKET> \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket <YOUR-TFSTATE-BUCKET> \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-encryption \
  --bucket <YOUR-TFSTATE-BUCKET> \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

### 2. Create the state lock table

Lock table is a one-time setup per account — it cannot be managed by the Terraform it locks (chicken-and-egg).

```bash
aws dynamodb create-table \
  --table-name fleetmind-tf-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

### 3. Write your local `backend.hcl`

From the root of your fleet repo (created from [`fleetmind-template`](https://github.com/Continuous-Agentics/fleetmind-template)):

```bash
cp backend.example.hcl backend.hcl
$EDITOR backend.hcl   # fill in bucket, region, etc.
```

`backend.hcl` is gitignored — each operator maintains their own.

### 4. Initialize Terraform with the backend config

```bash
terraform init -backend-config=backend.hcl
```

This sets up the S3 backend and DDB lock for all future Terraform operations.

## Per-fleet: workspace + tfvars

### 1. Create a Terraform workspace per fleet

```bash
terraform workspace new fleet-a        # first fleet
terraform workspace new fleet-b        # second fleet (parallel)
```

State files land at `s3://<bucket>/env:/<workspace>/fleetmind/terraform.tfstate` automatically.

### 2. Per-fleet tfvars

Each workspace needs its own `workspaces/<fleet>.tfvars` file (at the repo root).
Copy the template's starter and adjust:

```bash
cp workspaces/default.tfvars workspaces/fleet-b.tfvars
# Edit:
#   - aws_region (if different)
#   - delegation_enabled
```

`fleetmind render` (or `push fleet`) also writes a companion `.derived.tfvars` for
the fleet-derived variables (agent names, models, orchestrators). Apply both
files together:

```bash
terraform workspace select fleet-a
terraform apply -var-file=workspaces/fleet-a.tfvars -var-file=workspaces/fleet-a.derived.tfvars

terraform workspace select fleet-b
terraform apply -var-file=workspaces/fleet-b.tfvars -var-file=workspaces/fleet-b.derived.tfvars
```

### 3. Per-fleet fleet.yaml

Each fleet needs its own `fleet.yaml` (or a top-level YAML with the same structure). Copy the existing `fleet.yaml` and edit:

- `fleet.name` (must be unique per AWS account)
- Per-agent Slack `bot_user_id`, `channels` (different Slack apps + channels per fleet)
- Network CIDR if the fleet shares an account with another fleet (non-overlapping)

Pass to fleetmind commands explicitly:

```bash
fleetmind push fleet --fleet ./fleet-test2.yaml --restart
fleetmind slack discover --fleet ./fleet-test2.yaml
fleetmind secrets populate --fleet ./fleet-test2.yaml --interactive
```

## Cost & quota considerations

Each fleet creates its own VPC, NAT Gateway, EC2 instances, and S3 ledger bucket. Approximate ongoing cost per fleet:

- NAT Gateway: ~$32/mo
- 2 EC2 t4g.medium: ~$60/mo (or higher with m7g.large)
- VPC interface endpoints (optional, `enable_interface_endpoints = true`): ~$80/mo

AWS account quotas worth checking before adding fleets:
- VPCs per region (default 5)
- Elastic IPs (default 5 — NAT uses 1 per fleet)
- EC2 instance limits per family

## Switching between fleets

```bash
terraform workspace list
terraform workspace show
terraform workspace select <name>
```

All fleetmind CLI commands (push, pull-self, secrets, discover, etc.) accept `--fleet <path>` to target a specific fleet.yaml. The renderer's per-agent slicing means each agent gets its own openclaw.json regardless of how many fleets exist.

## Migrating an existing local-state deploy to remote state

If you've been deploying with local state (`terraform.tfstate` on disk) and want to migrate:

```bash
terraform init -backend-config=backend.hcl -migrate-state
# Terraform asks: "Do you want to copy existing state to the new backend?" — yes.
```

After migration, the local `terraform.tfstate*` files can be deleted (they're orphaned).

---

## Tearing down a fleet

> ⚠️ **Do NOT delete the shared Terraform state S3 bucket or DynamoDB lock table** — they are used by all fleets. Only remove per-fleet resources.

### 1. Terraform destroy

```bash
terraform workspace select <fleet-name>
terraform destroy -var-file=workspaces/<fleet-name>.tfvars -var-file=workspaces/<fleet-name>.derived.tfvars
```

This removes the VPC, NAT Gateway, EC2 instances, IAM roles, S3 ledger bucket, DDB tasks table, EventBridge rules, and NATS resources for the fleet.

### 2. Secrets Manager cleanup

FleetMind stores bot credentials under `/fleetmind/<fleet>/agents/<agent>/...`. Delete each secret after `terraform destroy` — Secrets Manager does not remove them automatically.

```bash
# List all secrets for the fleet
aws secretsmanager list-secrets \
  --filter Key=name,Values=/fleetmind/<fleet>/ \
  --query 'SecretList[].Name' --output text

# Delete each secret (force-delete skips the 30-day recovery window)
aws secretsmanager delete-secret \
  --secret-id /fleetmind/<fleet>/agents/<agent>/slack \
  --force-delete-without-recovery
# Repeat for each secret path returned above.
```

Common paths per agent:
- `/fleetmind/<fleet>/agents/<agent>/slack`
- `/fleetmind/<fleet>/agents/<agent>/anthropic`
- `/fleetmind/<fleet>/agents/<agent>/hooks`
- `/fleetmind/<fleet>/agents/<agent>/github-packages`

### 3. SSM Parameter Store cleanup

GitHub App credentials (app-id, installation-id, PEM) are stored in SSM and are also not removed by `terraform destroy`.

```bash
# Enumerate all SSM parameters for the fleet
aws ssm get-parameters-by-path \
  --path /fleetmind/<fleet>/ \
  --recursive \
  --query 'Parameters[].Name' --output text

# Delete them in one call (up to 10 at a time)
aws ssm delete-parameters \
  --names \
    /fleetmind/<fleet>/agents/<agent>/github-app/app-id \
    /fleetmind/<fleet>/agents/<agent>/github-app/installation-id \
    /fleetmind/<fleet>/agents/<agent>/github-app/pem
# Repeat for each agent, or pipe the get-parameters-by-path output into
# xargs to batch-delete in one command:
aws ssm get-parameters-by-path \
  --path /fleetmind/<fleet>/ \
  --recursive \
  --query 'Parameters[].Name' \
  --output text | xargs -n10 aws ssm delete-parameters --names
```

### 4. Remove the Terraform workspace

```bash
terraform workspace select default
terraform workspace delete <fleet-name>
```
