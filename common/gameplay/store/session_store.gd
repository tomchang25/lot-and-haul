# session_store.gd
# Thin base class for flat resumable session stores. Owns only generic session
# semantics — is_active, get_resume_target, has_session, clear. Concrete stores
# own their payload shape and mutator methods. Transaction boundaries and save
# scheduling remain in the owning Manager.
#
# Does NOT extend AggregateSessionStore behaviour (RunSnapshotContext,
# shared-ItemEntry identity, atomic aggregate discard). RunStore and LotStore
# continue to extend StoreBase directly.
class_name SessionStore
extends StoreBase

## True when this store represents a resumable session. Concrete stores provide
## active state and target validation; the lifecycle predicate stays centralized.
func has_session() -> bool:
    return is_active() and is_valid_resume_target(get_resume_target())


## Returns whether the concrete session is considered active.
func is_active() -> bool:
    return false


## Returns the scene identifier this session routes to on resume,
## or "" when inactive.
func get_resume_target() -> String:
    return ""


## Returns whether [param target] is a valid resume target for this session type.
func is_valid_resume_target(target: String) -> bool:
    return not target.is_empty()


## Resets all session fields to their default (inactive) state.
func clear() -> void:
    pass
