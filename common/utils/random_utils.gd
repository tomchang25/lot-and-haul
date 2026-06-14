class_name RandomUtils
extends RefCounted

static var _default_rng := RandomNumberGenerator.new()
static var _default_rng_ready := false

# ── Name pools ─────────────────────────────────────────────────────────────────

const FIRST_NAMES: Array[String] = [
    "Alice",
    "Bob",
    "Carol",
    "Dave",
    "Eve",
    "Frank",
    "Grace",
    "Hank",
    "Iris",
    "Jake",
    "Kate",
    "Leo",
    "Mia",
    "Noah",
    "Olive",
    "Pete",
    "Quinn",
    "Rosa",
    "Sam",
    "Tina",
    "Uma",
    "Vince",
    "Wendy",
    "Xander",
]

const LAST_NAMES: Array[String] = [
    "Weaver",
    "Chen",
    "Diaz",
    "Park",
    "Torres",
    "Lin",
    "Kim",
    "Moss",
    "Bell",
    "Sato",
    "Rossi",
    "Patel",
    "Khan",
    "Mueller",
    "Costa",
    "Yamada",
]


## Returns the shared production RNG. Tests should pass their own seeded RNG when a result must stay deterministic.
static func default_rng() -> RandomNumberGenerator:
    _ensure_default_rng()
    return _default_rng


## Replaces the shared production RNG seed with [param seed_value].
static func set_seed(seed_value: int) -> void:
    _default_rng.seed = seed_value
    _default_rng_ready = true


## Randomizes the shared production RNG.
static func randomize_seed() -> void:
    _default_rng.randomize()
    _default_rng_ready = true


## Returns [param rng] when provided, otherwise the shared production RNG.
static func resolve_rng(rng: RandomNumberGenerator = null) -> RandomNumberGenerator:
    return rng if rng != null else RandomUtils.default_rng()


## Returns a random integer in [param from]..[param to] using [param rng] or the shared RNG.
static func randi_range(from: int, to: int, rng: RandomNumberGenerator = null) -> int:
    return resolve_rng(rng).randi_range(from, to)


## Returns a random float in [param from]..[param to] using [param rng] or the shared RNG.
static func randf_range(from: float, to: float, rng: RandomNumberGenerator = null) -> float:
    return resolve_rng(rng).randf_range(from, to)


## Returns a random unsigned integer using [param rng] or the shared RNG.
static func randi(rng: RandomNumberGenerator = null) -> int:
    return resolve_rng(rng).randi()


## Returns a random float in 0.0..1.0 using [param rng] or the shared RNG.
static func randf(rng: RandomNumberGenerator = null) -> float:
    return resolve_rng(rng).randf()


static func pick_weighted_index(weights: Array[int], rng: RandomNumberGenerator = null) -> int:
    if weights.is_empty():
        return -1

    var total_weight := 0
    for weight in weights:
        total_weight += max(weight, 0)

    if total_weight <= 0:
        return -1

    var resolved_rng := resolve_rng(rng)
    var roll := resolved_rng.randi_range(1, total_weight)

    var cumulative := 0
    for i in range(weights.size()):
        cumulative += max(weights[i], 0)
        if roll <= cumulative:
            return i

    return -1


static func pick_weighted_entry(entries: Array, rng: RandomNumberGenerator = null):
    if entries.is_empty():
        return null

    var weights: Array[int] = []
    weights.resize(entries.size())

    for i in range(entries.size()):
        var entry = entries[i]
        if entry == null:
            weights[i] = 0
        elif "weight" in entry:
            weights[i] = max(entry.weight, 0)
        else:
            weights[i] = 0

    var picked_index := pick_weighted_index(weights, rng)
    if picked_index < 0 or picked_index >= entries.size():
        return null

    return entries[picked_index]


## Returns a random alphanumeric string of [param length] characters.
static func random_id(rng: RandomNumberGenerator = null, length: int = 8) -> String:
    var resolved_rng := resolve_rng(rng)
    var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
    var id := ""
    for i in range(length):
        id += chars[resolved_rng.randi_range(0, chars.length() - 1)]
    return id


## Returns a random "First Last" name drawn from the NAME pools.
static func random_name(rng: RandomNumberGenerator = null) -> String:
    var resolved_rng := resolve_rng(rng)
    var first: String = FIRST_NAMES[resolved_rng.randi_range(0, FIRST_NAMES.size() - 1)]
    var last: String = LAST_NAMES[resolved_rng.randi_range(0, LAST_NAMES.size() - 1)]
    return "%s %s" % [first, last]


## Shuffles [param array] in-place using Fisher-Yates with [param rng].
static func shuffle(array: Array, rng: RandomNumberGenerator = null) -> void:
    var resolved_rng := resolve_rng(rng)
    var n := array.size()
    for i in range(n - 1, 0, -1):
        var j := resolved_rng.randi_range(0, i)
        var tmp = array[i]
        array[i] = array[j]
        array[j] = tmp


## Picks [param count] unique items from [param pool] using [param rng].
## Returns fewer items if the pool is smaller than count.
static func pick_unique(pool: Array, count: int, rng: RandomNumberGenerator = null) -> Array:
    if pool.is_empty() or count <= 0:
        return []

    var resolved_rng := resolve_rng(rng)
    var actual := mini(count, pool.size())
    var chosen: Array = []
    var used: Array[int] = []
    for i in range(actual):
        var idx := resolved_rng.randi_range(0, pool.size() - 1)
        while idx in used:
            idx = resolved_rng.randi_range(0, pool.size() - 1)
        used.append(idx)
        chosen.append(pool[idx])
    return chosen


static func _ensure_default_rng() -> void:
    if _default_rng_ready:
        return
    _default_rng.randomize()
    _default_rng_ready = true
