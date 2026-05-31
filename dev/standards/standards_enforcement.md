# Standards Enforcement

How the rules in `dev/standards/` are actually kept. Prose in a doc (or in
`CLAUDE.md`) is *advisory* — it only works if the agent happens to attend to it
at the right moment. Anything that can be decided from the source is moved off
prose and onto a check instead.

## The model

- **One source of truth.** The rule itself lives in its standard doc
  (`block_scene_architecture_standard.md`, etc.). This file and the linter only
  *point back at* it — they never restate or redefine a rule.
- **One check module.** All machine-checkable rules are decided by
  `dev/tools/lint_standards.py`. No second copy of the logic anywhere.
- **Many trigger points.** The same linter fires at more than one moment in the
  lifecycle, earliest-and-cheapest first:
  - *In-loop* — a PostToolUse hook (`dev/tools/lint_changed.py`, wired via
    `dev/tools/lint_hook.settings.json` → `.claude/settings.json`) lints only the
    file just edited and feeds violations straight back to the agent, so drift is
    corrected as it happens instead of surviving to review.
  - *Backstop* — the tracked pre-commit hook (`dev/tools/hooks/pre-commit`,
    installed once with `git config core.hooksPath dev/tools/hooks`) lints the
    staged `.gd`/`.tscn` at every `git commit`, and/or the same linter runs in
    CI. This is harness-agnostic: the in-loop hook only fires inside Claude Code,
    so for any other agent (opencode, a generic LLM) or a hand edit, the
    pre-commit/CI backstop is the *only* net — it is not optional in a
    multi-agent workflow. Bypassable in an emergency with `--no-verify`.

A non-Claude-Code agent that can't run hooks should be told, in its own rules,
to run `python dev/tools/lint_standards.py --files <changed>` before finishing.

Rules a machine genuinely can't decide stay with review and human judgment —
they are not listed here. Don't pre-declare future checks; a rule earns a check
when it's actually been violated enough to be worth automating.

## Active checks

Only what `lint_standards.py` enforces today:

- **Node-source rule** (`block_scene_architecture_standard.md` §11). A machine
  can't tell whether a node is persistent, so the convention makes intent
  syntactic: every runtime `add_child` that is *not* a `.instantiate()`'d packed
  scene must carry a `# node-src: <tag>` marker (on the line directly above the
  call, preferred, or trailing it) naming the permitted exception.
  Unmarked → violation. Tags map 1:1 to the standard's exceptions table:
  `instance`, `ephemeral`, `drawn`, `debug`, `timer`.

  ```gdscript
  # node-src: timer
  add_child(_npc_timer)

  # node-src: ephemeral — separator in rebuilt list
  _lot_summary.add_child(HSeparator.new())

  # node-src: debug
  add_child(_debug_label)
  ```

  A *wrong* claim (e.g. `# node-src: ephemeral` on a clearly persistent node) is
  now greppable — that's exactly what a reviewer checks by eye.

- **No signal connections in `.tscn`** (scene standard, Signal connections).
  Any `[connection]` block in a scene file fails; connect signals in `_ready()`
  so the full wiring surface is visible in code.

## Adding a check

Each check is a function `(rel_path, text) -> [Violation]` registered in
`GD_CHECKS` or `TSCN_CHECKS` in `lint_standards.py`. Every `Violation` cites the
standard section it enforces, so the linter never becomes a second source of
truth. Add a check only when a rule is both machine-decidable and worth the
maintenance — then document it under *Active checks* above.
