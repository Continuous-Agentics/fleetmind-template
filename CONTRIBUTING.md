# Contributing to fleetmind-template

This repo is the starter template for new FleetMind fleets. Changes should keep the first-run path clear and compatible with the current FleetMind CLI and Terraform module baseline.

## Local Checks

```bash
terraform fmt -check
terraform init -backend=false
terraform validate
```

## Pull Requests

- Open PRs against `main`.
- Include the operator-facing reason for the change.
- Update `CHANGELOG.md` when defaults, pins, or docs change.
- Keep `main.tf`, `variables.tf`, `workspaces/default.tfvars`, and docs examples aligned with the compatibility matrix in `Continuous-Agentics/fleetmind`.

