# default.tfvars — infra-only knobs for the default workspace.
#
# DO NOT set fleet_name, agent_names, agent_orchestrators, or
# wake_target_session_key here — those are derived from fleet.yaml by
# `fleetmind render` into workspaces/default.derived.tfvars (gitignored).

# ── Region ──────────────────────────────────────────────────────────────────
aws_region = "us-west-2"

# ── EC2 sizing ──────────────────────────────────────────────────────────────
instance_type = "t3.medium"

# Per-agent overrides (optional). Agents not listed fall back to instance_type.
agent_instance_types = {
  # blanket = "t3.large"
}

# ── Per-agent gateway ports ─────────────────────────────────────────────────
# Each agent needs a unique port. Convention: start at 18789 and increment.

# ── Software pins ───────────────────────────────────────────────────────────
openclaw_version  = "latest"
node_version      = "22"
fleetmind_version = "0.4.19"

# ── Delegation substrate ────────────────────────────────────────────────────
# Task-ledger DDB + S3 narratives + EventBridge Pipe. Default true.
# Set false only for single-bot fleets that don't use bot-to-bot delegation.
delegation_enabled = true

# ── VPC interface endpoints ─────────────────────────────────────────────────
# Adds ~$80/mo for SSM/SecretsManager/ec2messages/ssmmessages endpoints.
# Recommended for production; off by default to keep test fleets cheap.
enable_interface_endpoints = false

# ── Secrets Manager recovery ────────────────────────────────────────────────
# 0 = delete immediately (no recovery delay on terraform destroy — useful while
# iterating on a fleet). 7–30 = days of recovery for production. Default below
# is 0 since template-derived fleets typically get destroyed several times
# before stabilizing; bump to 7+ for production fleets.
secret_recovery_window_days = 0

# ── BYO VPC (optional) ──────────────────────────────────────────────────────
# Leave vpc_id empty (default) to let the module create a fresh VPC.
# To deploy into an existing VPC, set vpc_id and both subnet lists.
#
# vpc_id                      = "vpc-0123456789abcdef0"
# existing_public_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
# existing_private_subnet_ids = ["subnet-ccc", "subnet-ddd"]
