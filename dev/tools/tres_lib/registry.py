"""Entity registry — processing order matters (dependency order)."""

from tres_lib.entities.perk import SPEC as perk_spec
from tres_lib.entities.super_category import SPEC as super_category_spec
from tres_lib.entities.category import SPEC as category_spec
from tres_lib.entities.attribute_data import SPEC as attribute_data_spec
from tres_lib.entities.clue import SPEC as clue_spec
from tres_lib.entities.item import SPEC as item_spec
from tres_lib.entities.car import SPEC as car_spec
from tres_lib.entities.lot import SPEC as lot_spec
from tres_lib.entities.location import SPEC as location_spec

# Processing order: entities listed earlier populate uid_cache entries
# that later entities need for cross-references. clue_spec must precede
# item_spec so clue UIDs are available for ExtResource links in item .tres files.
REGISTRY = [
    perk_spec,
    super_category_spec,
    category_spec,
    attribute_data_spec,
    clue_spec,
    item_spec,
    car_spec,
    lot_spec,
    location_spec,
]
