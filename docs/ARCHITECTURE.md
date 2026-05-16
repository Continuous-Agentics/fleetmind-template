# FleetMind Architecture

The implementation details behind the concepts in [CONCEPTS.md](./CONCEPTS.md). Read this when you're extending fleetmind, debugging the wake pipeline, working with the task ledger directly, or otherwise need to know *how* the pieces fit together — not just what they're called.

If you're trying to bring up your first fleet, you don't need this file. Use [QUICKSTART.md](./QUICKSTART.md).

---

## Gateway

The OpenClaw gateway process running on each agent's EC2 host as a systemd unit (`openclaw-<agent_id>.service`). It maintains the Slack socket connection, runs the LLM loop, and exposes the agent's local port for inter-process calls. One gateway per agent — no co-tenancy.

## Plugin

Like a skill, but at the gateway level rather than per-task. Plugins are loaded at gateway startup and stay loaded for the life of the process. The canonical plugin is `anthropic` (the LLM provider). Configured in `agents.defaults.plugins` or per-agent.

The distinction: skills are *how the agent solves a specific kind of problem*; plugins are *what the gateway can connect to at all*.

## Skill source and versioning

Skills have a **source**:

- `fleetmind` — ships bundled in the fleetmind package under `openclaw/skills/`
- `client` — fleet-local skills under [`skills/`](../skills/README.md) in this repo, plus any external versioned skills repo configured via `skills_repo` in `fleet.yaml`

Skills can be **pinned** (`version: "2.1.0"`) or unpinned. Unpinned skills auto-update when `fleetmind watch` runs.

## ContextStore internals

Keys are namespaced:

```text
{fleetName}/{scope}/{key}
```

Common scopes: `shared/` (fleet-wide), `<agent_id>/` (per-agent).

In dev mode (`provider: local`), the store is in-memory only — data does not survive process restart. A warning is printed so you know you're not hitting real DynamoDB.

The table ARN is exported as a Terraform output (`context_store_table_arn`) so external services can be granted IAM access without hardcoding table names.

## Task ledger internals

Hybrid substrate:

- **DynamoDB** (`{fleet_name}-tasks`) — structured state: status, timestamps, IDs, conditional writes
- **S3** (`{fleet_name}-ledger`) — narrative `.md` content: what got done, what was learned

Task IDs are 8-character lowercase hex. Status enum: `delegated → accepted → shipped → signed_off → merged`, with side transitions to `blocked` or `abandoned`.

For the full schema, IAM model, and conditional-write rules, see [protocol.md](./protocol.md).

## Lifecycle (`requires-human-signoff` vs. `shipped-is-done`)

Each delegated task carries a lifecycle flag declared at creation:

- **`shipped-is-done`** — the worker's `shipped` state is terminal. The PM closes the loop immediately on wake. Best for low-risk, self-verifiable work.
- **`requires-human-signoff`** — `shipped` triggers a human review step (`signed_off` state) before the task is considered closed. The PM prompts a human in Slack and waits.

Both lifecycles can still transition to `merged` (e.g. when an associated PR merges).

## Wake pipeline

How a worker's terminal status transition notifies the PM bot across isolated EC2 hosts (no shared process or socket):

```text
Worker UpdateItem (shipped|blocked|abandoned|merged)
  → DDB Stream record
  → EventBridge Pipe (filters terminal statuses)
  → EventBridge rule
  → SSM Run Command on PM's EC2
  → /opt/openclaw/ddb-wake.sh
  → openclaw agent --message "DDB_TERMINAL_WAKE: TASK#<id>"
```

Provisioned by the [`task-ledger`](https://github.com/Continuous-Agentics/terraform-aws-fleetmind/tree/v0.1.6/modules/task-ledger) submodule of [`terraform-aws-fleetmind`](https://github.com/Continuous-Agentics/terraform-aws-fleetmind), activated automatically when `delegation_enabled = true`. The DLQ topology (`{prefix}ledger-pipe-dlq`, `{prefix}ledger-wake-dlq`) catches failures for forensics.

## Sweep

The resilience layer for the wake pipeline. Each PM bot runs cron jobs (seeded into OpenClaw's cron from `fleet.yaml`) that periodically poll DDB for in-flight tasks owned by each worker. If a terminal status was missed by the live wake pipeline (e.g. the PM gateway was restarting when the event fired), the next sweep catches it.

Configured per-PM in `fleet.yaml` under `delegation.sweeps[]`. Typical cadence: every 5 minutes. Sweep jobs live in `~/.openclaw/cron/jobs.json` on the PM instance.

## Render output

`fleetmind render <fleet.yaml>` writes:

- `./rendered/openclaw-<fleet>.json` — per-agent `openclaw.json` slices
- `workspaces/<fleet>.derived.tfvars` — derived Terraform variables (`fleet_name`, `agent_names`, `agent_orchestrators`, `wake_target_session_key`), written inside this repo (created from `fleetmind-template`) for consumption by the [`terraform-aws-fleetmind`](https://github.com/Continuous-Agentics/terraform-aws-fleetmind) module

The `.derived.tfvars` suffix is intentional: those files are *not* auto-loaded by Terraform — they must be passed explicitly via `-var-file`. This prevents cross-workspace contamination when multiple fleets share an account.

## openclaw.json three-way merge

One file gets special treatment during `pull-self`: `.openclaw/openclaw.json`. Instead of an atomic overwrite, `pull-self` performs a three-way merge so that operator patches applied with `openclaw config patch` survive pushes:

```
merged = deepMerge(incoming, live − base)
```

- `incoming` — the freshly-rendered config from the new tarball
- `live`     — the current on-disk config (may have operator patches)
- `base`     — the previous render's config, snapshotted at `.openclaw/openclaw.base.json`

Keys in `live` that differ from `base` are treated as operator patches and re-applied on top of `incoming`. When patches are preserved, `pull-self --apply` logs a dim line: `ℹ live config patches preserved`. If `base` is missing (first push, or deliberately removed), the merge short-circuits and `incoming` wins. See [TROUBLESHOOTING § openclaw.json operator-patch handling](./TROUBLESHOOTING.md#openclawjson-operator-patch-handling-and-drift) for the recovery path.

All other files get atomic overwrite: modified files are written to `<dest>.new` then `mv -f` to `<dest>` — POSIX-atomic.

## Manifest

A JSON file produced by `push fleet` alongside each tarball:

```json
{
  "agent_id": "blanket",
  "fleet_name": "acme-bots",
  "fleetmind_version": "X.Y.Z",
  "rendered_at": "2026-05-12T21:30:00Z",
  "tarball": { "filename": "blanket.tar.gz", "size_bytes": 92348, "sha256": "..." },
  "files": [ { "path": "AGENTS.md", "size": 4612, "sha256": "...", "mode": 644 }, ... ]
}
```

`pull-self` diffs against `files[]`, not the tarball contents. `tarball.sha256` is verified before extraction to guard against partial uploads.

## Slack identity (account_id, bot_user_id, app/bot tokens)

Each agent has its own Slack app with two tokens:

- **`bot_token`** (`xoxb-…`) — from OAuth & Permissions → Bot User OAuth Token
- **`app_token`** (`xapp-…`) — from Basic Information → App-Level Tokens, with `connections:write` scope (used for socket mode)

Tokens are stored in AWS Secrets Manager under `/fleetmind/<fleet_name>/agents/<agent_id>/…` by `fleetmind secrets populate`.

After tokens are stored, `fleetmind slack discover` calls Slack's `auth.test` to fetch each agent's **`bot_user_id`** (`U…`) and writes it back to `fleet.yaml`. The second render uses these IDs to build per-channel `users` allowlists in `openclaw.json` — without them, peer-bot messages are silently dropped.
