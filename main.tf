###############################################################################
# fleetmind-template — operator root for a Fleetmind fleet
#
# This file calls the terraform-aws-fleetmind module. Most operator
# customization happens in:
#   - fleet.yaml                       — bot declarations (fleetmind render → derived.tfvars)
#   - workspaces/<name>.tfvars         — per-workspace infra knobs (region, sizes, etc.)
#   - backend.hcl                      — operator-local state backend config (gitignored)
#
# Run `terraform init -backend-config=backend.hcl` once, then `terraform apply
# -var-file=workspaces/<name>.tfvars -var-file=workspaces/<name>.derived.tfvars`.
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — partial config. Fill in bucket/region/dynamodb_table via
  # backend.hcl (see backend.example.hcl). The `key` argument is intentionally
  # omitted: Terraform workspaces auto-prefix state files with `env:/<workspace>/`,
  # so the workspace itself isolates state across fleets in the same operator
  # account. Run `terraform workspace new <fleet-name>` per fleet.
  backend "s3" {
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.fleet_name
      ManagedBy   = "terraform"
      FleetmindBy = "fleetmind-template"
    }
  }
}

module "fleetmind" {
  source = "github.com/Continuous-Agentics/terraform-aws-fleetmind?ref=v0.4.0"

  # ── Derived from fleet.yaml via `fleetmind render` ──────────────────────────
  fleet_name              = var.fleet_name
  agent_names             = var.agent_names
  agent_orchestrators     = var.agent_orchestrators
  wake_target_session_key = var.wake_target_session_key

  # ── Operator-owned infrastructure knobs ─────────────────────────────────────
  aws_region                  = var.aws_region
  architecture                = var.architecture
  instance_type               = var.instance_type
  agent_instance_types        = var.agent_instance_types
  openclaw_version            = var.openclaw_version
  node_version                = var.node_version
  fleetmind_version           = var.fleetmind_version
  delegation_enabled          = var.delegation_enabled
  enable_interface_endpoints  = var.enable_interface_endpoints
  secret_recovery_window_days = var.secret_recovery_window_days

  # ── BYO VPC (optional) ──────────────────────────────────────────────────────
  vpc_cidr                    = var.vpc_cidr
  vpc_id                      = var.vpc_id
  existing_public_subnet_ids  = var.existing_public_subnet_ids
  existing_private_subnet_ids = var.existing_private_subnet_ids
}
