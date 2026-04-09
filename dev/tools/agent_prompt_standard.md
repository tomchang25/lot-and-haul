# Agent Prompt Standard

A template for writing prompts to coding agents. Keeps prompts requirement-focused
without drowning the agent in code.

## Global Must-Haves (every prompt)

Every agent prompt must include these two constraints, no exceptions:

- Follow `dev/docs/standards/naming_conventions.md`.
- Use 4-space indentation throughout.

Place them in the header or the constraints section — but they must appear.

## Template

### 1. Header — Standards & Conventions

One or two lines pointing to the coding standards doc(s) and indentation rule.
The two global must-haves above go here. Nothing else.

### 2. What to build

Two to four sentences. The *goal*, not the *how*. Answer: what feature, which
scene/module, why it matters.

### 3. Context

Only the facts the agent can't infer from the codebase alone:

- Which files/scenes are already wired vs. need work
- Current phase/state model if relevant
- What is explicitly *out of scope* (e.g. "rotation is not persisted",
  "extra slot does not affect weight HUD")

### 4. Key data relationships / API

This is where code *is* warranted. Include:

- Type signatures the agent will call (`CargoShapes.get_cells(id) -> Array[Vector2i]`)
- Data shape conventions (`Vector2i(col, row)`, normalised to origin)
- Dictionary/array structures the agent must read or write
- Enum values it must respect
- Ports, endpoints, or external APIs if the feature touches them

Keep it to signatures and one-line semantics. No implementations.

### 5. Behavior / Requirements

The meat of the prompt. Prefer one of these formats depending on scope:

- **Function list** — when adding several functions: name, signature, 3–6 bullets
  of logic. No full function bodies unless a subtle algorithm is involved.
- **Step-by-step by file** — when the change spans multiple files: group changes
  under each file, describe the edit in prose, show code *only* for non-obvious
  snippets (new state vars, tricky branches, signal wiring).
- **Dispatch table** — when behavior depends on state × input. Much clearer
  than prose.

Rule of thumb: if the agent could write the code correctly from a one-sentence
description, don't paste the code.

### 6. Constraints / Non-goals

Short list of things the agent must *not* touch, must *not* break, or must leave
at defaults. This prevents scope creep and regressions in adjacent systems.
Repeat the two global must-haves here if they weren't in the header.

### 7. Acceptance criteria

Observable outcomes, not implementation checks. "Pressing E rotates the ghost
preview 90° CW" — not "`_active_rotation` is incremented". Include edge cases
the agent should verify (reset behavior, symmetry cases, initial-population
paths, etc.).

## When to include code vs. not

| Include code                                          | Skip code                                           |
| ----------------------------------------------------- | --------------------------------------------------- |
| Non-obvious algorithm (e.g. rotation normalisation)   | Standard CRUD on a dictionary                       |
| Exact signal-wiring pattern the project uses          | Straightforward loops                               |
| New state variable declarations with intent comments  | Function bodies derivable from bullets              |
| Dispatch/match branches where keycodes/enums matter   | Boilerplate the agent already knows                 |
| Exact string keys/magic values (`"cargo"`, `"temp"`)  | Anything the signature + 3 bullets already implies  |

## Minimum viable prompt checklist

Before sending, the prompt should answer:

1. Where are the standards, and are the two global must-haves present?
2. What is the goal in plain English? (2–4 sentences)
3. What APIs / ports / endpoints does the agent need? (signatures only)
4. What should happen, broken down by function or by file? (bullets, not code)
5. What must it *not* touch? (constraints)
6. How will I know it works? (acceptance criteria)

If any of those six is missing, the agent will either ask or guess. If any of
them is padded with code the agent didn't need, the prompt is too long.
