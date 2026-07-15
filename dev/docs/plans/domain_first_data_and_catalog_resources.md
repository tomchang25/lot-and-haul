# Domain-First Data and Catalog Resources

## Goal

Move Lot & Haul's data conventions toward domain-first ownership while preserving the current generated catalog pipeline until it can be migrated deliberately. The change matters because new curated content should not inherit a global generated-data shape when it needs authored packs, explicit order, or testable alternate content sets.

## Requirements

1. Preserve the current generated catalog behavior until a migration phase explicitly replaces it, because the live economy and run flow depend on those generated resources being available at boot.
2. Establish domain-first ownership for new hand-authored content: a data domain owns its schemas, authored content, Catalog Resources, and any generated subfolders it needs.
3. Support Catalog Resources as first-class content packs for curated sets that need authored membership, authored order, scene injection, test variants, or alternate debug pools.
4. Keep directory-scanned global registries for broad generated lookup data where O(1) by-id access and startup validation are more valuable than authored ordering.
5. Make generated/manual boundaries explicit per domain so future contributors know which resources can be edited directly and which must be rebuilt from source data.

## Design

The migration should happen in two tracks.

Documentation and standards land first. They describe domain-first data ownership as the preferred shape for new content, while naming the current generated catalog pipeline as a preserved existing system rather than a universal rule. Registry guidance distinguishes Catalog Resources from directory-scanned global registries so new systems choose the right dependency shape before writing code.

Code and data migration lands later as a focused compatibility pass. The current generated catalog should move only when the generator, registry loading, validation, tests, and boot expectations can change together. During that pass, generated output remains generated, hand-authored content remains directly editable, and every moved domain documents its own rebuild command and generated-output folder.

Catalog Resources should be introduced opportunistically for new curated systems rather than forced onto the existing generated catalog. A catalog owns content membership and validation; runtime systems consume it explicitly and keep rolling, filtering, RNG, save state, and gameplay flow outside the catalog.

## Non-Goals

1. Do not rewrite the current generated economy catalog as part of the documentation update.
2. Do not replace existing global generated-data registries with Catalog Resources unless a later implementation spec proves that the content benefits from authored packs.
3. Do not change item generation, pricing, auction balance, customer demand, save compatibility, or tutorial flow as part of the data-layout migration.
4. Do not create a new project-wide generated folder rule; generated output remains owned and documented by the domain that needs it.

## Acceptance Criteria

1. Project standards describe domain-first data ownership for new content while accurately preserving the current generated catalog pipeline.
2. Registry guidance clearly explains when to use Catalog Resources and when to keep directory-scanned global registries.
3. New curated content can be designed around explicit catalog assets without becoming an autoload or hidden generator default.
4. The current generated catalog continues to boot, validate, and serve existing gameplay until a dedicated implementation pass moves it.
5. A later migration can move generated catalog data domain by domain without changing player-facing behavior.
