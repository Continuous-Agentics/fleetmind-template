# FleetMind Concepts

A glossary of the vocabulary used across this repo and its docs. Read this first if you're new to fleetmind — most other docs assume you know these terms.

This file covers the *vocabulary* you need to follow the operator docs. For the implementation details behind these concepts (DynamoDB schemas, EventBridge wiring, three-way merge, etc.), see [ARCHITECTURE.md](./ARCHITECTURE.md).

For a guided walkthrough, see [QUICKSTART.md](./QUICKSTART.md). For a comprehensive bring-up reference, see [SETUP-A-FLEET.md](./SETUP-A-FLEET.md).

---

## The big picture

A **fleet** is a set of independent **agents** (AI bots), each running on its own EC2 host with its own OpenClaw **gateway** and Slack identity. Agents coordinate over Slack threads and a shared DynamoDB **ContextStore** — never via shared process state.

You describe the fleet in a single `fleet.yaml`. The fleetmind CLI **renders** that file into per-agent workspace artifacts and Terraform variables, then **pushes** them to each agent's EC2 host. The agents apply the update via **pull-self** and restart their gateway.

When you enable **delegation**, a PM agent (the **orchestrator**) can hand work to **worker** agents through a durable **task ledger**, with a **wake pipeline** notifying the PM when a worker reaches a terminal state.

---

## Fleet

The top-level unit. A fleet has a name (e.g. `acme-bots`), one `fleet.yaml`, one Terraform [workspace](#workspace-disambiguation), and one set of AWS resources (VPC, EC2 hosts, IAM roles, S3 ledger bucket, DynamoDB tables, Secrets Manager paths).

`fleet.name` is the prefix on every AWS resource the fleet creates. Multiple fleets coexist in one AWS account via Terraform workspaces — see [MULTI-FLEET.md](./MULTI-FLEET.md).

## Agent

A single OpenClaw bot. Each agent has:

- An **id** (lowercase, e.g. `conductor`) — appears in SSM paths, systemd unit names, workspace directories
- A **persona** (name, emoji, role, soul)
- Its own **EC2 instance** (isolation > efficiency: a runaway skill on one agent can't starve another)
- Its own OpenClaw gateway
- Its own **Slack app** (bot token, app token, channels)
- Its own **workspace** (filesystem directory on the EC2)
- A **skill catalog** chosen in `fleet.yaml`

Throughout the codebase and docs, "agent" and "bot" are used interchangeably.

## Orchestrator vs. worker

Two roles, both implemented as agents:

- **Orchestrator** (`orchestrator: true`, conventionally one per fleet) — typically a PM bot. Receives tasks from humans, creates [task ledger](#task-ledger) entries, delegates to workers, and closes the loop. Has the `bot-delegation` skill.
- **Worker** — accepts delegations from the PM, ships work, posts results. Has the `bot-reception` skill. Workers can have a `delegation.specialty` (e.g. `frontend`, `backend`) used by the PM for routing.

Both PM and worker still talk to humans in Slack — "orchestrator" is just a config role, not a different runtime.

## Persona

Per-agent personality and identity, declared in `fleet.yaml`:

```yaml
persona:
  soul: |
    You are Conductor, a project-manager bot...
```

Rendered into `SOUL.md` in the agent's workspace. The persona shapes how the bot writes and behaves; the [skills](#skill) it has shape what it can *do*.

## Skill

A versioned capability that gives an agent a specific competence (e.g. `coding`, `github`, `bot-delegation`, `bot-reception`). Each skill is a directory containing `SKILL.md` plus optional scripts/templates. Skills come from two sources: bundled with fleetmind, or fleet-local under [`skills/`](../skills/README.md) in this repo. For source/version details and pinning semantics, see [ARCHITECTURE § Skill source and versioning](./ARCHITECTURE.md#skill-source-and-versioning).

## ContextStore

A DynamoDB-backed shared key/value store ("hive mind") accessible to every agent in a fleet, plus any external service with IAM access. Used for fleet-wide and per-agent state that needs to survive process restart. CLI: `fleetmind context get|set|delete|list`. For the keying scheme, scopes, and IAM model, see [ARCHITECTURE § ContextStore internals](./ARCHITECTURE.md#contextstore-internals).

## Task ledger

A durable record of work delegated from a PM to a worker. Backed by DynamoDB (structured state) plus S3 (narrative `.md` content). Used by the [delegation](#delegation) flow to track every task from creation to completion. For the schema, status enum, and conditional-write rules, see [ARCHITECTURE § Task ledger internals](./ARCHITECTURE.md#task-ledger-internals).

## Delegation

The PM-bot-to-worker-bot handoff. When `delegation.enabled: true` in `fleet.yaml`, the PM:

1. Creates a [task ledger](#task-ledger) entry
2. Posts a delegation envelope in a Slack channel mentioning the worker
3. The worker acknowledges and ships the work
4. The PM is notified via the [wake pipeline](./ARCHITECTURE.md#wake-pipeline) and closes the loop

For the lifecycle flags (`shipped-is-done` vs `requires-human-signoff`), wake pipeline wiring, and sweep resilience layer, see [ARCHITECTURE.md](./ARCHITECTURE.md). For setup: [integration/delegation.md](./integration/delegation.md).

## Workspace (disambiguation)

The word "workspace" means two different things:

1. **Agent workspace** — a filesystem directory on the agent's EC2 (`/opt/openclaw/workspace/<agent_id>/`). Source of truth for what OpenClaw runs: `AGENTS.md`, `SOUL.md`, `.openclaw/openclaw.json`, skills, plugins. Mutated by `fleetmind pull-self`.
2. **Terraform workspace** — Terraform's per-environment state isolation. One Terraform workspace per fleet. Created with `terraform workspace new <fleet-name>`.

These are unrelated concepts that happen to share a name. When in doubt, the context makes it clear (agent workspaces hold `.md` files; Terraform workspaces hold `.tfstate`).

## Render

`fleetmind render <fleet.yaml>` reads the fleet definition and writes per-agent `openclaw.json` slices plus derived Terraform variables. Nothing is pushed to EC2. Render is idempotent and safe to re-run — it's what `push fleet` does first under the hood.

## Push

`fleetmind push fleet [--restart]` is the main deploy command. It runs `render`, packages each agent's workspace into a tarball, uploads to S3, then triggers `fleetmind pull-self --apply` on each EC2 via SSM Run Command. With `--restart`, also restarts each agent's gateway after apply.

## Pull-self

`fleetmind pull-self [--apply] [--restart]` is the *bot-side* counterpart to `push`. It runs on the agent's EC2, downloads its tarball from S3, diffs against the live workspace, and (with `--apply`) atomically applies the changes.

You usually don't run `pull-self` directly: `push fleet` triggers it via SSM. But you can also run it manually (SSH/SSM session) when iterating on a single agent. One file gets special handling (`openclaw.json` three-way merge) — see [ARCHITECTURE § openclaw.json three-way merge](./ARCHITECTURE.md#openclawjson-three-way-merge).

## fleetmind vs. openclaw

Two related repos:

- **fleetmind** (this repo) — operator-side CLI + the per-agent workspace artifacts that ship in the package
- **openclaw** — the agent runtime: gateway, agent loop, Slack adapter, LLM plugins. Installed on each agent's EC2 by the bootstrap script.

`fleetmind` produces the inputs (`openclaw.json`, `AGENTS.md`, skills); `openclaw` reads them.
