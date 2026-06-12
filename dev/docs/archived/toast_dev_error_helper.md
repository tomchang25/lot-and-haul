# Toast Dev-Error Helper

## Goal

Add a one-call developer-error helper to the toast notification system so a programmer-error guard is a single call instead of the current three-line pattern (log + debug gate + toast). The manual pattern is easy to get wrong — forgetting the debug gate leaks internal messages to players — and offers no protection against toast spam from guards that fire every frame.

## Requirements

1. The toast system gains a dev-error helper (decided name: `show_dev_error`) that performs the full programmer-error pattern in one call: always writes the message to the error log (so it reaches release logs), and shows the red error toast only when the debug gate is enabled — players never see internal detail.
2. The helper dedupes toasts fire-once per session: a given message string toasts at most once, because a guard sitting in a per-frame or loop path would otherwise flood the screen. Every occurrence still reaches the error log, since the log is greppable and is where repetition is useful.
3. The error guard standard is updated to mandate the helper for all new programmer-error guards once the helper ships, replacing the manual gated pattern as the documented norm.
4. Existing call sites that hand-roll the gated pattern are migrated to the helper in a dedicated sweep phase. New code is governed by the standard from day one; the sweep is scheduled work, not a blocking precondition.

## Design

The helper belongs on the toast system because the gate-and-toast decision is presentation policy, not debug policy — the debug autoload stays free of toast dependencies.

Dedupe model: an in-memory set of already-toasted message strings, cleared only on process restart. No cooldown timer — a programmer error is a bug signal, and one toast per session per message is enough to notice it during playtesting.

The save/load diagnostics channel is out of scope: it already has its own push-model (collected during load, drained once at the end) and routes through the warning and info channels, not the error channel.

## Phases

1. **Helper** — implement the dev-error helper with session fire-once dedupe; update the error guard standard's programmer-error pattern to mandate it.
2. **Migration sweep** — codebase-wide scan for hand-rolled gated-toast guard sites (debug-gated error toasts paired with error logging); migrate each to the helper. Requires a full-codebase search pass — schedule on a model tier where that is acceptable.

## Non-Goals

1. No change to the warning or info toast channels, their visibility rules, or the save/load diagnostics flow.
2. No change to runtime guards — player-facing error toasts remain direct, ungated calls.
3. No cooldown/timer-based re-toast logic — fire-once per session is the whole dedupe model.

## Acceptance Criteria

1. A programmer-error guard is expressible as one call; the message appears in the error log in all build configurations and on screen only in debug mode.
2. A guard firing every frame produces exactly one toast per session while continuing to log.
3. After the sweep phase, no hand-rolled debug-gated error-toast pattern remains at guard sites; the standard documents only the helper pattern.
