# customer_sell_fixtures.gd
# Fixture methods for the nightly-selling testbed. Seeds storage items and
# generates a night of customers so the customer_sell scene has real data to
# display and sell through.
extends RefCounted

class_name CustomerSellFixtures

## Seeds storage items (via StorageFixtures) and opens a single evening selling
## slot so CustomerSell finds populated nightly_customers and sellable items.
static func seed_open_shop() -> void:
    StorageFixtures.seed_storage_state()
    MetaManager.begin_open_shop(2)
