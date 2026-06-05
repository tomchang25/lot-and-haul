# Systems Docs L2 Audit

Goal: apply the sharpened L2 exclusion rule (`dev/docs/README.md` → systems/) to every current `systems/` doc, lifting concept definitions up to `vision/`, pushing per-file detail down to code docstrings (L3), and leaving `systems/` holding only cross-flow facts. Net effect we expect: `systems/` shrinks substantially and stops attracting duplication.

Context / why now: L2 has been the rot source — concept definitions and per-file `Reads`/`Writes`/`Ownership` lists drift here and go stale (e.g. `data_model.md` once mirrored every exported field). The README now states membership by exclusion; this plan operationalises it against the current 10 files.

## The rule being applied

A fact stays in `systems/` only if **both**: (1) no single file is its home, and (2) it's too volatile for `vision/`. Otherwise it routes:

- concept definition / layer responsibility boundary → **L1 `vision/`**
- which class is which / fields / file paths / signatures → **L3 code docstrings** (or just deleted — code is the source)
- cross-scene flow + cross-cutting invariant → **stays L2**

## Preliminary per-doc verdict

First-pass read of headers only — each verdict is confirmed against the full file in Phase 1 before any cut. "Lift" = move to vision, "Drop" = push to docstrings/delete, "Keep" = true L2 residue.

| Doc | Lift to L1 (concept) | Drop to L3 (per-file detail) | Keep as L2 (cross-flow) | Net |
| --- | --- | --- | --- | --- |
| `data_model.md` | The two-layer concept: designer-resource (authored, immutable) vs runtime-type (per-instance, saved) — this is foundational, whole-project | per-resource field notes already mostly gone; verify none remain | the ownership chain `SuperCategory ← Category ← Item → Clue` (cross-type relationship) | heavy lift — likely becomes a vision artifact + a thin L2 stub |
| `item_system.md` | "two-layer architecture" overlaps `data_model` — dedupe; the concept goes to vision once | "old `ItemViewContext` removed" is history, not present — trim | item lifecycle flow (draw → inspect → research → sell) | merge concept with data_model; keep lifecycle |
| `autoloads.md` | — | the autoload roster table (file → role) is readable from `project.godot` + class names | boot orchestration invariant (RegistryCoordinator drives migrate/validate; load order matters) | big drop — table out, keep the boot-sequence invariant |
| `item_display.md` | — | component method/architecture detail — it's one folder (`game/shared/item_display/`), so it's L3 | the cross-cutting invariant: every visible value is a getter on `ItemEntry`, no `ItemViewContext`, columns driven by caller | mostly drops to docstrings; keep the invariant |
| `customer_sell.md` | — | the `Ownership` section (file paths: Customer, SellMath, MetaManager, scene) | the flow (arrive → pack → conservative/aggressive), "only selling path" invariant, tags = clue ids | trim ownership; keep flow + invariants |
| `meta/hub_home.md` | — | `Reads` / `Writes` lists (SaveManager fields) | hub navigation flow + slot-tray entry points | trim Reads/Writes; keep flow |
| `meta/knowledge.md` | maybe: three-axis progression (mastery / attributes / perks don't substitute) reads vision-ish — decide in Phase 1 | `Reads` / `Writes` lists | how the three axes are earned/spent across scenes | trim Reads/Writes; keep flow |
| `meta/vehicle.md` | — | `Reads` / `Writes` lists | thin — cross-run investment flow, garage buy/select | trim to flow; may be the thinnest survivor |
| `day_slot_economy.md` | — | none obvious — already concept-level | slot day structure, AP pools, MetaManager-as-authority, day-end sequence — textbook cross-flow | keep nearly whole |
| `lot_auction_run.md` | — | none obvious | the full scene-flow diagram spanning location→browse→inspect→auction→reveal→cargo→review | keep nearly whole — canonical L2 |

Pattern: `day_slot_economy` and `lot_auction_run` are pure cross-flow and survive intact. `data_model` + `item_system` carry the concept-definition that should be lifted to vision (and they duplicate each other). Everything else is mostly `Reads`/`Writes`/`Ownership`/roster tables that drop to L3.

## Phases

Phase 1 — Confirm verdicts (read-only). Full-read all 10 docs; for each, mark every section as Lift / Drop / Keep against the rule. Produce the real lift/drop/keep ratio. Decision gate: if the cross-flow residue is only 2–3 files' worth, fold survivors into existing docs and consider whether `systems/` should stay a folder at all (vs. inlining cross-flow into orchestrator file headers). This phase's output replaces the preliminary table above.

Phase 2 — Lift concepts to L1. Resolve the `data_model` ↔ `item_system` two-layer duplication into a single vision artifact (designer-resource vs runtime-type, layer responsibilities). Respect the vision ≤5-artifact cap — if this would be the 6th, it merges into an existing vision doc rather than adding one.

Phase 3 — Drop per-file detail to L3. For each Drop item, confirm the fact already lives in the relevant `.gd` file header / GDDoc; add it where missing; then delete the enumeration from the system doc. Targets: `autoloads` roster table, all `Reads`/`Writes` lists, `customer_sell` Ownership, `item_display` component detail.

Phase 4 — Trim survivors to cross-flow only. Rewrite the kept docs so each contains only flow + cross-cutting invariants, present tense. Update cross-references.

Phase 5 — Verify no fact lost. Diff each removed block against its new home (vision artifact or docstring); confirm every lifted/dropped fact landed somewhere. Re-read `dev/docs/README.md` rules and check each surviving doc passes the exclusion test (renaming a function must not make it wrong).

## Acceptance criteria

- Every `systems/` doc passes the exclusion test: no concept definition (→ vision), no per-file `Reads`/`Writes`/`Ownership`/roster/signatures (→ L3).
- The `data_model` ↔ `item_system` two-layer concept exists in exactly one place (vision), not two.
- No fact silently deleted — each lifted/dropped item is traceable to its new L1 or L3 home.
- Phase 1's measured ratio is recorded so the "does `systems/` survive as a folder" question is answered with data, not a guess.
