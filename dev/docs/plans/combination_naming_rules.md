# Combination Naming Rules

**Status:** Exploring

A combination rule defines a set of input clue ids and a replacement naming entry (slot, text, priority). When all inputs are revealed on the same item, the combination replaces the individual naming entries during display-name composition — e.g. `{Blown Glass, Moser}` → `"Bohemian Moser"`.

Authored per category, separate from clue definitions.

## Validation

The validator enforces:

- existence of every referenced clue id,
- same-domain inputs,
- priority dominance over the individual naming entries it replaces,
- full-reveal name match (the composed name equals the authored combination name when all inputs are revealed).

## Open questions

- Pairs only, or arbitrary input sets?
- A single clue participating in multiple combination rules — allowed, and how resolved?
- Strict text containment vs. free replacement of the individual entries.

## Prerequisite

The affix-naming system validated across the full item set (composed == authored) — already in place.
