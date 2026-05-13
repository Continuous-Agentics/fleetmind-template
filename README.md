# fleetmind-template

Operator-side starter for a [Fleetmind](https://github.com/Continuous-Agentics/fleetmind) fleet. Fork or clone this repo, edit a few files, and `terraform apply` to stand up a multi-bot fleet on AWS.

This repo *consumes* [`terraform-aws-fleetmind`](https://github.com/Continuous-Agentics/terraform-aws-fleetmind) as a module (currently pinned to `v0.1.0`). It does not vendor the module's source — bump the `?ref=` in `main.tf` to upgrade.

## Layout

```
fleetmind-template/
├── README.md                         # this file
├── fleet.yaml                        # bot declarations (edit this)
├── main.tf                           # module call (rarely edited)
├── variables.tf                      # input surface (rarely edited)
├── outputs.tf                        # re-exported outputs
├── backend.example.hcl               # copy to backend.hcl (gitignored)
├── workspaces/
│   ├── default.tfvars                # infra-only knobs per workspace
│   └── default.derived.tfvars        # CLI-generated; gitignored
├── docs/slack-manifests/             # Slack app manifests (populated by fleetmind)
├── .github/workflows/plan.yml        # PR CI: fmt + validate
└── .gitignore
```

## Prerequisites

- AWS account with admin or equivalent permissions
- Terraform `>= 1.5`
- Node.js `>= 22`
- `@continuous-agentics/fleetmind >= 0.4.4` CLI: `npm install -g @continuous-agentics/fleetmind` *(requires GitHub Packages auth — see the [Fleetmind README](https://github.com/Continuous-Agentics/fleetmind))*
- Slack workspace admin (for creating per-bot Slack apps)

## One-time setup per operator

1. *Fork or clone this repo* into your own org. Rename if you want.
2. *Create a Terraform state backend* (one-time per operator account):
    ```bash
    aws s3 mb s3://my-fleet-tfstate --region us-west-2
    aws dynamodb create-table \
      --table-name my-fleet-tfstate-lock \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region us-west-2
    ```
3. *Copy `backend.example.hcl` to `backend.hcl`* and fill in the bucket/region/table you just created. `backend.hcl` is gitignored — operator-local.

## Per-fleet workflow

1. *Edit `fleet.yaml`* — set `fleet.name`, declare your agents (PMs + workers), wire up Slack channels and tokens.
2. *Edit `workspaces/default.tfvars`* — region, EC2 sizing, per-agent ports, software pins, opt-ins for VPC endpoints, BYO VPC, etc.
3. *Render the fleet.yaml-derived tfvars*:
    ```bash
    fleetmind render
    ```
    Produces `workspaces/default.derived.tfvars` (gitignored). Re-run whenever `fleet.yaml` changes.
4. *Initialize Terraform*:
    ```bash
    terraform init -backend-config=backend.hcl
    terraform workspace new my-fleet
    ```
5. *Apply*:
    ```bash
    terraform apply \
      -var-file=workspaces/default.tfvars \
      -var-file=workspaces/default.derived.tfvars
    ```
6. *Populate Slack + Anthropic secrets* (per agent, out-of-band):
    ```bash
    aws secretsmanager put-secret-value \
      --secret-id my-fleet/agents/blanket/slack \
      --secret-string '{"SLACK_BOT_TOKEN":"xoxb-...","SLACK_SIGNING_SECRET":"...","SLACK_APP_TOKEN":"xapp-..."}'

    aws secretsmanager put-secret-value \
      --secret-id my-fleet/agents/blanket/anthropic \
      --secret-string '{"ANTHROPIC_API_KEY":"sk-ant-..."}'
    ```
7. *Verify*:
    ```bash
    terraform output ssm_connect       # SSM commands to reach each bot
    fleetmind push-fleet               # push workspace config to running agents
    ```

## Upgrading the module

Bump the `?ref=` in `main.tf`'s `module "fleetmind"` block:

```hcl
source = "github.com/Continuous-Agentics/terraform-aws-fleetmind?ref=v0.2.0"
```

Then `terraform init -upgrade` and `terraform plan` to see what changes.

## Multi-fleet from one repo

Use Terraform workspaces. Each workspace gets its own `workspaces/<name>.tfvars` + `workspaces/<name>.derived.tfvars` and its own state path (`env:/<name>/`):

```bash
terraform workspace new fleet-a
fleetmind render --workspace fleet-a
terraform apply -var-file=workspaces/fleet-a.tfvars -var-file=workspaces/fleet-a.derived.tfvars

terraform workspace new fleet-b
fleetmind render --workspace fleet-b
terraform apply -var-file=workspaces/fleet-b.tfvars -var-file=workspaces/fleet-b.derived.tfvars
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
