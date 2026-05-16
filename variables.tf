###############################################################################
# Operator-facing variables.
#
# Most of these pass straight through to terraform-aws-fleetmind. A few are
# derived from fleet.yaml by `fleetmind render` and written to
# workspaces/<name>.derived.tfvars (don't set those in workspaces/<name>.tfvars
# manually).
###############################################################################

# ── Derived by `fleetmind render` from fleet.yaml ────────────────────────────
# Do not set these in workspaces/<name>.tfvars — the renderer writes them to
# workspaces/<name>.derived.tfvars.

variable "fleet_name" {
  description = "Fleet name (derived). Set in fleet.yaml under fleet.name."
  type        = string
}

variable "agent_names" {
  description = "List of agent IDs (derived). Set in fleet.yaml under agents.list[].id."
  type        = list(string)
}

variable "agent_orchestrators" {
  description = "Map of agent_id → orchestrator-flag (derived). True for PM bots, false for workers."
  type        = map(bool)
  default     = {}
}

variable "wake_target_session_key" {
  description = "OpenClaw session key for the task-ledger wake-up rule (derived). Format: agent:main:slack:channel:<channel_id>."
  type        = string
  default     = ""
}

# ── Operator-owned infrastructure knobs ──────────────────────────────────────
# Set these in workspaces/<name>.tfvars.

variable "aws_region" {
  description = "AWS region for the fleet."
  type        = string
  default     = "us-west-2"
}

variable "architecture" {
  description = "CPU architecture for both the AMI and the instance type. 'arm64' (Graviton, default) or 'x86_64' (Intel/AMD). var.instance_type and var.agent_instance_types entries must match."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture must be 'arm64' or 'x86_64'."
  }
}

variable "instance_type" {
  description = "Default EC2 instance type for agent bots. Must match var.architecture (t4g.* for arm64, t3.*/t4.* for x86_64)."
  type        = string
  default     = "t4g.large"
}

variable "agent_instance_types" {
  description = "Per-agent EC2 instance type overrides. Agents not listed fall back to var.instance_type."
  type        = map(string)
  default     = {}
}

variable "openclaw_version" {
  description = "OpenClaw npm package version pin."
  type        = string
  default     = "latest"
}

variable "node_version" {
  description = "Node.js major version (installed via nvm)."
  type        = string
  default     = "22"
}

variable "fleetmind_version" {
  description = "Fleetmind CLI version pin. Must be an exact version (no 'latest') and must match the renderer that produced the .derived.tfvars in this checkout."
  type        = string
  default     = "0.6.3"
}

variable "delegation_enabled" {
  description = "Provision the task-ledger substrate (DynamoDB tasks + S3 narratives + EventBridge Pipe). Default true."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Provision SSM + Secrets Manager interface endpoints (~$80/mo, 4 endpoints * ~$20/mo). Recommended for production fleets that want SSM resilience independent of NAT health."
  type        = bool
  default     = false
}

variable "secret_recovery_window_days" {
  description = "AWS Secrets Manager recovery window (days). Must be 0 or 7–30. Use 0 for ephemeral test fleets to avoid the recovery delay on terraform destroy."
  type        = number
  default     = 7
}

# ── BYO VPC (optional) ───────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the created VPC. Ignored when vpc_id is set (BYO VPC mode)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "ID of an existing VPC to deploy into. Leave empty (default) to create a new VPC."
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "Public subnet IDs (2 required) when deploying into an existing VPC."
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "Private subnet IDs (2 required) when deploying into an existing VPC."
  type        = list(string)
  default     = []
}
