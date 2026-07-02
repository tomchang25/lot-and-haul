# Affix Dictionary

## Goal

Add a player-facing affix dictionary that turns item names into collected hypotheses: each known affix shows the possible clue combinations behind it, which combinations the player has confirmed, and which hidden outcomes remain a risk. This completes the affix-driven generation loop by making Authenticate a decision about hidden combination risk, not only a price reveal.

## Requirements

1. The dictionary must index knowledge by affix first, then by category context, because the affix name is the player's lookup key and the category/anchor tells them what concrete object that risk applies to.
2. Seeing an affix on an unveiled item must unlock that affix's dictionary entry and show the number of possible combinations as locked rows, so the player learns that a name such as "Suspicious" is a family of possibilities rather than one fixed meaning.
3. Revealed clues must fill the matching combination over time, with hidden clues kept unknown until research or authentication reveals them, because the main decision should be whether to spend resources to resolve hidden risk.
4. Each affix must have a tight semantic scope. If one affix covers unrelated questions, split it; "Suspicious" should stay about authenticity, provenance, or unclear origin, while "Modern" should stay about age, reproduction, reissue, or mass production.
5. Most affixes should carry three to five possible combinations. More than five should be reserved for rare, advanced, or especially important affixes; ten-way unknown lists turn the dictionary into homework instead of inference.
6. Each item must keep exactly one concrete anchor body in the player's mental model. Prefixes and suffixes describe risk, condition, provenance, era, production method, or status; the anchor remains the thing being bought.
7. Probability information must unlock gradually. Early dictionary entries show possibilities without odds; higher mastery, perks, or specialist tools can upgrade that to qualitative likelihoods, then rounded or exact weighted percentages.
8. Category context must matter, and location context should be able to matter. The same display label can imply different combination tables on paintings, toys, documents, jewelry, or weapons, while location can later bias which branch is more likely in that market.
9. The first implementation must fit the current single-prefix/single-suffix generation policy. Supporting one to two prefixes and one to two suffixes is a later generation and validator expansion, not a prerequisite for the dictionary.

## Design

The dictionary entry answers one player question: "When I see this affix on this kind of object, what hidden truths could it be pointing at?" For example, a Suspicious painting entry might eventually reveal paths like "fuzzy label + forgery", "fuzzy label + antique", or "repair marks + later restoration + historical artifact." A Modern watch entry should not drift into the same authenticity space; it should stay around mass-produced, reproduction, reissued, or contemporary-production paths.

Dictionary rows should be spoiler-safe. Once the player has seen an affix, the UI may show locked combination rows and their slot structure, but not undiscovered clue text or effects. A locked row can communicate "there are more possibilities here" without giving away that one of them is a high-value antique path.

Knowledge should have partial and confirmed states. Surface clues can fill in a row as observations, but a row is not fully confirmed until its hidden clues are known or the combination has no hidden clue to reveal. This preserves the bet: surface information narrows the hypothesis, while hidden information resolves it.

Anchor text should be visually and mechanically central in dictionary examples. The player should read "Suspicious Painting" or "Modern Watch" as a concrete item plus a risk modifier, not as a stack of abstract tags. If an affix starts doing the job of the anchor, the content should move back into anchors or categories.

Probability display should be tiered. A practical progression is: no odds at first sight, qualitative labels at low mastery ("likely", "possible", "unlikely"), rounded percentages at higher mastery, and exact weighted percentages only from a late perk or specialist feature. Location-specific probability overlays can sit on top of the canonical affix table: the base dictionary says what can happen, while a location readout says what tends to happen here.

Authoring rules should prefer readable inference over exhaustive possibility space. A narrow affix with four meaningful paths is better than a broad affix with ten weak paths. If content authors need more coverage, they should add another affix label with a sharper player-facing question instead of bloating the first one.

## Sketch (non-normative)

Names and shapes below are implementation hints only; the codebase wins any disagreement.

Add persistent affix discovery to the knowledge store, defaulting to empty for old saves:

```gdscript
var _affix_dictionary: Dictionary = {
    "bag_rustic": {
        "seen_count": 3,
        "location_counts": {
            "estate_sale": 2,
        },
        "combinations": {
            "comb_bag_rustic_01": {
                "seen_count": 2,
                "revealed_surface_ids": ["bag_exterior_faded", "bag_hardware_tarnished"],
                "revealed_hidden_ids": ["bag_leaf_coach"],
                "confirmed_count": 1,
            },
        },
    },
}
```

Record knowledge whenever an item's identity or clues change. A proposed manager helper can walk the generated affix and combination pairs on the item, resolve the combination through the affix, and store only clue ids that are already revealed on the item:

```gdscript
func record_item_dictionary_knowledge(entry: ItemEntry, location_id: String = "") -> void:
    for idx in range(entry.affixes.size()):
        var affix := entry.affixes[idx]
        var combination_id := entry.combination_ids[idx]
        var combination := _find_combination(affix, combination_id)
        _mark_affix_seen(affix.affix_id, location_id)
        _record_revealed_clues(affix.affix_id, combination, entry.revealed_clue_ids)
```

The update trigger can start broad and simple: item unveiled records the affix as seen, surface reveal records partial clue knowledge, and hidden reveal records hidden clue knowledge plus confirmation when all hidden clues in that combination are known. If a combination has no hidden clues, confirmation can require all of its surface clues to be known.

Add a dictionary panel under the knowledge hub. A first pass can be read-only and list affixes grouped by category: affix label, categories seen, known combination count, locked combination count, and a detail view with one row per combination. Known rows show revealed clue text and price effects; locked slots show placeholders only.

Probability presentation can be derived from combination weights at display time, gated by category rank or a perk:

```gdscript
func probability_text(affix: AffixData, combination: AffixCombinationData, category: CategoryData) -> String:
    var rank := KnowledgeManager.get_category_rank(category)
    if rank < 1:
        return ""
    var p := _combination_weight_share(affix, combination)
    if rank < 3:
        return _qualitative_band(p)
    if rank < 5:
        return "%d%%" % int(round(p * 100.0 / 5.0) * 5.0)
    return "%.1f%%" % (p * 100.0)
```

Keep the first pass on the existing generation contract: at most one prefix and one suffix per item. The display helper can already tolerate multiple affixes in name order, but expanding generation to one to two prefixes and one to two suffixes should wait until the validator checks prefix-prefix and suffix-suffix cross-products, dictionary rows explain multi-affix provenance clearly, and balance output can show the resulting clue-count distribution.

Content validation can start as authoring warnings rather than hard gates. The affix YAML validator can warn when an affix has more than five combinations, when an affix has only one possible combination, or when all combinations share nearly identical surface clues and therefore fail to create useful inference. Semantic narrowness still needs human review; put that in the affix generation prompt and content review checklist.

Location influence should not block the first pass. Store observation counts by location if available, then later add a location-affix bias layer that changes probability overlays or draw weights. The canonical dictionary remains affix + category; location modifies likelihood, not the meaning of the affix, unless a location-exclusive affix is deliberately authored.

## Non-Goals

1. Expanding generation to one to two prefixes and one to two suffixes. The dictionary should prove the learning loop on the current draw policy first.
2. Building a full posterior assistant that tells the player the exact best decision for a live item. The dictionary informs judgment; it does not replace judgment.
3. Rewriting lot or location generation around affix odds. Location-aware probability can be layered in after the base dictionary works.
4. Replacing the offline clue information validator. Authoring QA and player-facing collection knowledge are related but separate tools.
5. Revealing undiscovered clue text just because the player has seen an affix. Locked rows must stay spoiler-safe.

## Acceptance Criteria

1. After the player unveils an item with an affix, the dictionary shows that affix entry with the correct number of possible combination rows and no spoiler text in locked rows.
2. Revealing surface clues fills the matching observed combination with those clue texts while leaving hidden clue slots unknown.
3. Revealing hidden clues records them permanently, marks the combination confirmed when appropriate, and lets the player review the clue effects later.
4. A normal affix with three to five combinations is easy to scan; an affix with more than five combinations is treated as an exception that needs explicit content justification.
5. Probability information is absent, qualitative, rounded, or exact depending on player knowledge level or perks, rather than being fully transparent from the start.
6. The same affix display label can have different category-specific dictionary entries, and future location overlays can bias likelihood without changing the canonical clue combinations.
7. Old saves load with an empty dictionary state, and newly recorded dictionary knowledge persists across save/load.
