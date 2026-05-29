class_name RandomUtils
extends RefCounted

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


static func pick_weighted_index(weights: Array[int], rng: RandomNumberGenerator = null) -> int:
    if weights.is_empty():
        return -1

    var total_weight := 0
    for weight in weights:
        total_weight += max(weight, 0)

    if total_weight <= 0:
        return -1

    var resolved_rng := rng if rng != null else _create_fallback_rng()
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
static func random_id(rng: RandomNumberGenerator, length: int = 8) -> String:
    var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
    var id := ""
    for i in range(length):
        id += chars[rng.randi_range(0, chars.length() - 1)]
    return id


## Returns a random "First Last" name drawn from the NAME pools.
static func random_name(rng: RandomNumberGenerator) -> String:
    var first: String = FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)]
    var last: String = LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]
    return "%s %s" % [first, last]


## Picks [param count] unique items from [param pool] using [param rng].
## Returns fewer items if the pool is smaller than count.
static func pick_unique(rng: RandomNumberGenerator, pool: Array, count: int) -> Array:
    if pool.is_empty() or count <= 0:
        return []

    var actual := mini(count, pool.size())
    var chosen: Array = []
    var used: Array[int] = []
    for i in range(actual):
        var idx := rng.randi_range(0, pool.size() - 1)
        while idx in used:
            idx = rng.randi_range(0, pool.size() - 1)
        used.append(idx)
        chosen.append(pool[idx])
    return chosen


static func _create_fallback_rng() -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    return rng
