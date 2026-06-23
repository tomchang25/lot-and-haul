Review the currently git-staged changes and codebase for violations against any referenced plan spec. Steps:

1. Run `git diff --cached --name-only` to get staged files.
2. Run `git diff --cached --stat` for a summary.
3. If a plan/spec file is among the staged files (under `dev/docs/plans/`), read it as the spec.
4. Run `git diff --cached` for all staged files and systematically compare each change against the spec: every requirement, implementation note, edge case, and acceptance criterion.
5. Run `python dev/tools/lint_standards.py --files <staged .gd files under game/>` to verify no standards violations.
6. Search for any stale references to removed APIs across the full codebase (old method names, old constants, old import patterns the spec says should be gone).
7. Report: a summary table showing each file's compliance status, any deviations from the spec, and the final verdict.
8. Double-check for any robustness concerns or stale/legacy problems.
