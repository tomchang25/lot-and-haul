# Lint Before Finishing

If you are an agent without the in-loop lint hook (i.e. not Claude Code), run the standards linter on every changed `.gd` or `.tscn` file before finishing:

```bash
python dev/tools/lint_standards.py --files <changed files>
```

See `dev/standards/standards_enforcement.md` for what the linter checks and how to add new rules.
