# lot_pool_sampler.gd
# Stateless lot sampling policy for location browse pools.
class_name LotPoolSampler
extends RefCounted

static func sample(location_data: LocationData, include_test: bool = false) -> Array[LotData]:
    var pool: Array[LotData] = location_data.lot_pool.duplicate()
    if not include_test:
        pool = pool.filter(func(lot: LotData): return not lot.is_test)
    RandomUtils.shuffle(pool)
    var count := mini(location_data.lot_number, pool.size())
    return pool.slice(0, count)
