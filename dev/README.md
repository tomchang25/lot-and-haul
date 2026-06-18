# dev/

This directory holds development-time instructions, standards, workflows, references, and tooling. When adding or moving a file under `dev/`, classify it by the primary thing it governs, not by who reads it.

## Placement Test

- `agent_rules/`: agent behavior and execution constraints. Use this for sandbox rules, git permissions, lint/test requirements, headless run procedures, approval rules, and habits an agent must follow while working.
- `workflows/`: development process artifacts. Use this for plan, implementation spec, sketch, closeout, stage-review, slash-command workflow files under `workflows/commands/`, and other rules for how work moves from idea to implementation.
- `standards/`: project output standards. Use this for rules that define what correct repo artifacts look like: code architecture, naming, scene structure, registries, themes, error guards, data conventions, change-summary tone, and project layout.
- `skills/`: concrete recipes and hazard cards for AI, Godot, GDScript, or tooling pitfalls. Use this for specific failure modes, compiler/import traps, API gotchas, repeatable fixes, commit/PR formatting references, and examples that prevent common wrong code.
- `docs/`: actual design, architecture, planning, and tracking documents. Use this for feature plans, system docs, vision docs, archived plans, and product/design content.
- `tools/`: executable development tooling and tool-owned prompts. Use this for scripts, validators, generators, hooks, and prompt packs used by those tools.

## Tie-Breakers

- If the file tells an agent what it may or must do while operating, use `agent_rules/`.
- If the file tells any contributor how to produce or advance a development artifact, use `workflows/`.
- If the file tells what the game, codebase, data, scenes, or docs should look like when correct, use `standards/`.
- If the file explains a specific trap and its fix, especially one an AI is likely to write wrong, use `skills/`.
- If the file is the actual content being designed, planned, or archived, use `docs/`.
- If the file is run by humans, CI, hooks, or agents as a command, use `tools/`.

## Common Misplacements

- Do not put a file in `standards/` only because its filename contains "standard". Workflow artifact formats belong in `workflows/`.
- Do not put a file in `agent_rules/` only because agents read it. Agents read all of `dev/`; `agent_rules/` is only for agent behavior and execution constraints.
- Do not put a file in `docs/` only because it is Markdown. `docs/` is for design and tracking content, not every prose reference.
- Do not put a project-wide rule in `skills/` just because it prevents a bad outcome. Use `skills/` when the value is a concrete recipe or hazard card; use `standards/` when the value is a durable repo convention.

## Reading Flow

`CLAUDE.md` carries a compact placement table so an agent can make the first classification without hunting for context. This file is the fuller reference for edge cases, tie-breakers, and examples.
