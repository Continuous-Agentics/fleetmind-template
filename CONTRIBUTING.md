# Contributing to fleetmind-template

Thank you for your interest in contributing. This repo is the starter template for new FleetMind fleets, so changes should preserve a clear first-run path for operators.

## Dev Setup

**Prerequisites:** Terraform `>= 1.5`, AWS provider compatibility with the checked-in lockfile, Node.js 22+ if you are validating FleetMind CLI examples.

External contributors should fork first, then clone their fork:

```bash
gh repo fork Continuous-Agentics/fleetmind-template --clone
cd fleetmind-template
terraform fmt -check
terraform init -backend=false
terraform validate
```

Maintainers can clone upstream directly:

```bash
git clone https://github.com/Continuous-Agentics/fleetmind-template.git
cd fleetmind-template
terraform fmt -check
terraform init -backend=false
terraform validate
```

Do not run `terraform apply` against a real AWS account unless you are intentionally testing a fleet deployment.

## Test Conventions

- Run `terraform fmt -check` for every Terraform change.
- Run `terraform init -backend=false` and `terraform validate` for module input/output changes.
- Keep examples in README, `docs/`, `variables.tf`, `main.tf`, and `workspaces/default.tfvars` aligned.
- Prefer dry-run or validation evidence in PRs unless the change specifically requires a live AWS smoke test.
- Redact AWS account IDs, Slack tokens, GitHub App credentials, provider API keys, and Terraform state snippets before sharing logs.

## Compatibility Contract

This template consumes:

- `@continuous-agentics/fleetmind`
- `terraform-aws-fleetmind`

When changing pins, generated tfvars expectations, onboarding docs, secrets, or bootstrap assumptions, check the compatibility matrix in `Continuous-Agentics/fleetmind/docs/COMPATIBILITY.md` and coordinate companion PRs as needed.

## Branch & Commit Conventions

Use Conventional Commits:

```text
feat | fix | docs | chore | refactor | test
```

Branch off `main`:

```bash
git checkout main && git pull --ff-only
git checkout -b docs/your-change
```

Keep PRs focused. Squash noisy WIP commits before opening a PR.

## Pull Request Conventions

- Title: Conventional Commit style, for example `docs: clarify guided onboarding`.
- Body: describe what changed, why it matters to operators, and how it was verified.
- Link issues with `Closes #123` or `Refs #123`.
- CI must be green before merge.
- Update `CHANGELOG.md` when defaults, pins, docs, or operator behavior change.
- At least one maintainer approval is required to merge to `main`.

## Where to File Things

| What | Where |
|------|-------|
| Template bugs | GitHub Issues with the `bug` label |
| New operator workflow requests | GitHub Issues with the `enhancement` label |
| Documentation gaps | GitHub Issues or PRs with the `documentation` label |
| Security vulnerabilities | GitHub Security Advisories; do not file publicly |
| CLI or module bugs | File in `fleetmind` or `terraform-aws-fleetmind` and link back if template docs are affected |

## Releases

This is a GitHub template repo, not an npm package. It does not use semver releases. The effective version is the `main` commit used when a customer creates a fleet repo.

Before merging operator-facing changes:

- [ ] `CHANGELOG.md` updated.
- [ ] Terraform checks pass.
- [ ] FleetMind CLI and module pins match the intended compatibility baseline.
- [ ] Docs examples match current command behavior.

## License / DCO

No CLA is required. By contributing, you agree that your contributions are licensed under the project's [MIT license](./LICENSE). The standard inbound=outbound licensing model applies.

## Conduct

Be direct, respectful, and constructive. Maintainers may close or edit issues that are spammy, abusive, or unrelated to FleetMind.

