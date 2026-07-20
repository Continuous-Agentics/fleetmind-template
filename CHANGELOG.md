# Changelog

All notable changes to this template are documented here. This repo is a GitHub template rather than a versioned package, so entries describe template snapshots and the FleetMind / `terraform-aws-fleetmind` versions they align with.

Going forward, every PR that changes operator-facing template behavior should add an entry under `Unreleased`.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- Documented the public npm install path for FleetMind and removed default GitHub Packages bootstrap guidance.
- Added `docs/ONBOARD-TROUBLESHOOTING.md` with step-by-step recovery notes for `fleetmind onboard`.
- Updated `docs/GITHUB-APPS.md` to make `fleetmind github-app create` the recommended GitHub App provisioning path.
- Bumped the template FleetMind pin from `0.10.0` to `0.10.4`.
- Bumped the Terraform module pin to `v1.1.5` for public npm bootstrap and no-delegation deploy-staging reads.

## 2026-07-16 Snapshot

Aligned with:
- FleetMind CLI: `0.10.0`
- `terraform-aws-fleetmind`: `v1.1.0`

### Changed

- Bumped template defaults to FleetMind `0.10.0`.
- Preserved the `v1.1.0` Terraform module pin for NATS-based delegation and OpenClaw gateway deployment.

## 2026-07-09 Snapshot

Aligned with:
- FleetMind CLI: `0.9.0`
- `terraform-aws-fleetmind`: `v1.1.0`

### Changed

- Reframed self-start docs so worker self-start is tracker-agnostic and Slack-driven.
- Updated teardown guidance and CLI ambiguity notes.
- Bumped Terraform module pin to `v1.1.0`.

## 2026-06-20 Snapshot

Aligned with:
- FleetMind CLI: `0.8.x`
- `terraform-aws-fleetmind`: `v1.0.0`

### Changed

- Documented GitHub access as enabled by default per agent.
- Added `github_access: false` as the opt-out path for agents that do not touch code.
- Removed dead wake-target variables and aligned the template with the `v1.0.0` module.

## 2026-06-08 Snapshot

Aligned with:
- FleetMind CLI: `0.8.0-beta.x`
- `terraform-aws-fleetmind`: `v0.5.0`

### Changed

- Bumped the Terraform module to `v0.5.0`.
- Added explicit per-agent provider declarations to match per-provider Secrets Manager paths.

## 2026-05-29 Snapshot

Aligned with:
- FleetMind CLI: `0.8.0-beta.8`
- `terraform-aws-fleetmind`: `v0.4.x`

### Changed

- Retired `delegation.sweeps` from the template.
- Documented NATS push as the standard delegation wake path.

## 2026-05-27 Snapshot

Aligned with:
- FleetMind CLI: `0.8.0-beta.1`
- `terraform-aws-fleetmind`: `v0.4.0`

### Changed

- Migrated `fleet.yaml` to the v2 schema with explicit `targets` and `channels`.
- Added NATS transport configuration and updated quickstart/setup docs.

## 2026-05-16 Snapshot

Aligned with:
- FleetMind CLI: `0.6.3`
- `terraform-aws-fleetmind`: `v0.1.x`

### Changed

- Added `architecture` as an operator variable and defaulted the template to Graviton `arm64`.
- Removed `agent_ports`; gateway port configuration moved into `fleet.yaml`.
- Split concepts and architecture docs.
- Renamed example bots to Conductor and Forge.

## 2026-05-14 Snapshot

Aligned with:
- FleetMind CLI: `0.5.x`
- `terraform-aws-fleetmind`: `v0.1.6`

### Added

- Added `COMPANY.md` starter and README/QUICKSTART pointers.
- Relocated operator docs from the FleetMind CLI repo into this template.

## 2026-05-13 Snapshot

Aligned with:
- FleetMind CLI: `0.4.x`
- `terraform-aws-fleetmind`: `v0.1.0` through `v0.1.3`

### Added

- Initial FleetMind template scaffold.
- Added `fleetmind onboard` docs and manual reference flow.
- Added GitHub Apps setup, Slack workflow notes, skills directory, and push-fleet restart guidance.
