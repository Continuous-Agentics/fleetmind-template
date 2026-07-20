# FleetMind Onboard Troubleshooting

`fleetmind onboard` is designed to be re-run. If a step fails, fix the underlying resource or credential, then run `fleetmind onboard` again from the fleet repo root. Completed steps are detected and skipped where possible.

## First-time checklist

- Run from the repo created from `fleetmind-template`, not from the template source repo.
- Install the public CLI: `npm install -g @continuous-agentics/fleetmind`.
- Confirm the active AWS account and region before Terraform steps.
- Fill in `fleet.yaml`, `COMPANY.md`, and `workspaces/<workspace>.tfvars` before starting.
- Keep generated Slack app manifests and downloaded GitHub App PEM files until onboard stores the final credentials.

## Step 1 — Validate `fleet.yaml`

Runs `fleetmind render --check`.

Common failures:
- YAML parse error: fix indentation, list markers, or quoting.
- Missing required fields: add the fleet name, agent IDs, targets, providers, and Slack channel blocks.

Confirm complete:
```bash
fleetmind render --check --fleet fleet.yaml
```

Safe to re-run: yes.

## Step 2 — Generate Slack manifests

Writes Slack app manifest files under `docs/slack-manifests/`.

Common failures:
- Manifest output path missing or unwritable: create the directory or fix repo permissions.
- Stale agent names: re-run after editing `fleet.yaml`.

Confirm complete:
```bash
ls docs/slack-manifests
```

Safe to re-run: yes; generated manifests are deterministic from `fleet.yaml`.

## Step 3 — Collect Slack credentials

Prompts for each agent's bot token, signing secret, app token, and channel IDs.

Common failures:
- Token rejected by Slack: verify the app is installed and the token starts with the expected prefix.
- Missing channel membership: invite the bot to each channel listed in `fleet.yaml`.

Confirm complete:
```bash
fleetmind slack discover --fleet fleet.yaml --check
```

Safe to re-run: yes; re-enter credentials if an app was recreated.

## Step 4 — Discover Slack bot user IDs

Calls Slack auth APIs and writes `bot_user_id` values back into `fleet.yaml`.

Common failures:
- `auth.test` fails: wrong bot token or app not installed.
- Channel lookup fails: bot is not in the channel or the channel ID is wrong.

Confirm complete:
```bash
rg -n 'bot_user_id: "U' fleet.yaml
```

Safe to re-run: yes.

## Step 5 — Create GitHub Apps

Uses `fleetmind github-app create` for agents with GitHub access enabled.

Common failures:
- Browser callback interrupted: rerun the command, or delete the partial GitHub App and retry.
- Wrong owner/org: rerun with `--owner <github_org>` matching the repo owner.
- Non-code agent should skip GitHub: set `github_access: false` for that agent.

Confirm complete:
```bash
fleetmind github-app create --fleet fleet.yaml --agent <agent_id> --owner <github_org> --dry-run
```

Safe to re-run: yes, but clean up partial GitHub Apps in GitHub if the manifest flow created duplicates.

## Step 6 — Verify FleetMind package availability

Confirms the operator and EC2 bootstrap can install the public npm package.

Common failures:
- Package version not found: update `fleetmind_version` in the workspace tfvars.
- npm/network failure: verify npm registry access from the operator machine and, if needed, EC2 networking.

Confirm complete:
```bash
npm view @continuous-agentics/fleetmind version
rg -n 'fleetmind_version' workspaces/*.tfvars
```

Safe to re-run: yes.

## Step 7 — Render Terraform variables

Writes `workspaces/<workspace>.derived.tfvars`.

Common failures:
- Derived tfvars path missing: run from repo root.
- Agent/provider mismatch: make every provider used by an agent appear in its `providers` list.

Confirm complete:
```bash
ls workspaces/*.derived.tfvars
```

Safe to re-run: yes; derived tfvars are generated artifacts.

## Step 8 — Terraform init, plan, and apply

Prints the exact Terraform commands and waits for the operator to run them.

Common failures:
- Backend not initialized: fill `backend.hcl` and run `terraform init -backend-config=backend.hcl`.
- State lock error: confirm no other Terraform run is active before force-unlocking.
- AWS quota or permission error: fix the account limit/IAM policy, then rerun `terraform apply`.

Confirm complete:
```bash
terraform output
terraform state list | head
```

Safe to re-run: yes; Terraform should converge or show no changes.

## Step 9 — Populate provider and gateway secrets

Writes Slack, provider, gateway, and hook secrets to Secrets Manager.

Common failures:
- Missing provider key: set the provider API key requested by onboard.
- Wrong provider name: align `providers: [...]` in `fleet.yaml` with model prefixes and plugin configuration.
- Missing hooks/gateway tokens at runtime: rerun secrets population so `<fleet>/agents/<agent>/hooks` and `<fleet>/agents/<agent>/gateway` are present.

Confirm complete:
```bash
aws secretsmanager list-secrets \
  --region us-west-2 \
  --filters Key=name,Values=<fleet>/agents/
```

Safe to re-run: yes; secrets are updated in place.

## Step 10 — Store GitHub App credentials

Stores App ID, installation ID, and PEM under each agent's SSM path.

Common failures:
- PEM file missing: use the downloaded private key or generate a new key in GitHub.
- Installation ID wrong: copy it from the GitHub App installation URL.

Confirm complete:
```bash
aws ssm get-parameter --region us-west-2 --name /fleetmind/<fleet>/agents/<agent>/github-app/app-id
aws ssm get-parameter --region us-west-2 --name /fleetmind/<fleet>/agents/<agent>/github-app/installation-id
```

Safe to re-run: yes; rerun when rotating private keys.

## Step 11 — Push fleet and restart agents

Runs `fleetmind push fleet --restart --upgrade-cli`.

Common failures:
- SSM cannot reach an instance: wait for EC2 status checks and SSM managed-instance registration.
- Service fails after restart: inspect `journalctl -u openclaw-<agent>`.
- NATS subscriber missing when delegation is enabled: inspect `fleetmind-nats-<agent>.service`.

Confirm complete:
```bash
fleetmind agent connect <agent_id> --fleet fleet.yaml --region us-west-2 --local-port 18889 --yes
```

Safe to re-run: yes.

## Step 12 — Verify

Prints connection commands and basic health checks.

Common failures:
- Slack mention/DM does not respond: check Slack app socket mode, bot channel membership, and `openclaw-<agent>` logs.
- Gateway connect fails: confirm SSM permissions and the gateway token printed by `fleetmind agent connect`.
- Delegation smoke fails: verify `delegation.enabled`, NATS service health, and task ledger table/bucket names.

Confirm complete:
```bash
terraform output ssm_connect
fleetmind agent connect <agent_id> --fleet fleet.yaml --region us-west-2 --local-port 18889 --yes
```

Safe to re-run: yes.
