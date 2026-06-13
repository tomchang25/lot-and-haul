# Item System

Items are runtime compositions, not fixed authored item records. The system's through-line is information asymmetry: the player first handles a physical object with masked identity, then reveals anchor identity, surface evidence, and hidden truth over time; every economic decision uses the best knowledge the player currently has.

Related docs: `lot_auction_run.md` covers the run scene loop and auction flow, `item_display.md` covers rendering invariants, `customer_sell.md` covers selling, `day_slot_economy.md` covers AP timing, and `meta/knowledge.md` covers mastery, attributes, and perks.

## Composition

A generated item starts from a lot-selected category. The category narrows the anchor pool, affix eligibility, clue domains, cargo expectations, and mastery axis.

Each item has exactly one anchor. The anchor is the concrete object body: it gives the item its base value, physical shape, weight, and body name once unveiled. Anchors are not clues; they have no discovery roll, DC, or price modifier operation. This is the line that keeps an item feeling like a thing being bought rather than a pile of tags.

Affixes are the player-facing hypothesis layer. Under the current draw policy, a generated item can receive at most one prefix and at most one suffix. Each drawn affix chooses exactly one weighted combination, and that combination contributes the item's affix-sourced surface and hidden clues. A plain item has no affix; it receives baseline surface clues and no hidden clues.

Surface and hidden clues carry evidence text, discovery difficulty, attribute association, and price effects. Surface clues are ordinary observable evidence. Hidden clues are the verification layer: maker truth, forgery, later repair, internal damage, provenance, or any other outcome that should remain risky until discovered.

## Generation Flow

Lot generation chooses how many items appear, then repeatedly picks a category from the lot's category or super-category weighting. The item generator then chooses an anchor from that category, using the lot's tier weighting as the value-band pressure. Affixes are drawn after the anchor, filtered by category, and each affix contributes one chosen combination.

This order matters. The anchor says what the object is; the affix says what family of risk or promise is attached to it; the combination says which clue set actually landed. Rarity is not drawn directly from the lot as a separate item flag: current item rarity is derived from the number of hidden clues on the generated instance. As a result, affix combination content is the practical source of rarity for affixed items.

Affix combinations are validated as authored content. The current data contract allows at most one hidden base override on an item and prevents incompatible hidden clue groups from coexisting. Runtime generation still carries conflict insurance, but shipped data is expected to satisfy the authored cross-product rules before play.

## Information Lifecycle

Veiled items hide identity and price, but they still have physical presence: cargo shape and weight are observable because the player must be able to pack objects before fully understanding them.

Unveiling reveals the anchor identity and the item's affix-qualified name. This is the moment the player learns the concrete object body and the visible hypothesis labels attached to it. Unveiling does not prove which affix combination was drawn.

Inspection spends run AP to attempt unrevealed clues. Surface clues increase the player's appraisal confidence by changing the known price stack and raising the revealed-surface ratio. Hidden clues can be discovered if reached by the clue attempt flow, but storage research is the reliable hub-phase route for resolving hidden truth.

Returning to the hub auto-reveals all remaining surface clues on cargo items before they enter storage. This keeps storage focused on repair, restoration, authentication, and selling decisions instead of asking the player to spend hub time on ordinary surface observation.

An item is verified when all of its hidden clues are revealed. Items with no hidden clues are verified by default, which makes common plain items economically straightforward and keeps the verification bet concentrated on items that actually carry hidden risk.

## Price And Value

All item prices resolve through the ItemEntry price pipeline. The appraised value starts from the anchor base value, adds all revealed surface additions, then multiplies all revealed surface multipliers. The verified value uses the same add-then-multiply structure across revealed surface and hidden clues, with a hidden override allowed to replace the anchor base before modifiers are applied. Condition applies after clue value.

Unverified items show an estimated range, not a true number. The range is widest when inspection is shallow and converges as surface clues are revealed; a per-instance center offset keeps early estimates from always centering on the true point value. Verified items show an exact resolved value.

Auction NPCs do not know true value. Their estimate is based on a rolled subset of surface clues and is cached when the lot is created, so the auction has a stable hidden price pressure that can disagree with both the player's current appraisal and the item's eventual verified value.

## Storage And Selling

Items keep their runtime identity as they move from lot, to auction win, to cargo, to storage, and finally to sale. The same item instance accumulates reveal state, research progress, condition changes, and save identity across that lifecycle.

Storage actions are deterministic once chosen. Repair and restore change condition within their respective bounds, while research advances the first unrevealed hidden clue toward its DC and reveals it when enough progress has accumulated. Storage actions spend AP only when the guarded effect actually lands.

Selling reads the item's resolved price and revealed clue tags. Surface clue tags become available once revealed; hidden clue tags become available once that hidden clue is revealed. The anchor is deliberately not a demand tag because it is the base object identity, not a buyer preference signal. Verified items receive the selling system's verified advantages separately from tag matching.

## Authoring Boundaries

Human-authored YAML defines anchors, clues, affixes, and affix combinations; generated resource files are build artifacts and are not hand-edited. Anchors carry physical identity and base value. Clues carry revealable evidence and price effects. Affixes carry display labels, category scope, draw weight, and the set of possible combinations behind that label.

Affixes should stay semantically narrow. A good affix asks one readable player question, such as authenticity, production era, condition risk, provenance, or luxury signal. If one affix needs many unrelated outcomes, it should be split rather than turned into a broad mystery bucket.

Most affixes should remain small enough for players to learn. A few meaningful combinations create inference; too many unknown rows create homework. The intended long-term player skill is recognizing how an affix, category, surface evidence, and hidden-risk table interact, not memorizing a giant undifferentiated clue list.
