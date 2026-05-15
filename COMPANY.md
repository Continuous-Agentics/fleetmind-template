# COMPANY.md — `<Your Company Name>`

> **Fill this out before your first deploy.**
>
> This file is copied to every agent's workspace at `fleetmind render` time, so each
> bot in the fleet starts every session with the same baseline knowledge about your
> company. Bots read it after `SOUL.md` and `TOOLS.md` during session boot.
>
> Keep it ~500 lines or less. Bots have finite context windows; this is shared
> background, not an encyclopedia. Link to deeper internal docs where appropriate.

---

<!-- AUTO SECTION -->
## Mission

<One paragraph: what your company does, who it serves, what success looks like.>

<!-- AUTO SECTION -->
## Products / Services

<One line per product or service. Include internal codenames operators or external names customers know.>

- `<Product 1>` — <one-line description>
- `<Product 2>` — <one-line description>

<!-- AUTO SECTION -->
## Team & Structure

<How teams are organized. Not a directory — high-level roles and how work flows.>

- *Engineering*: <team names + what they own>
- *Product*: <team names + what they own>
- *<Other functions as relevant>*: <...>

<!-- AUTO SECTION -->
## Terminology / Jargon

<Acronyms, internal codenames, things only insiders would know. Save bots from asking 'what does X mean?' in every conversation.>

| Term | Means |
|---|---|
| `ACME` | <expansion> |
| `<jargon>` | <expansion> |

<!-- AUTO SECTION -->
## How We Work

<Engineering norms bots should follow when contributing.>

- *Deploy cadence*: <e.g. continuous, weekly, on-demand>
- *PR review*: <required reviewers? min approvals? CODEOWNERS?>
- *Branch naming*: <convention>
- *Commit conventions*: <e.g. Conventional Commits, custom format>
- *Testing*: <expectations for new code>
- *On-call / incident response*: <who responds, escalation path>

<!-- AUTO SECTION -->
## Out of Scope

<What bots should NOT do or speak to. Hard boundaries.>

- *Financial commitments* — bots don't sign contracts, quote prices, or commit budget
- *HR matters* — bots don't discuss personnel issues, hiring decisions, compensation
- *Legal review* — bots don't make legal interpretations or approve language requiring counsel
- *<Add your own>*: <...>

<!-- AUTO SECTION -->
## Contact

- *On-call*: <Slack channel, PagerDuty, etc.>
- *Engineering leadership*: <how to reach for escalations>
- *<Other channels as relevant>*: <...>

---

*Last reviewed: <YYYY-MM-DD>*
