# FleetMind Quickstart

This is the narrative happy-path for bringing up a working 2-bot fleet. First-time bring-up realistically takes *~20–30 minutes* end-to-end — of which roughly half is clicking through the Slack UI to create two apps and copy four tokens. Once Slack is set up and AWS bootstrap is done, the iteration loop drops to about a minute (`render` + `push fleet --restart`). The last step is *"DM your PM bot in Slack and ask it to delegate a task."*

If anything is unfamiliar, see [CONCEPTS.md](./CONCEPTS.md) for the vocabulary. For the comprehensive reference with every option, see [SETUP-A-FLEET.md](./SETUP-A-FLEET.md). When something breaks, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

> **Faster path:** `fleetmind onboard` is an interactive wizard that drives every step below automatically — see [fleetmind-template § Guided onboarding](https://github.com/Continuous-Agentics/fleetmind-template#guided-onboarding-recommended). The manual flow below exists so you can see what's happening under the hood when something goes wrong.

---

## Prerequisites

This fast-path assumes you have:

- **fleetmind CLI** installed locally (`npm install -g @continuous-agentics/fleetmind` — see [README.md](../README.md) for the `~/.npmrc` PAT setup if `npm install` 404s)
- **AWS CLI v2** configured for your target account, with admin or equivalent permissions
- **Terraform ≥ 1.5** (`tfenv` works fine for managing the version)
- **Slack workspace** admin access (you'll create apps and channels)
- **One-time AWS account setup done**: TF state S3 bucket, DynamoDB lock table, GitHub Packages PAT stored in SSM at `/fleetmind/shared/github-packages-token`. If not, jump to [§First-time setup](#first-time-setup-cold-start) at the bottom, then come back.
- **Your fleet repo created from [`fleetmind-template`](https://github.com/Continuous-Agentics/fleetmind-template)** (click **Use this template** in the GitHub UI, then `git clone` your new repo). The template ships `main.tf` (which calls [`terraform-aws-fleetmind`](https://github.com/Continuous-Agentics/terraform-aws-fleetmind)), `variables.tf`, `outputs.tf`, `backend.example.hcl`, and a starter `fleet.yaml` + `workspaces/default.tfvars`.

**`cd` into your fleet repo before running anything below — every command in this guide is relative to that directory:**

```bash
git clone git@github.com:<your-org>/<your-fleet-repo>.git
cd <your-fleet-repo>
```

Target region for this walkthrough: `us-west-2`.

---

## 1. Edit fleet.yaml + COMPANY.md (~5 min)

The template ships starter versions of both files at the repo root. Edit both before continuing.

### 1a. `fleet.yaml`

Replace its `agents.list[]` (and the `fleet` block at the top) with this minimal 2-bot definition:

> **Starting outside the template?** `fleetmind init --name acme --client "Acme Corp" --output fleet-acme.yaml` scaffolds a standalone `fleet.yaml` you can drop into any repo — but the canonical path is to edit the template's existing `fleet.yaml` directly.

```yaml
fleet:
  name: acme
  version: "1.0.0"
  client: "Acme Corp"

delegation:
  enabled: true
  aws_region: us-west-2
  table_name: acme-tasks         # matches Terraform default ${fleet_name}-tasks
  s3_bucket: acme-ledger         # matches Terraform default ${fleet_name}-ledger

agents:
  defaults:
    model: anthropic/claude-haiku-4-5
    workspace_base: /opt/openclaw/workspace
    plugins:
      - anthropic

  list:
    - id: pm
      name: "PM Bot"
      emoji: 🎼
      role: pm
      orchestrator: true
      model: anthropic/claude-sonnet-4-6
      persona:
        soul: |
          You are PM Bot, a project-management bot. You receive tasks from humans, delegate
          to worker bots via NATS, track everything in a task ledger, and close the loop.
      slack:
        account_id: pm
        channels:
          - "C_HOME_CHANNEL_ID"        # PM's home channel — fill in after §3
          - "C_DELEGATION_CHANNEL_ID"  # delegation channel — fill in after §3
        bot_token: "${PM_BOT_TOKEN}"
        app_token: "${PM_APP_TOKEN}"
      skills:
        - name: bot-delegation
          source: fleetmind
      agent_to_agent:
        can_send_to: [worker]
      delegation:
        worker_bots: [worker]
        sweeps:
          - name: pm-sweep-worker
            worker_id: worker
            every: 5m
            model: anthropic/claude-haiku-4-5

    - id: worker
      name: "Worker Bot"
      emoji: ⚙️
      role: backend-worker
      orchestrator: false
      persona:
        soul: |
          You are Worker Bot, a backend worker bot. You accept delegated tasks from
          the PM via NATS, acknowledge with :eyes:, ship the work, and report back.
      slack:
        account_id: worker
        channels:
          - "C_DELEGATION_CHANNEL_ID"  # same as PM's delegation channel
        bot_token: "${WORKER_BOT_TOKEN}"
        app_token: "${WORKER_APP_TOKEN}"
      skills:
        - name: bot-reception
          source: fleetmind
      agent_to_agent:
        can_send_to: [pm]
      delegation:
        specialty: backend

outputs:
  openclaw_json: ./rendered/openclaw-acme.json
  terraform_vars: ./workspaces/acme.derived.tfvars

openclaw:
  gateway:
    port: 18789
    mode: local
    bind: loopback
  # Hooks endpoint — used by wakeAgent() in the NATS subscriber to wake the
  # OpenClaw session. Token is generated at bootstrap and injected via
  # OPENCLAW_HOOKS_TOKEN in the service environment (see §6 below).
  hooks:
    enabled: true
    path: /hooks
    allowed_agent_ids: [main]
  slack:
    mode: socket
    typing_reaction: black_cat
    ack_reaction: eyes
    allow_bots: true
    history_limit: 50
    streaming:
      mode: partial
      native_transport: true
    reply_to_mode_by_chat_type:
      channel: all
```

Don't fill in `C_…_CHANNEL_ID` placeholders yet — you'll get them in §3.

### 1b. `COMPANY.md`

Open `COMPANY.md` at the repo root. Fill in the placeholder sections — mission, products, terminology, how you work, out-of-scope boundaries. *Every bot in the fleet reads this on session boot*, so the time you spend here saves the team from re-explaining basics in every conversation.

If you skip this step, bots run without org context. They'll ask basic questions ('what does this acronym mean?', 'who owns this repo?') in every session. Strongly recommend filling it in even minimally before first deploy.

## 2. Generate Slack app manifests (~10s)

```bash
fleetmind slack manifests --fleet fleet-acme.yaml --out ./rendered/slack-manifests/
```

One file appears per agent, named after that agent's `id` in `fleet.yaml`. With the example above you get `pm.yaml` and `worker.yaml`; with different agent IDs you get different filenames.

## 3. Create the Slack apps and channels (~5 min, manual UI)

This step is the longest because it's clicking through the Slack UI. Do it for **each agent** (`pm`, then `worker`):

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From a manifest**.
2. Choose your workspace, paste the YAML from `./rendered/slack-manifests/<agent>.yaml`, and click **Create**. This creates the app but does *not* install it to your workspace yet — the bot token doesn't exist until install.
3. On the app's settings page, go to **Basic Information → App-Level Tokens → Generate Token and Scopes**. Add the `connections:write` scope (required for socket mode) and click **Generate**. Copy the **App-Level Token** (`xapp-…`) — this is the only time it's shown.
4. Go to **Install App** in the left sidebar, click **Install to Workspace**, then **Allow** on the OAuth consent page.
5. After install, you're returned to the **Install App** page (or **OAuth & Permissions**) where the **Bot User OAuth Token** (`xoxb-…`) is now displayed. Copy it.

Then in your Slack workspace:

- Create `#acme-pm` (PM's home channel) and `#acme-delegation` (shared)
- `/invite @PM Bot` to both channels
- `/invite @Worker Bot` to `#acme-delegation` only
- Right-click each channel → **Copy link**. The channel ID is the `C…` segment at the end of the URL

Fill the channel IDs back into `fleet-acme.yaml`:

```yaml
# PM agent
slack:
  channels:
    - "CXXXXXXXXXX"   # #acme-pm
    - "CYYYYYYYYYY"   # #acme-delegation

# Worker agent
slack:
  channels:
    - "CYYYYYYYYYY"   # #acme-delegation only
```

> **Why now and not later:** Channel IDs must be filled in before the first render so `fleetmind render` can include peer bot IDs in each agent's Slack allowlist. Channels without real IDs produce placeholder allowlists and inter-bot Slack messages will be silently dropped.

## 4. First render (~5s)

```bash
fleetmind render fleet-acme.yaml
```

Writes `./rendered/openclaw-acme.json` and `./workspaces/acme.derived.tfvars` (both relative to the repo root).

## 5. Edit the infra-only tfvars (~30s)

The template ships `workspaces/default.tfvars` as a starting point. Two options:

- *Single-fleet repo* (most operators): edit `workspaces/default.tfvars` directly. Use "default" as the Terraform workspace name in step 6.
- *Multi-fleet repo* (one repo, several fleets): copy `default.tfvars` to a per-fleet file. Below shows the multi-fleet pattern using `acme` as the fleet name:

```bash
cp workspaces/default.tfvars workspaces/acme.tfvars
```

Minimum contents:

```hcl
aws_region    = "us-west-2"
architecture  = "arm64"      # or "x86_64" — must match instance_type below
instance_type = "t4g.large"  # arm64; use a t3.*/t4.* type if architecture = "x86_64"

openclaw_version  = "latest"
node_version      = "22"
fleetmind_version = "X.Y.Z"   # pin to current stable — `npm view @continuous-agentics/fleetmind version`

delegation_enabled = true
enable_interface_endpoints = false
agent_instance_types = {}
```

## 6. Apply Terraform (~3 min)

From the root of this repo (created from `fleetmind-template`):

```bash
terraform init -backend-config=backend.hcl
terraform workspace new acme || terraform workspace select acme
terraform apply \
  -var-file=workspaces/acme.tfvars \
  -var-file=workspaces/acme.derived.tfvars
```

The template's `main.tf` calls [`module "fleetmind" { source = "github.com/Continuous-Agentics/terraform-aws-fleetmind?ref=v0.1.6" ... }`](https://github.com/Continuous-Agentics/terraform-aws-fleetmind) — bump `?ref=` in `main.tf` to upgrade the module.

Expect ~60–80 resources to add (VPC, NAT, EC2, IAM, SSM params, S3, DynamoDB, EventBridge). Confirm with `yes`. Wait for completion, then for EC2 bootstrap to finish (~3–5 min more — the instances run a multi-stage bootstrap script on first launch).

Check bootstrap completion:

```bash
INSTANCE_ID=$(terraform output -json instance_ids | jq -r '.pm')
aws ec2 get-console-output --instance-id "$INSTANCE_ID" --region us-west-2 \
  --query 'Output' --output text | tail -20
```

Look for `[bootstrap] Done. Agent pm provisioned.`.

## 7. Populate secrets (~1 min, interactive)

```bash
cd -    # back to your fleet.yaml dir
fleetmind secrets populate --fleet fleet-acme.yaml --interactive --region us-west-2
```

For each agent, paste the `xoxb-…` and `xapp-…` you copied in §3, plus your Anthropic API key. They're stored in AWS Secrets Manager under `/fleetmind/acme/agents/<agent>/…`.

## 8. Discover bot user IDs (~10s)

```bash
fleetmind slack discover --fleet fleet-acme.yaml --region us-west-2
```

Calls Slack's `auth.test` for each agent and writes `bot_user_id: U…` back into `fleet-acme.yaml`. Required for inter-bot message delivery (peers are added to per-channel allowlists by the next render).

## 9. Second render + push (~1 min)

```bash
fleetmind render fleet-acme.yaml
fleetmind push fleet --fleet fleet-acme.yaml --restart
```

The second render picks up the `bot_user_id`s; the push uploads workspaces to S3, triggers `pull-self --apply --restart` on each EC2 via SSM, and starts each agent's gateway for the first time.

## 10. Delegate a task in Slack 🎉

In Slack, DM PM Bot in `#acme-pm`:

> PM Bot, please delegate to Worker Bot: write a haiku about distributed systems and post it back in the delegation thread.

Watch the round-trip:

1. PM Bot creates a task ledger entry (DDB + S3) and **publishes a delegation event on the NATS bus** targeting Worker Bot
2. Worker Bot's NATS subscriber (`fleetmind-nats-worker.service`) receives the event, auto-acks in DDB, and wakes the Worker OpenClaw session
3. Worker Bot opens a Slack thread with the human requestor (no Slack envelope — NATS is the transport)
4. Worker Bot ships the work, posts a completion summary in the requestor's thread
5. Worker Bot calls `fleetmind task ship --task-id <task-id>` which publishes a `ship` event on NATS
   > **`fleetmind task ship` flags** (canonical form — confirm with `fleetmind task ship --help`):
   > `--task-id <id>` (required) — the 8-character hex task ID from the ledger row
6. PM Bot's NATS subscriber (`fleetmind-nats-pm.service`) receives the ship event and wakes the PM session via `POST /hooks/wake` using `OPENCLAW_HOOKS_TOKEN`

You just delegated a task across two isolated EC2 hosts with a durable audit trail. ✨

---

## 6. NATS transport + hooks: how the wake pipeline works

With the NATS transport, delegation is no longer posted as a Slack message ("envelope"). Instead, `fleetmind` publishes typed events on a NATS message bus and each agent runs a long-lived subscriber service.

### Systemd services

The bootstrap script writes two units for each agent:

| Service | Mode | Description |
|---------|------|-------------|
| `fleetmind-nats-pm.service` | `--mode pm` | PM subscriber — receives `ship`/`block` events, wakes PM session via `/hooks/wake` |
| `fleetmind-nats-worker.service` | `--mode worker` | Worker subscriber — receives delegation events, auto-acks in DDB, wakes worker session |

Both are path-activated: a `.path` unit watches for `fleet.yaml` and starts the service automatically once `fleetmind push fleet` lands the workspace. No manual `systemctl start` needed.

### NATS config in fleet.yaml

Add a `delegation.nats` block to enable the NATS bus:

```yaml
delegation:
  enabled: true
  aws_region: us-west-2
  table_name: acme-tasks
  s3_bucket: acme-ledger
  nats:
    servers:
      - nats://nats.acme.internal:4222   # Cloud Map DNS or explicit IP
    subject_prefix: fleetmind            # default; all events go to fleetmind.task.<id>.*
    connect_timeout_ms: 5000
    max_reconnect: -1                    # unlimited reconnects
```

If `delegation.nats` is absent, the subscriber service exits 0 and systemd leaves it alone — the fleet still works, but without the push-based wake path.

### Hooks config and OPENCLAW_HOOKS_TOKEN

The PM subscriber wakes the OpenClaw PM session by calling `POST /hooks/wake` on the gateway. This requires `hooks.token` in `openclaw.json` — a secret **distinct** from `gateway.auth.token` (OpenClaw enforces this and returns 401 if the same token is reused).

**How the token gets there (automatic — no operator action needed):**

1. Bootstrap (STAGE 7c) generates `openssl rand -hex 32` and stores it in Secrets Manager at `<fleet>/agents/<agent>/hooks`.
2. `fetch-agent-secrets` (runs as ExecStartPre on every service start) fetches it and writes `OPENCLAW_HOOKS_TOKEN=<token>` and `<AGENT_UPPER>_HOOKS_TOKEN=<token>` to `/run/openclaw-<agent>.env`.
3. `fleetmind render` emits `hooks.token: ${<AGENT_UPPER>_HOOKS_TOKEN}` into `openclaw.json`; OpenClaw substitutes the env var at startup.
4. The NATS subscriber service sources the same env file — `OPENCLAW_HOOKS_TOKEN` is available when `wakeAgent()` calls `/hooks/wake`.

The end result: `wakeAgent()` returns 2xx and the PM session wakes immediately on worker ship/block events.

---

## Day-to-day

After bring-up, the operator loop is short:

```bash
# Edit fleet.yaml or workspace files, then:
fleetmind push fleet --fleet fleet-acme.yaml --restart
```

See [OPERATING.md](./OPERATING.md) for the full operations reference (dry-run, single-agent push, manual `pull-self` from SSM session, restart semantics).

---

## First-time setup (cold start)

If `npm install -g @continuous-agentics/fleetmind` failed with 404, or you have no Terraform state bucket, or you've never used fleetmind in this AWS account, do these one-time steps first. They only need to happen once per account/operator.

### a. Terraform backend config (per operator clone of fleetmind-template)

Create your fleet repo from [`fleetmind-template`](https://github.com/Continuous-Agentics/fleetmind-template) (click **Use this template**, then `git clone` and `cd` into it), then from the root of that repo:

```bash
cp backend.example.hcl backend.hcl
$EDITOR backend.hcl   # fill in: bucket, region, dynamodb_table
terraform init -backend-config=backend.hcl
```

`backend.hcl` is gitignored. The bucket and lock table referenced here are created in §d below; if they don't exist yet, do §d first then come back and run `terraform init`.

### b. GitHub Packages PAT (per operator)

fleetmind is published to GitHub Packages as a private scoped package. Generate a classic PAT at [github.com/settings/tokens](https://github.com/settings/tokens) with `read:packages` scope, then:

```bash
echo "@continuous-agentics:registry=https://npm.pkg.github.com" >> ~/.npmrc
echo "//npm.pkg.github.com/:_authToken=<YOUR_PAT>" >> ~/.npmrc
npm install -g @continuous-agentics/fleetmind
```

### c. Store the PAT in SSM (one-time per AWS account)

EC2 instances also need a PAT during bootstrap to install fleetmind:

```bash
aws ssm put-parameter \
  --name /fleetmind/shared/github-packages-token \
  --type SecureString \
  --value <YOUR_PAT> \
  --region us-west-2
```

### d. Terraform state bucket + lock table (one-time per AWS account)

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

aws dynamodb create-table \
  --table-name fleetmind-tf-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

Once these are done, return to [§1](#1-edit-fleetyaml--companymd-5-min) above. Subsequent fleets in the same account reuse all of this.

For the comprehensive bring-up reference (every variable, every gotcha, the full IAM model), see [SETUP-A-FLEET.md](./SETUP-A-FLEET.md).
