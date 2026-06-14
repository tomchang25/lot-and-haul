# Sketch Standard

Use this standard to produce a sketch — the single document for a small feature, replacing both the Plan and the Implementation Spec stages.

A Sketch carries everything a small feature needs in one pass: behavioral requirements at Plan depth, plus a **non-normative implementation sketch** — pseudo-code, proposed names, and migration steps written down from the design conversation. Its defining contract is the verification level of code references, which is what separates the three document types:

| Document | Code references | Verification contract |
| --- | --- | --- |
| Plan | forbidden | none needed — durable by construction |
| Sketch | allowed | **non-normative** — intent only, implementer verifies on contact |
| Spec | required | normative — every claim carries a codebase-verified coordinate |

The non-normative marker is what makes code in a sketch safe: a stale snippet in a plan would be mistaken for truth, but a sketch declares up front that names and snippets are illustrative and the codebase wins every disagreement. This also removes the spec's retrieval obligation — the author writes what the design conversation already settled and is **not** required to explore the codebase; light spot-checks are fine, exhaustive evidence-gathering is the signal you should be writing a spec instead.

Use this for:

- Small features whose design was fully settled in the planning conversation.
- Changes confined to one system, or with a blast radius the author already understands without exploration.
- Work where a Plan's only purpose would be to be transcribed into a spec immediately.

Do not use this for:

- Changes with non-obvious cross-system ownership or call-direction questions — those need a Spec's Relational Context, written from codebase evidence.
- Designs worth keeping after shipping (mechanics, economy, invariants) — those need a Plan that survives refactors.
- Anything still carrying an unresolved design decision — same rule as Plans: ask during the conversation; a sketch never contains open questions.

A rough litmus test for "small": if the Plan's Design section would be shorter than the Spec's Implementation Notes, skip both and write a sketch.

---

## Output Structure

Sections 1–3 and 5–6 follow the Plan Standard's rules exactly (behavioral level, no code coordinates, why stated inline). Only section 4 may contain code.

### 1. Goal

One to three sentences: capability, reason, gap.

### 2. Requirements

Numbered list at the product/behavioral level, why stated inline when non-obvious.

### 3. Design (optional)

Behavioral design: mechanics, numbers, tables, worked examples. Same cut line as a Plan — no code coordinates here; they belong one section down, behind the non-normative marker.

### 4. Sketch (non-normative)

The section that defines this document type. Pseudo-code, proposed class/file/function names, data-shape examples, and an ordered migration/step list. Everything here is a proposal, not a claim about the codebase:

- Names are suggestions; the implementer renames freely to match conventions on the ground.
- Snippets express intent and shape; they are not expected to compile or to match real signatures.
- References to existing code are **recalled, not verified** — when the codebase disagrees, the codebase wins silently, with no doc update required.
- Anything the author does not know is left out, not guessed — the implementer resolves it on contact. An omission in a sketch is normal, not a defect.

### 5. Non-Goals (optional)

Numbered exclusions, when the boundary is not obvious.

### 6. Acceptance Criteria

Numbered, observable, behavioral. No file paths or function names — criteria outlive the sketch's proposed naming.

---

## Rules

1. Write entirely in English.
2. The Sketch section heading must carry the literal marker `(non-normative)` — the marker is the contract that makes code in this document safe.
3. Code and code coordinates appear **only** inside the Sketch section. The rest of the document obeys the Plan Standard's no-code-coordinates rule, so if the feature later grows, the Sketch section can be cut and the remainder is a valid Plan.
4. No retrieval obligation, and no retrieval theater: do not pad the Sketch with coordinates or quoted declarations to look spec-like. If the change genuinely needs verified coordinates to be implementable, stop and write a Plan + Spec.
5. No open questions — unresolved decisions are resolved in the planning conversation before the sketch is written, same as Plans and Specs.
6. Do not hard-wrap prose lines at a column boundary — let the client handle line wrapping. Tables and code blocks are exempt.

---

## Lifecycle

- File name: `dev/docs/plans/<scope>_<short_description>.sketch.md`, with the usual one-line pointer in `TODO.md` (`## Plan` queued, `## Active` building).
- Implementation goes straight from the sketch — there is no spec stage and no separate scout stage.
- Shipped → `CHANGELOG.md` entry, archive the sketch, delete the TODO line — same as a plan. Sketches are disposable by design; only if a durable cross-flow invariant emerged does a one-paragraph conclusion graduate to `systems/` first.

---

## Template

```md
# <Title>

## Goal

<One to three sentences: capability, reason, gap.>

## Requirements

1. <Requirement at product/behavioral level. Why inline if non-obvious.>
2. <Requirement at product/behavioral level.>

## Design

<Optional. Behavioral design only — no code coordinates.>

## Sketch (non-normative)

<Pseudo-code, proposed names, data shapes, migration steps. All illustrative — the codebase wins every disagreement.>

## Non-Goals

1. <Explicit exclusion.>

## Acceptance Criteria

1. <Observable outcome.>
2. <Observable outcome.>
```
