# skills/

Skills directory for this fleet.

Referenced by `fleet.yaml` (`skills_repo.local: ./skills`) and consumed by the agent runtime at start time.

## What goes here

- *Fleet-specific skills* — custom skills written for this fleet's bots (e.g. domain-specific workflows, internal API wrappers).
- *Skill overrides* — local copies of upstream skills with operator-specific customizations.

Skills bundled with Fleetmind (e.g. `bot-delegation`, `bot-reception`) are pulled from the `fleetmind` npm package automatically — you don't need to copy them here. Only put a skill here if you're authoring it or overriding the bundled version.

## Layout

Each skill is its own subdirectory containing a `SKILL.md` and any supporting files:

```
skills/
├── README.md                       # this file
├── my-custom-skill/
│   ├── SKILL.md
│   └── references/
│       └── runbook.md
└── another-skill/
    └── SKILL.md
```

See the [Fleetmind skills docs](https://github.com/Continuous-Agentics/fleetmind) for the skill manifest format.
