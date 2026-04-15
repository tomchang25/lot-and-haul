"""Entity registry — processing order matters (dependency order)."""

from tres_lib.entities.skill import SPEC as skill_spec
from tres_lib.entities.super_category import SPEC as super_category_spec
from tres_lib.entities.category import SPEC as category_spec
from tres_lib.entities.identity_layer import SPEC as identity_layer_spec
from tres_lib.entities.item import SPEC as item_spec
from tres_lib.entities.car import SPEC as car_spec
from tres_lib.entities.lot import SPEC as lot_spec
from tres_lib.entities.location import SPEC as location_spec
from tres_lib.entities.special_order_data import SPEC as special_order_data_spec
from tres_lib.entities.merchant import SPEC as merchant_spec

# Processing order: entities listed earlier populate uid_cache entries
# that later entities need for cross-references.
REGISTRY = [
    skill_spec,
    super_category_spec,
    category_spec,
    identity_layer_spec,
    item_spec,
    car_spec,
    lot_spec,
    location_spec,
    special_order_data_spec,
    merchant_spec,
]
