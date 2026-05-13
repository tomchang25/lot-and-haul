# Lot & Haul - YAML Generation Prompts

This file is kept as the legacy entrypoint for YAML generation prompt docs.

The current standards are split by responsibility:

- `dev/tools/prompts/yaml_generation/base.md`: shared YAML output, ID, text, and validation rules.
- `dev/tools/prompts/yaml_generation/category.md`: category schema and cargo shape rules.
- `dev/tools/prompts/yaml_generation/item.md`: Phase 3 item schema, perceived identity layer rules, and item value rules.

For complete item-category generation, use these together:

1. `yaml_generation/base.md`
2. `yaml_generation/category.md`
3. `yaml_generation/item.md`

Do not use older single-file copies of the item generation prompt. Phase 3 changed the value model: `identity_layers[].base_value` is perceived value, while `items[].base_price` is true verified item value.
