# Headless Run-Loop Test Suite

## Goal

Add an automated test suite that exercises the full run-phase loop (inspect → auction → cargo → hub resolution) under Godot headless, with results reported to CI on every push. Currently there is no automated coverage of the run loop, so runtime regressions in manager logic are caught only by manual play.

## Requirements

1. The run-phase manager layer must be exercisable in headless mode without instantiating any scene — tests call manager methods directly on constructed fixtures. This keeps test speed high and decouples correctness from UI state.
2. All random draws that participate in run-loop entry construction must accept a seedable RNG so test outcomes are deterministic and reproducible. Several entry constructors and the item generator currently use global random calls; those must migrate to an injectable RNG. The customer entry already uses this pattern correctly; the item entry, lot entry, and item generator must follow.
3. A GUT-based unit test suite covers the critical run-loop manager invariants: AP lifecycle, clue discovery hit/miss, cargo commit, and a full scratch-to-hub traversal.
4. A log-grep smoke test complements the unit suite: the game boots headless, auto-pilots one full run via a CI-only pilot script, and CI fails the build on any error-level log line. This layer catches wiring bugs — null dereferences, missing signal connections, bad scene-routing calls — that the unit layer cannot reach.
5. A GitHub Actions workflow runs both layers on every push to `main` and every pull request. The workflow only imports and tests; it does not produce an export binary.

## Design

### RNG injection

The global random calls inside the item entry factory, lot entry factory, and item generator service each gain an optional injectable RNG parameter (defaulting to null). When null, the function falls back to the equivalent global call, leaving all production call sites unchanged. Tests pass a freshly seeded RNG; production code passes nothing. The customer entry factory is the model for this pattern.

Each test case seeds its RNG before constructing fixtures — seed 0 for a baseline happy-path fixture, seed 1 for an edge-case fixture, and so on. This pinning makes a failing test exactly reproducible on any machine.

### Test layers

**Layer 1 — Manager unit tests (GUT)**

Each test constructs all required designer resources from scratch — item definitions, clue definitions, lot definitions, location definitions, car definitions — with field values set directly rather than loaded from disk. Autoloads still initialize when the test runner boots — that cannot be avoided in-engine — so a dedicated test command-line flag makes the boot orchestrator skip save loading, save validation, and initial scene routing. This keeps unit tests free of save-state side effects, while from-scratch resource construction keeps each case in the millisecond range.

Test cases cover:

- AP lifecycle: create a run → spend AP → confirm the remainder is correct; verify over-spend is rejected.
- Clue attempt: inject an attribute bonus and a known DC; verify the revealed clue set grows on a seeded hit and stays stable on a seeded miss.
- Cargo commit: commit a lot win → verify the cargo list and the economics debit are consistent.
- Trailer damage: seed a roll that triggers damage; verify the item count delta matches the damage output.
- Full run traversal: create a run with a seeded RNG → inspect items → win an auction → fill cargo → build the run result → resolve into the hub → confirm the hub economy delta.

**Layer 2 — Smoke test (headless boot + log grep)**

A CI-only pilot script activates only when a dedicated command-line flag is present, making it invisible in production builds. On startup it waits for all autoloads to finish initializing, then auto-pilots one full run: new-game init → create a run → inspect all surface clues on one lot → win the auction → fill cargo → resolve the run → end the day → exit with code 0. The pilot must not assume the auction is winnable at the floor price — rival bidding is non-deterministic — so it either raises its bid within a bounded budget or wins through a debug-only force-win hook; a run that cannot complete exits non-zero on its own rather than relying on the log grep to notice.

The CI step then checks the combined output for error-level log lines and fails the build if any are found. The grep matches a defined set of engine error patterns (script errors, engine errors, user-raised errors) filtered through an allowlist of known-benign lines — headless CI environments routinely emit harmless error lines for missing audio and display devices, and those must not fail the build. The global notification system already routes its error channel through engine error logging, so errors surfaced as toasts are caught by the same grep. The whole run is wrapped in a watchdog timeout: a hung pilot fails the build instead of stalling the job. This layer is intentionally non-deterministic; its role is coverage of wiring, not value correctness.

### GitHub Actions workflow

Two jobs run in parallel:

**Job 1 — unit tests**: install the Godot headless binary, import the project to populate the resource cache, run the GUT command-line runner against the tests directory, exit non-zero on any failure.

**Job 2 — smoke test**: install the Godot headless binary, import the project, launch the game with the CI flag, capture combined stdout and stderr, grep for error patterns, exit non-zero on any match.

Both jobs cache the Godot binary by version hash to avoid redundant downloads. The `data/tres/` generated files must be present before both jobs run; until the build-automation draft lands, they are regenerated by running the YAML pipeline as the first CI step, with the Python version and dependencies pinned so the pipeline output is reproducible.

### Phases

1. RNG injection refactor (item entry, lot entry, item generator)
2. GUT installation, the test-flag boot gate, and Layer 1 manager tests
3. CI pilot autoload and Layer 2 smoke test
4. GitHub Actions workflow

## Non-Goals

1. Do not test scene rendering, visual layout, or shader output — headless provides no GPU.
2. Do not add a platform export or binary packaging step to CI at this stage.
3. Do not cover tutorial, weekly-order, or other non-run-loop flows — scope to the core loop only.
4. Do not introduce per-scene GUT tests at this stage; the smoke test covers scene wiring.

## Acceptance Criteria

1. The GUT suite exits with code 0 when all manager-layer invariants pass, and exits non-zero when any invariant fails.
2. The smoke test exits with code 0 on a clean codebase and exits non-zero when a null-reference bug is deliberately introduced.
3. The GitHub Actions workflow reports pass/fail on every push to `main` and every pull request, completing in under five minutes total wall-clock time.
4. No existing production call site is changed by the RNG injection — the null-fallback preserves all current behavior. Outside CI, the test flag and pilot flag are absent and boot behavior is unchanged.
5. The smoke test passes ten consecutive runs on a clean codebase — Layer 2 is intentionally non-deterministic, so stability across repeated runs is the flakiness gate.
