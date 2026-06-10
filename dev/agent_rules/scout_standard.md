# Scout Standard

Use this standard to produce a scout report — the raw, evidence-backed intelligence gathered from codebase exploration against a completed Plan.

A Scout Report is the input to an Implementation Spec. The scout agent's job is to **read and quote, not to conclude**. The spec author (a stronger model) performs the relational reasoning; the scout's value is reducing the spec author's exploration cost by pre-collecting verifiable facts.

**Assume the scout agent's conclusions cannot be trusted, but its quotations can.** A scout may misjudge ownership or misread intent, but a quoted signature with a file path is checkable in seconds. Therefore every claim in this report must carry a coordinate — a file path, a symbol name, or a quoted snippet. **A claim without a coordinate is not intelligence; it is noise, and it must be deleted before the report is filed.**

Use this for:

- Gathering codebase context for a Plan before spec generation.
- Mapping which existing systems a feature will touch, reuse, or conflict with.

Do not use this for:

- Designing the change — the scout proposes nothing.
- Writing or editing any code.
- Small changes where the spec author can explore directly at trivial cost.

---

## Filing

Pipeline position: Plan (`plan_standard.md`) → **Scout Report** → Implementation Spec (`implementation_spec_standard.md`) → implementation.

A scout report files as a sibling of the plan it serves: `dev/docs/plans/<plan>_scout.md`. It is the shortest-lived artifact in `dev/docs/` — it quotes code, so it rots faster than anything else there. Move it to `dev/docs/archived/` as soon as its Implementation Spec is generated; it never lingers beside an active plan as a competing source of truth.

---

## Output Structure

### 1. Mission

One or two sentences: which Plan this report serves, and the exploration boundary derived from it.

### 2. Systems Inventory

| File / System | Role in This Change                        | Evidence                                  |
| ------------- | ------------------------------------------ | ----------------------------------------- |
| `<path>`      | What it owns or does, relevant to the Plan | Symbol or line range that proves the role |

Every row must be a file the scout actually opened. Listing a file from its name alone is forbidden — open it or omit it.

### 3. Call Graph Observations

Flat bullet list. Each bullet states one relationship the scout directly observed:

- Who calls who, and whether the call reads or writes state.
- Where state is created, mutated, and consumed.

Format each bullet as: **claim — `path` `symbol` (quoted call site or signature)**.

Tag every bullet with a confidence marker:

- `[VERIFIED]` — the scout read the call site itself.
- `[INFERRED]` — deduced from naming, structure, or partial reading. Inferred bullets are the spec author's mandatory spot-check list, so under-tagging is worse than over-tagging.

### 4. Existing Contracts

Quoted, not paraphrased. The public signatures, data shapes, constants, and config surfaces the change will likely touch. Copy the actual declaration lines with their paths. Paraphrasing a signature defeats the report's purpose: a paraphrase inherits the scout's misreadings, a quotation does not.

### 5. Plan Friction

Flat bullet list. Every place where the codebase as found disagrees with what the Plan assumes — missing systems, renamed responsibilities, behavior already partially implemented, dead code that looks alive. Each bullet carries evidence like any other claim.

This section exists because friction the scout swallows silently becomes a wrong Relational Context bullet later. Omit the section only when there is genuinely no friction, and say so explicitly with one line: "No friction found between Plan and codebase."

### 6. Potential Issues

Numbered list. Risks and relationships the scout could not verify within the exploration boundary, stated as concerns the spec author must resolve. An honestly raised issue is worth more than a confident `[INFERRED]` guess.

---

## Rules

1. Write entirely in English.
2. Every claim carries a coordinate: path, symbol, or quoted snippet. No coordinate, no claim.
3. Quote signatures and contracts verbatim. Never paraphrase a declaration.
4. Tag every Call Graph bullet `[VERIFIED]` or `[INFERRED]`. When unsure which applies, use `[INFERRED]`.
5. Report observations, not designs. The scout never proposes how the change should be built, never drafts Relational Context conclusions, and never recommends an approach.
6. Scope by the Plan's blast radius. Do not inventory systems the Plan cannot plausibly touch.
7. Read before listing. A file that was not opened does not appear in the report.
8. Modify nothing. The scout is read-only.
9. Target under 800 words excluding quoted code. Exceed only when the blast radius genuinely requires it.

---

## Template

```md
# Scout Report: <Plan Title>

## Mission

<Which Plan, and the exploration boundary.>

## Systems Inventory

| File / System | Role in This Change | Evidence                 |
| ------------- | ------------------- | ------------------------ |
| `<path>`      | <role>              | `<symbol or line range>` |

## Call Graph Observations

- [VERIFIED] <claim> — `<path>` `<symbol>` (`<quoted call site>`)
- [INFERRED] <claim> — `<path>` (<basis for inference>)

## Existing Contracts

`<path>`:
```

<verbatim signature / declaration lines>

```

## Plan Friction

- <disagreement between Plan and code> — `<path>` (<evidence>)

## Potential Issues

1. <Unverified relationship or risk the spec author must resolve.>
```

---

## Example

````md
# Scout Report: Configurable Retry Policy for Outbound Requests

## Mission

Map the outbound request path and its error handling for the Retry Policy
Plan. Boundary: the outbound client, its callers, and error classification.

## Systems Inventory

| File / System               | Role in This Change              | Evidence                                         |
| --------------------------- | -------------------------------- | ------------------------------------------------ |
| `net/outbound_client.gd`    | Single outbound request path     | `func send(req: Request) -> Result`              |
| `net/errors.gd`             | Error type definitions           | `enum ErrKind { TIMEOUT, REFUSED, BAD_REQUEST }` |
| `game/sync/sync_service.gd` | Heaviest caller of outbound path | 3 call sites to `send()`                         |

## Call Graph Observations

- [VERIFIED] `sync_service.gd` calls `outbound_client.send()` and aborts the
  whole sync on first error — `game/sync/sync_service.gd`
  (`if result.is_err(): return result`)
- [VERIFIED] `outbound_client.send()` constructs `Result` with `ErrKind` but
  performs no classification beyond the enum — `net/outbound_client.gd`
- [INFERRED] `telemetry_service.gd` also calls `send()` — matched by grep,
  call site not read.

## Existing Contracts

`net/outbound_client.gd`:

```
func send(req: Request) -> Result
```

`net/errors.gd`:

```
enum ErrKind { TIMEOUT, REFUSED, BAD_REQUEST }
```

## Plan Friction

- The Plan assumes failures need transient/permanent classification to be
  introduced; `ErrKind` already separates `TIMEOUT`/`REFUSED` (plausibly
  transient) from `BAD_REQUEST` (permanent) — `net/errors.gd`. The spec
  author should decide whether to map onto this enum or add a new tag.

## Potential Issues

1. `telemetry_service.gd` may require fire-and-forget semantics; added retry
   latency on its path is an unverified risk.
2. No existing config surface for per-caller tuning was found; the policy may
   be introducing the first one.
````
