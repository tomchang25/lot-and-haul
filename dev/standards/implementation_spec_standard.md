# Implementation Spec Standard

Use this standard to produce an implementation spec from a completed Plan and codebase exploration.

This document gives an implementation agent enough context to execute a change without its own plan-mode phase. Its primary value is the **Relational Context** section, which pre-computes cross-system ownership, call direction, and integration constraints so the implementation agent does not have to reason about them independently.

**Assume the executing agent cannot reliably infer cross-system relationships.** It can translate clear instructions into correct code, but it does not deduce who owns what or who calls who. Every relationship the change depends on must be stated; an omitted relationship will be invented, and the executing agent will not notice it was wrong. The spec, plus the reviewer who approves it, is the only quality gate before code is written.

Use this for:

- Medium or large changes that touch multiple systems with non-obvious ownership boundaries.
- Work where the implementation agent is likely to invent incorrect cross-system interfaces.
- Cases where you want to skip the implementation agent's plan-mode phase entirely.

Do not use this for:

- Small bounded changes with no meaningful cross-system interaction — use a compact implementation note.
- Work where you want the agent to discover and propose the approach itself — use a plan-mode prompt instead.
- Changes that need step-by-step, per-file instruction — use a full per-file plan instead.

Generating this document requires codebase exploration. Read the relevant files before filling Relational Context and Files to Change. Do not generate it from the Plan alone.

---

## Output Structure

### 1. Goal

One to three sentences, taken from the Plan and condensed if needed. State what capability is being added or changed, and why. Add no implementation detail here.

### 2. Relational Context

A flat bullet list. No subsections.

Write the constraints and decisions an implementation agent would get wrong without being told. Include whichever of the following apply:

- **Call direction** between touched systems — who calls who, and whether it is a read or a write.
- **Ownership rules** — which system is the single authority for a piece of state.
- **Changed integration contracts** — before → after for any cross-system interface this change modifies.
- **Wrong shapes to avoid** — describe the incorrect coupling pattern in terms of system responsibility, not function names.

**Completeness rule (load-bearing):** Every system relationship that a Files-to-Change entry participates in must appear here — even one that would be "obvious" to a strong reader. The executing agent does not infer, so an unstated relationship is an unspecified one. The boundary that keeps this from becoming noise is **blast radius**, not obviousness: document every relationship the change touches; do not document relationships elsewhere in the codebase that the change does not interact with.

Do not create subheadings. Do not force entries for categories that do not apply. A simple change may have two bullets within its blast radius; a complex one may have eight or more.

### 3. Scope

#### Included

Short bullet list of what this spec covers.

#### Excluded

Short bullet list of what is intentionally out of scope. Keep it tight to prevent scope bleed during implementation.

### 4. Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `<file>` | Small / Medium / Large | What this file is responsible for in this change |

Identifies ownership and change effort. Does not prescribe line-by-line edits.

### 5. Implementation Notes

Write only the decisions and constraints the implementation agent is likely to get wrong.

Organize by file or system when grouping helps. Use bullets or short paragraphs.

Do not write step-by-step instructions. Do not reproduce logic the agent can read from the codebase. Include pseudocode only for non-obvious branching logic or state transitions.

### 6. Edge Cases

| Case | Expected Handling |
| --- | --- |
| `<case>` | `<expected behavior>` |

Omit this section if no meaningful edge cases exist.

### 7. Acceptance Criteria

Numbered list of observable outcomes, at the same level as the Plan's acceptance criteria.

Do not include file paths or function names.

---

## Rules

1. Write entirely in English.
2. Requires codebase exploration before generating. Do not fill Relational Context or Files to Change from the Plan alone.
3. Relational Context is a flat list. Do not add subsections.
4. Apply the completeness rule: every cross-system relationship within the change's blast radius is stated, even the obvious ones — the executing agent does not infer. Relationships outside the blast radius stay undocumented.
5. Implementation Notes should be shorter than a full per-file plan. If you are writing step-by-step per-file instructions, switch to a full per-file plan.
6. Do not include implementation detail the agent can discover from the codebase, except where the completeness rule requires stating a relationship explicitly.
7. Do not mix future scope into this spec.
8. Target under 600 words. Exceed only when relational complexity genuinely requires it.

---

## Template

```md
# <Title>

## Goal

<One to three sentences from the Plan.>

## Relational Context

- <Call direction, ownership rule, changed contract, or wrong shape to avoid.>
- <Every relationship within the change's blast radius — including the obvious ones.>

## Scope

### Included

- <Included change>

### Excluded

- <Excluded change>

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `<file>` | Small / Medium / Large | <Purpose> |

## Implementation Notes

<Organized by file or system. Bullets or short paragraphs. Pseudocode only when branching is non-obvious.>

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| `<case>` | `<expected behavior>` |

## Acceptance Criteria

1. <Observable outcome.>
2. <Observable outcome.>
```
