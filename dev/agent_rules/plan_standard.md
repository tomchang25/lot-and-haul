# Plan Standard

Use this standard to produce a durable, high-level feature plan — the stable design artifact for a feature.

A Plan defines **what** a feature is, **why** it exists, and **how it behaves**. It never specifies **where** (files) or **how it is wired** (functions, classes). A separate Implementation Spec — generated later from codebase exploration — turns a Plan into executable work. Keeping the Plan free of code coordinates is deliberate: it stays valid as the codebase changes, and it forces the spec stage to re-map the design onto the real code every time.

Use this for:

- Medium or large features before implementation.
- Architecture-level changes that need scope control.
- Any design whose intent is worth reviewing before code is touched.

Do not use this for small bug fixes, config changes, or narrow refactors — those go straight to a compact implementation note.

---

## Output Structure

### 1. Goal

One to three sentences. State the capability being added or changed, why it matters, and the gap or problem it addresses.

### 2. Requirements

Numbered list. Each item is a feature, constraint, or refactor described at the product or behavioral level.

When a requirement is non-obvious or counterintuitive, state the reason **inline** in the same line. Do not open a separate rationale section.

Typical length: three to six items.

### 3. Design (optional — expand to fit the feature)

This is where the actual design lives. A trivial feature may omit it; a complex mechanic, economy, or state system may have several subsections.

Permitted and encouraged:

- Mechanics, rules, and state transitions described in behavioral terms.
- Concrete numbers, formulas, thresholds, and tables.
- Worked examples that trace a mechanic step by step.

Forbidden: file paths, line numbers, function names, class names, or any other code-level coordinate. Refer to systems by their role or responsibility, not by symbol.

The cut line for this whole document is **"no code coordinates," not "no detail."** Carry as much design depth as the feature needs.

### 4. Non-Goals

Numbered list. Explicit exclusions that keep the implementation boundary tight. Omit this section only when the boundary is already obvious.

### 5. Acceptance Criteria

Numbered list. Observable, behavioral completion signals: outcomes, compatibility, preserved behavior, fallback behavior.

Avoid test names, file paths, and function names.

---

## Standards

- Write the plan entirely in English.
- Include no file paths, line numbers, code snippets, or names of functions/classes. Reference existing systems by role, not by symbol.
- Carry full design depth — numbers, formulas, tables, worked examples are all in scope. The boundary is code coordinates, not detail.
- State the **why inline** wherever a decision is non-obvious. Never open a standalone rationale section; fold the reason into the Requirement or Design line it justifies.
- Do not mix future phases into the current feature boundary.

---

## Template

```md
# <Title>

## Goal

<One to three sentences: capability, reason, gap.>

## Requirements

1. <Requirement at product/behavioral level. State the why inline if non-obvious.>
2. <Requirement at product/behavioral level.>
3. <Requirement at product/behavioral level.>

## Design

<Optional. Mechanics, numbers, formulas, tables, worked examples.
No file paths or function/class names. Refer to systems by role.>

## Non-Goals

1. <Explicit exclusion.>
2. <Explicit exclusion.>

## Acceptance Criteria

1. <Observable completion criterion.>
2. <Compatibility or preserved-behavior criterion.>
3. <Fallback, edge-case, or user-visible criterion.>
```

---

## Example

````md
# Configurable Retry Policy for Outbound Requests

## Goal

Add a configurable retry policy for outbound requests so transient failures recover automatically instead of failing the whole operation. Today every outbound call aborts on its first error, which makes the system fragile to brief network blips.

## Requirements

1. Support a bounded retry with backoff for outbound requests, defaulting to no retry so existing behavior is preserved unless a caller opts in.
2. Make max attempts and backoff base configurable — different callers tolerate different latency budgets.
3. Classify failures so only transient ones retry; permanent failures fail fast, because retrying a non-retryable error only wastes the latency budget.

## Design

Retry wraps the existing outbound path; it does not change the request itself.

- Attempt budget: 1 initial attempt + up to N retries. Default N = 0 (off).
- Backoff: delay before retry k = base × 2^(k-1), capped at a ceiling.
- Only failures tagged transient consume a retry; a permanent failure aborts immediately and surfaces the original error.

Worked example (N = 3, base = 100 ms, ceiling = 2 s):

```

attempt 1 → transient fail → wait 100 ms
attempt 2 → transient fail → wait 200 ms
attempt 3 → transient fail → wait 400 ms
attempt 4 → success (or final failure surfaced)

```

A permanent failure at any attempt skips the remaining budget and returns at once.

## Non-Goals

1. Do not add a circuit breaker or failure-rate tripping.
2. Do not change the outbound request shape or payload.
3. Do not add per-endpoint policy overrides — a single configurable policy is enough for now.

## Acceptance Criteria

1. With retry off (the default), behavior is identical to today.
2. A transient failure under a non-zero policy recovers without surfacing an error, within the configured attempt budget.
3. A permanent failure aborts on the first attempt regardless of policy, surfacing the original error.
````
