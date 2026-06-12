# Godot Screenshot Check — Rendered Captures in the Sandbox

Use this when a task needs **visual** verification (UI placement, tutorial overlay, VFX, theme changes) rather than just parse/script checks. Verified working 2026-06-13: minimal project and the full game (boots to main menu) both render correctly.

## Key facts

- `--headless` uses the dummy rendering driver — `get_viewport().get_texture().get_image()` returns black. Headless is fine for parse checks, useless for screenshots.
- The sandbox has Xvfb and software GL (llvmpipe/swrast) preinstalled. `xvfb-run` + `LIBGL_ALWAYS_SOFTWARE=1` + `--rendering-driver opengl3` renders the real UI.
- Audio falls back to the dummy driver — ALSA error lines at boot are expected noise, not findings.
- Software rendering is slow-ish: full game boot + ~180 frames ≈ 10–20 s. Budget frame counts against the 45 s shell timeout.

## Procedure

1. Build a clean `/tmp` snapshot exactly per `godot_headless_check.md` (mktemp dir, `git checkout-index` — or the `git archive HEAD` fallback — copy `dev/tools/bin`, regenerate tres + sfx, `rm -rf .godot`, `--import`). Never run against the mount.
2. Run with a virtual display instead of `--headless`:

```bash
cd "$LH"
LIBGL_ALWAYS_SOFTWARE=1 timeout 40 xvfb-run -a -s "-screen 0 1280x720x24" \
  dev/tools/bin/Godot_v4.6.3-stable_linux.x86_64 --path "$LH" --rendering-driver opengl3 [scene-or-flags]
```

Keep the Xvfb screen at least as large as the project window size.

3. Capture mechanism — either:
   - **ShotPilot harness** (once shipped — see `dev/docs/plans/tutorial_shot_harness.sketch.md`): pass `--tutorial-shot=<id> --shot-dir="$LH/shots"`.
   - **Temporary autoload** (general case): write a small capture script into the snapshot and append it to the `[autoload]` section of the snapshot's `project.godot` (the snapshot is disposable — never touch the real one). Pattern: count frames in `_process`, at chosen frame numbers `get_viewport().get_texture().get_image().save_png(<abs path>)`, then `get_tree().quit()`.

4. View the result: `cp` the PNGs to the outputs mount, then Read them via the Windows outputs path. Claude can see PNGs natively — judge placement, color, and overlap directly from the image.

## Caveats

- The game must quit itself (capture script calls `quit()`); otherwise `timeout` kills it and late captures are lost.
- Identical file sizes across capture frames usually means the screen is static between them, not a capture bug.
- Dynamic effects need multiple capture frames (e.g. 3–5 timestamps) — a single still hides timing problems.
- All `godot_headless_check.md` caveats apply (index staleness + archive fallback, gitignored assets noise, stale `.godot` poisoning UIDs).
