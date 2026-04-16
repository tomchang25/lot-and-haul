# price_config.gd
# Value object describing which factors participate in an ItemEntry price
# calculation. Passed to ItemEntry.compute_price() so every caller selects its
# pricing policy declaratively instead of duplicating the math.
class_name PriceConfig
extends RefCounted

# ── Factor toggles ───────────────────────────────────────────────────────────

var condition: bool = false
var knowledge: bool = false
var market: bool = false

# Uniform scalar applied after all factor terms (e.g. SpecialOrder buff).
var multiplier: float = 1.0

# ══ Presets ═══════════════════════════════════════════════════════════════════
# Each factory returns a fresh instance. Callers that need reuse should cache
# the result (see ItemRegistry price preset properties).


static func flat() -> PriceConfig:
    return PriceConfig.new()


static func condition_only() -> PriceConfig:
    var cfg := PriceConfig.new()
    cfg.condition = true
    return cfg


static func appraised() -> PriceConfig:
    var cfg := PriceConfig.new()
    cfg.condition = true
    cfg.knowledge = true
    return cfg


static func market() -> PriceConfig:
    var cfg := PriceConfig.new()
    cfg.condition = true
    cfg.knowledge = true
    cfg.market = true
    return cfg
