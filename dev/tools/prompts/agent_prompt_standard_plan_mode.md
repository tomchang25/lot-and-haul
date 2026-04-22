# Agent Prompt Standard — Plan Mode

A lightweight template for writing prompts when using Claude Code's plan mode
(or ultra plan). The agent will read the codebase and propose a plan before
touching anything, so most context-gathering is its job, not yours.

Keep prompts short. Trust the plan review step to catch the rest.

## Global Must-Haves

Every prompt must include these constraints:

- Follow `dev/standards/naming_conventions.md`.
- Use 4-space indentation throughout.
- Commit: Write up to 100 words. Use the conventional commit format. For example: 'feat: add user authentication'. Only say necessary things — don't pad to reach the word limit or guess the reason for the edit.

## Template

### 1. Header — Standards & Conventions (focus)

One or two lines pointing to the coding standards doc(s) and indentation rule.
The two global must-haves above go here. Nothing else.

These are the things the agent cannot infer from reading the code — your
taste, your conventions. Always include.

### 2. Goal (focus)

Two to four sentences. The _what_ and _why_, not the _how_. Which feature,
which module/scene, and what outcome you want.

This frames the plan the agent will propose. Vague goal → vague plan → wasted
review cycle.

### 3. Behavior / Requirements (focus)

Bullets. No code. Describe _what should happen_, grouped by function or by
file if the change spans several.

Rule: if a one-sentence description would let the agent write it correctly,
one sentence is enough. Save code for the plan review, not the prompt.

If behavior depends on state × input, a small dispatch table is fine — often
clearer than prose.

### 4. Non-goals

A short list of what the agent must _not_ touch, change, or "improve while
it's in there". This is where plan mode benefits most from explicit guidance —
agents often propose adjacent refactors that you didn't ask for.

Examples: "do not modify the weight HUD", "rotation is not persisted across
scenes", "leave the save/load format alone".

### 5. Acceptance criteria

Observable outcomes. "Pressing E rotates the ghost preview 90° CW" — not
implementation assertions. Include obvious edge cases (reset, symmetry,
first-run paths).

## What you do NOT need to include

The agent will figure these out during planning and surface them for your
review. Pre-writing them is wasted effort:

- Which files/scenes are already wired
- Current state model or data shapes
- Type signatures of existing functions
- Dict/array structures already in the codebase
- Enum values already defined
- Implementation details, algorithms, signal wiring

Only include these if the agent genuinely can't discover them — e.g. an
external API, a magic string that appears nowhere else, or a convention
that isn't enforced by existing code.

## Minimum viable prompt checklist

1. Standards pointer + two global must-haves present?
2. Goal clear in 2–4 sentences?
3. Behavior described as bullets (no code)?
4. Non-goals listed?
5. Acceptance criteria observable?

If yes to all five, send it. The plan review will catch everything else.
