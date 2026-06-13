# Godot Screenshot Check — Rendered Captures in the Sandbox

Use this when a task needs **visual** verification (UI placement, tutorial overlay, VFX, theme changes) rather than just parse/script checks. Verified working 2026-06-13: minimal project and the full game (boots to main menu) both render correctly.

## Sandbox prerequisites

The following packages are required (install once per session):

```bash
apt-get update -qq && apt-get install -y -qq xvfb libxcursor1 libxinerama1 libxrandr2 libxi6
```

## Key facts

- `--headless` uses the dummy rendering driver — `get_viewport().get_texture().get_image()` returns black. Headless is fine for parse checks, useless for screenshots.
- `xvfb-run` + `LIBGL_ALWAYS_SOFTWARE=1` + `--rendering-driver opengl3` + `--display-driver x11` renders the real UI via software GL (llvmpipe). **Always specify `--display-driver x11`** — without it, missing XCursor/Wayland libraries cause Godot to fall through all display drivers and exit with "all display drivers failed."
- `libxkbcommon.so.0` may be missing (non-fatal warning, "Could not set V-Sync mode"). Ignore it.
- Audio falls back to the dummy driver — ALSA error lines at boot are expected noise, not findings.
- Software rendering is slow-ish: full game boot + ~180 frames ≈ 10–20 s. Budget frame counts against the shell timeout (use 60–90 s for interactive captures).

## Procedure

1. Build a clean `/tmp` snapshot following `godot_headless_check.md` with **one critical difference**: run `render_sfx.py` _after_ `--import`, not before (the sfx script needs resolved script UIDs). Full order:
   - `git checkout-index` (or `git archive HEAD` fallback)
   - copy `dev/tools/bin`
   - `yaml_to_tres.py`
   - `rm -rf .godot`
   - `--import`
   - `render_sfx.py`

   Never run against the mount.

2. Run with a virtual display instead of `--headless`:

```bash
# Note: $LH is a literal path from step 1. Shell calls don't share env — paste the actual path.
cd "$LH"
LIBGL_ALWAYS_SOFTWARE=1 timeout 60 xvfb-run -a -s "-screen 0 1280x720x24" \
  dev/tools/bin/Godot_v4.6.3-stable_linux.x86_64 --path "$LH" --rendering-driver opengl3 --display-driver x11 [flags]
```

Keep the Xvfb screen at least as large as the project window size.

3. Capture mechanism — choose one:
   - **ShotPilot harness** (shipped): pass `--tutorial-shot=<id> --shot-dir="$LH/shots"`.
   - **CI Pilot** (game logic without UI clicks): pass `--ci-run` to exercise the full game loop. Screenshots show whatever scene is active when the capture fires.
   - **Temporary autoload** (general case — see template below). Write a capture script into the snapshot, append it to `[autoload]` in the snapshot's `project.godot`, and let it count frames in `_process` to fire captures and `quit()`.

   **Save screenshots to an absolute path outside the project tree** (e.g. `/tmp/shots/`) — if the PNG lands inside the snapshot dir, Godot creates `.import` files for it and they pollute subsequent runs.

### Temporary autoload template

Create `/tmp/lh.XXXXXX/tmp_capture.gd`:

```gdscript
extends Node
var _frame := 0

func _ready():
    print("CAPTURE: ready")

func _process(_delta):
    _frame += 1
    if _frame == 120:
        snap("frame_120")
    elif _frame == 300:
        snap("frame_300")
        print("CAPTURE: done")
        get_tree().quit(0)

func snap(name: String):
    DirAccess.make_dir_recursive_absolute("/tmp/shots")
    var img := get_viewport().get_texture().get_image()
    img.save_png("/tmp/shots/%s.png" % name)
```

Append to `project.godot` `[autoload]` section:

```
TmpCapture="*res://tmp_capture.gd"
```

### Interacting with the UI

To simulate clicks (e.g. press New Game, select a slot), use `Input.parse_input_event()` with `InputEventMouseButton` at pixel coordinates. In software rendering, button hit areas don't always match pixel coordinates precisely — if a click misses, use node-level access instead:

```gdscript
# Mouse click fallback — sometimes unreliable in software GL
func click(x: float, y: float):
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    ev.position = Vector2(x, y)
    Input.parse_input_event(ev)
    ev = InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = false
    ev.position = Vector2(x, y)
    Input.parse_input_event(ev)

# Node-level access — reliable for ConfirmationDialogs
var scene := get_tree().current_scene
var dialog := scene.get_node("%OverwriteDialog") as ConfirmationDialog
if dialog and dialog.visible:
    dialog.get_ok_button().pressed.emit()
```

4. View the result: `cp` the PNGs to a workspace folder (e.g. `/workspace/tmp/`), then Read them. Identical file sizes across frames usually means a static screen, not a capture bug — verify with `identify -verbose` to check channel statistics.

## Caveats

- The game must quit itself (capture script calls `quit()`); otherwise `timeout` kills it and late captures are lost.
- Identical file sizes across capture frames usually means the screen is static between them, not a capture bug. Use `identify -verbose` on the PNGs to inspect channel statistics, histogram, and confirm whether pixel content differs.
- Dynamic effects need multiple capture frames (e.g. 3–5 timestamps) — a single still hides timing problems.
- All `godot_headless_check.md` caveats apply (index staleness + archive fallback, gitignored assets noise, stale `.godot` poisoning UIDs).
- `$LH` does **not** persist across shell calls. Each `bash` invocation needs the literal path from `mktemp` — save it and paste it explicitly.
