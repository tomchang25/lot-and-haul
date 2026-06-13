# affix_registry.gd
# Autoload that loads all AffixData resources at startup and provides query access.
# Access globally via AffixRegistry.get_affix_by_id(affix_id).
extends ResourceRegistry

func _dir_path() -> String:
    return DataPaths.AFFIXES_DIR


func _id_of(r: Resource) -> String:
    return (r as AffixData).affix_id if r is AffixData else ""


func get_affix_by_id(affix_id: String) -> AffixData:
    return get_by_id(affix_id) as AffixData


func get_all_affixes() -> Array[AffixData]:
    var result: Array[AffixData] = []
    for affix: AffixData in get_all():
        result.append(affix)
    return result
