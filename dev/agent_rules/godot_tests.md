# Godot Tests — Unit & Smoke (How to Run)

Two automated test layers exist. Both are command-line flags handled by `GameManager._ready()`; both exit non-zero on failure.

- **Layer 1 — unit tests** (`--test-unit`): GameManager skips normal boot and routes to `test/test_runner.tscn`. GUT runs everything under `res://test/unit/` (subdirectories included), prints a summary line (`TestRunner: N scripts, N tests, N passed, N failed, N errors`), and quits 0/1.
- **Layer 2 — smoke test** (`--ci-run`): autoloads boot normally, scene routing is skipped, and the `CIPilot` autoload (`global/autoloads/ci_pilot/ci_pilot.gd`) auto-pilots one full run, then quits 0/1 (`CI Pilot: autopilot OK|FAILED`). CI additionally greps the captured log for error-level lines with a benign-noise filter — see the `smoke-test` job in `.github/workflows/ci.yml` for the authoritative grep patterns. Do not duplicate that pattern here; read it from ci.yml when needed.

Canonical invocations live in `.github/workflows/ci.yml` and `.vscode/tasks.json` ("CI: unit tests", "CI: smoke test").

## Sandbox procedure

Never run either layer against the mounted working tree (`sandbox_environment.md`). Build a `/tmp` snapshot as in `godot_headless_check.md`, and ensure `/tmp` is container-native Linux storage, not a Windows bind mount such as `E:/tmp:/tmp`: mktemp dir, `git checkout-index`, copy `dev/tools/bin`, regenerate `data/tres/`, render SFX, `rm -rf .godot`, `--import`. The `--import` step is setup only; ignore errors and non-zero exit status from that phase. It is required for Layer 2 (smoke test loads scenes that depend on imported WAV resources); Layer 1 (unit tests) may work without it but still benefits from a clean import. Then:

```bash
# extra step for unit tests: test fixtures are gitignored, so checkout-index omits them
cp -r test/test_data "$LH/test/"        # from the repo mount; recently-modified fixtures may be tail-truncated — cross-check before trusting a fixture-related failure

# Layer 1
timeout 40 dev/tools/bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path "$LH" --test-unit 2>&1 | tail -30; echo "exit=$?"

# Layer 2 — can exceed a single shell call's 45 s cap: background it, then poll
nohup dev/tools/bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path "$LH" --ci-run > "$LH/ci-output.log" 2>&1 &
# later calls: tail "$LH/ci-output.log" until "CI Pilot: autopilot OK|FAILED" appears, then apply the ci.yml grep filter to the log
```

Pass criteria: Layer 1 — exit 0 and a summary line with 0 failed / 0 errors. Layer 2 — `CI Pilot: autopilot OK` and no unexpected error lines after the ci.yml benign filter. Missing-asset warnings in `/tmp` runs are expected noise, not findings — see the caveats list in `godot_headless_check.md`.

As with the headless check: the snapshot is the **index**, not the working tree — ask the user to `git add` first if results must reflect unstaged edits, and cross-check any failure against the Windows side (Read/Grep file tools) before reporting it as a real bug.

## Windows side (user-run)

The VS Code tasks must point at the `_console.exe` Godot binary. The regular Windows exe is a GUI-subsystem app that detaches from the console immediately, so Run Task ends after the version banner with no test output and no usable exit code. If a task shows only the banner and finishes instantly, that is the cause — not a test failure.
