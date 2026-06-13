# Test Data as YAML

All test data lives in `data/yaml/` and goes through the standard YAML → tres pipeline (`yaml_to_tres.py`), the same pipeline used by production data. No in-memory fakes, no hand-constructed resources in test files.

## Workflow

1. Author test data as a YAML file under `data/yaml/`. Prefix the filename with `_test_` to distinguish it from production data (e.g. `_test_item_generator.yaml`).
2. Run `python3 dev/tools/yaml_to_tres.py --godot-root /workspace --force` to regenerate all `.tres` files (production + test data).
3. The test registries (`CategoryRegistry`, `AnchorRegistry`, `ClueRegistry`, etc.) load the test `.tres` files alongside production data via `ResourceDirLoader`.
4. Tests call the same `ItemGenerator.draw()` that production uses, passing a `CategoryData` from the registry and a seeded `RandomNumberGenerator`.

## Why

- Tests exercise the exact same resource-loading path as production — same registries, same `ResourceDirLoader`, same `.tres` format.
- `ItemGenerator.draw()` reads from registries natively, so no shim or adapter layer is needed for tests.
- Adding test data to `data/yaml/` is zero-cost — the pipeline already scans `**/*.yaml` recursively from that directory.
- The `--force` flag regenerates all `.tres` from all YAML sources, including test data.
- Test data is committed alongside production YAML and is version-controlled.

## Conventions

- Prefix all test IDs with `test_` to avoid collisions with production data.
- Use a dedicated `domain` for test clues that matches the test `category_id` so they don't leak into production pool draws.
- Keep test data minimal — one super-category, one category, the minimum anchors and clues needed for the tests that use them.

## Prerequisites

- PyYAML: `pip install pyyaml`
- Run from the project root: `python3 dev/tools/yaml_to_tres.py --godot-root /workspace --force`
