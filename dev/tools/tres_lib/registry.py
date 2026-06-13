"""Entity registry — processing order matters (dependency order)."""

from tres_lib.entities.perk import SPEC as perk_spec
from tres_lib.entities.super_category import SPEC as super_category_spec
from tres_lib.entities.category import SPEC as category_spec
from tres_lib.entities.attribute_data import SPEC as attribute_data_spec
from tres_lib.entities.anchor_data import SPEC as anchor_spec
from tres_lib.entities.clue import SPEC as clue_spec
from tres_lib.entities.car import SPEC as car_spec
from tres_lib.entities.lot import SPEC as lot_spec
from tres_lib.entities.affix import SPEC as affix_spec
from tres_lib.entities.affix import SPEC_COMBINATION as affix_combination_spec
from tres_lib.entities.location import SPEC as location_spec

REGISTRY = [
    perk_spec,
    super_category_spec,
    category_spec,
    attribute_data_spec,
    anchor_spec,
    clue_spec,
    affix_combination_spec,
    affix_spec,
    car_spec,
    lot_spec,
    location_spec,
]
