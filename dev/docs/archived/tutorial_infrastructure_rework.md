# Tutorial Infrastructure Rework

## Goal

Lift the tutorial system from a static, Next-only, single-scene hint tour into a presentation/flow split that can drive an interactive onboarding spanning multiple scenes and waiting on real gameplay actions, without the presentation layer accumulating flow state. The current system renders hints and popups within one registered scene but cannot express "wait until the player wins an auction" or "advance when cargo is loaded," which an interactive onboarding requires.

## Requirements

1. Split tutorial responsibilities into two layers that the current single presentation controller conflates: a presentation layer (overlay, highlight, hint/popup rendering, panel placement — unchanged in scope) and a flow layer (which tutorial is active, current step, what the step is waiting on, cross-scene continuity). The presentation layer must not own flow state, because mixing render and orchestration is what makes the current system unextendable.
2. Introduce an event-based advance condition alongside the existing Next and scene-entered conditions, so a step can complete when a semantic gameplay event fires. Onboarding is interactive by nature and cannot be driven by Next alone.
3. Gameplay systems emit a small, named set of semantic tutorial events; the flow layer subscribes and advances. Gameplay must not know tutorial copy or step order — it only emits the event, keeping the dependency one-directional.
4. Tutorial content continues to live in a single catalog surface (script ids, steps, anchor ids, advance conditions) so adding a tutorial does not require editing the presentation layer, preserving the boundary the earlier script-registry rework established.
5. Existing hub and storage tutorials continue to resolve and play through the new flow surface with no player-visible behavior change, so the rework is a migration of one system, not a parallel second system.
6. Transient anchor surfaces that are not scenes — most immediately the activity chooser popup from Plan A — must be registerable and unregisterable as tutorial anchors on open and close, because onboarding needs to point at a chooser option that only exists while the popup is open.
7. The flow layer survives scene transitions: an onboarding that spans the run scenes keeps its current step and waiting state across scene changes, unlike the current per-scene register-and-trigger model where each scene independently starts a tutorial.

## Design

### Step advance kinds

| Kind         | Completes when                        |
| ------------ | ------------------------------------- |
| Next         | the player clicks the advance control |
| SceneEntered | a new scene registers its anchors     |
| Event        | a named semantic gameplay event fires |

A step carries its wait condition; the flow layer evaluates it on each advance opportunity.

### Flow layer state

The flow layer owns: the active tutorial id, the current step index, the current wait condition, and a cross-scene continuity flag. On scene register, it decides whether to continue an active onboarding (continue path) or trigger a standalone tutorial (the current hub/storage behavior, unchanged). The presentation layer is told only "render this step"; it is never told about future steps or wait conditions.

### Semantic event set (starting)

`location_selected`, `lot_selected`, `inspection_performed`, `auction_won`, `cargo_loaded`, `run_reviewed`, `sale_completed`, `activity_chosen`. These are gameplay milestones, not UI clicks. Gameplay emits; the flow layer listens. The set is intentionally small and additive — new onboarding needs add an event here, not a new coupling to the presentation layer.

### Chooser anchor lifecycle

The activity chooser popup (Plan A) registers its option anchors when opened and unregisters them when closed (cancel or confirm). A flow-layer step waiting on `activity_chosen` resolves against whichever chooser is open. This keeps popup-internal anchors out of the persistent per-scene anchor set and makes a closed chooser resolve to "anchor unavailable" rather than a stale reference.

### Migration of existing tutorials

The existing hub and storage tutorials move onto the catalog + flow surface with their steps keeping Next/SceneEntered advance (no event dependency), so they remain static tours. The presentation layer's public render API stays stable so existing harnesses and screenshot tooling need no broad rewrite.

## Non-Goals

1. No branching or conditional tutorial logic, and no story scripting.
2. No external resource format for tutorial content yet — the catalog may stay code-authored.
3. No localization of tutorial copy.
4. No previous-step (back) navigation.
5. No onboarding content itself — that is Plan C. This plan delivers the machinery only.

## Acceptance Criteria

1. The presentation layer renders hints, popups, and highlights and performs panel placement, but holds no step-order or wait-condition state; all flow state lives in the flow layer.
2. A step with an event advance condition completes when the corresponding gameplay event fires, and does not complete otherwise.
3. Gameplay systems emit the named semantic events; no gameplay system references tutorial copy or step order.
4. Existing hub and storage tutorials play identically to today through the new surface.
5. An anchor exposed only by a transient popup (the chooser) can be targeted by a tutorial step while the popup is open and safely resolves or skips when the popup is closed.
6. A tutorial whose steps span multiple scenes retains its step index and wait state across scene transitions, and reattaches correctly when the next scene registers.
