# economy.gd
# Shared economic constants. Access via class_name (not an autoload).
class_name Economy
extends RefCounted

const DAILY_BASE_COST: int = 100
const LOCATION_SAMPLE_SIZE: int = 3

# Authenticate duration in days, keyed by ItemData.Rarity enum.
const AUTHENTICATE_DAYS: Dictionary = {
    ItemData.Rarity.COMMON: 1,
    ItemData.Rarity.UNCOMMON: 2,
    ItemData.Rarity.RARE: 3,
    ItemData.Rarity.EPIC: 4,
    ItemData.Rarity.LEGENDARY: 5,
}
