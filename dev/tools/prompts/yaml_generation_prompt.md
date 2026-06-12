# Lot & Haul - YAML Generation Prompts

This file is kept as the legacy entrypoint for YAML generation prompt docs.

The current standards are split by responsibility:

- `dev/tools/prompts/yaml_generation/base.md`: shared YAML output, ID, text, and validation rules.
- `dev/tools/prompts/yaml_generation/category.md`: category schema and cargo shape rules.
- `dev/tools/prompts/yaml_generation/sfx.md`: SFX sound patch schema (waveform, pitch envelope, ADSR, filters, playback metadata) and intent→sound conventions for placeholder sound generation.

Items are now pool-generated at draw time (ItemGenerator service); the legacy `data/yaml/items/*.yaml` pipeline and `item.md` prompt were removed in Phase 2.
