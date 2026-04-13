# resource_dir_loader.gd
# Static helper for loading all .tres files in a directory, keyed by a
# caller-supplied id getter. Used by registry autoloads (ItemRegistry,
# CarRegistry, LocationRegistry) and by KnowledgeManager's perk/skill loaders.
class_name ResourceDirLoader
extends RefCounted

# Loads every .tres in dir_path and returns a Dictionary keyed by
# id_getter(resource). Resources for which id_getter returns "" (empty id,
# wrong type) are skipped. Emits push_error if the directory cannot be opened.
static func load_by_id(dir_path: String, id_getter: Callable) -> Dictionary:
    var result: Dictionary = { }
    var dir := DirAccess.open(dir_path)
    if dir == null:
        push_error("ResourceDirLoader: could not open " + dir_path)
        return result

    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var res := load(dir_path + "/" + file_name) as Resource
            if res != null:
                var id: String = id_getter.call(res)
                if id != "":
                    result[id] = res
        file_name = dir.get_next()
    dir.list_dir_end()

    return result
