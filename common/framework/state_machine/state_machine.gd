class_name StateMachine
extends Node

@export var initial_state: State
@onready var target: Node = owner

var current_state: State
var states: Dictionary = { }

## Guards against re-entrant transitions triggered during enter() or exit().
var _transitioning: bool = false

@export_group("Tick Update")

## When enabled, current_state.update() and current_state.physics_update() are
## only called every [tick_interval] seconds instead of every frame/physics frame.
## Transitions, enter(), and exit() are never throttled — they always fire immediately.
@export var tick_enabled: bool = true

## How often (in seconds) to call update() and physics_update() when tick_enabled is true.
## e.g. 0.1 = 10 Hz, 0.5 = 2 Hz.
@export_range(0.016, 5.0, 0.016, "suffix:s") var tick_interval: float = 0.1

## Stagger tick phases so multiple StateMachines in the scene don't all fire on
## the same frame. Each instance starts with a random phase in [0, tick_interval).
@export var tick_stagger: bool = true

# Accumulated time for _process tick.
var _process_accumulator: float = 0.0
# Accumulated time for _physics_process tick.
var _physics_accumulator: float = 0.0


func _ready() -> void:
    if target and not target.is_node_ready():
        await target.ready

    states.clear()

    for child in get_children():
        if child is State:
            var state := child as State
            if state.state_id < 0:
                push_warning("StateMachine: state '%s' has invalid state_id" % state.name)
                continue

            states[state.state_id] = state
            if not state.transition_requested.is_connected(_on_transition_requested):
                state.transition_requested.connect(_on_transition_requested)

    if initial_state == null:
        push_error("StateMachine must have an initial_state")
        return

    if not states.has(initial_state.state_id):
        push_error("StateMachine initial_state is not registered in children")
        return

    # Spread tick phases so multiple machines don't all fire on the same frame.
    if tick_stagger:
        var offset := randf_range(0.0, tick_interval)
        _process_accumulator = offset
        _physics_accumulator = offset

    current_state = initial_state
    current_state.enter()


func _process(delta: float) -> void:
    if current_state == null:
        return

    if tick_enabled:
        _process_accumulator += delta
        if _process_accumulator >= tick_interval:
            _process_accumulator -= tick_interval
            current_state.update(tick_interval)
    else:
        current_state.update(delta)


func _physics_process(delta: float) -> void:
    if current_state == null:
        return

    if tick_enabled:
        _physics_accumulator += delta
        if _physics_accumulator >= tick_interval:
            _physics_accumulator -= tick_interval
            current_state.physics_update(tick_interval)
    else:
        current_state.physics_update(delta)


## Internal path — only states call this via change_state().
## The `from` check ensures a stale or already-exited state
## cannot corrupt the FSM with a late-arriving signal.
func _on_transition_requested(from: State, to: int) -> void:
    if _transitioning:
        push_warning("StateMachine: transition requested mid-transition from '%s', ignoring" % from.name)
        return

    if from != current_state:
        return

    if not states.has(to):
        push_warning("StateMachine: missing target state id %s" % str(to))
        return

    var new_state := states[to] as State
    if new_state == current_state:
        return

    _do_transition(new_state)


## External path — called by the actor (e.g. on damage, or from Beehave).
## Respects the current state's interruptible flag.
## Use force = true only when the transition must happen regardless
## (e.g. instant death, cutscene takeover).
func request_transition(to: int, force: bool = false) -> void:
    if _transitioning:
        push_warning("StateMachine: request_transition called mid-transition to id %s, ignoring" % str(to))
        return

    if current_state == null:
        return

    if not states.has(to):
        push_warning("StateMachine: missing target state id %s" % str(to))
        return

    if not force and not current_state.interruptible:
        return

    var new_state := states[to] as State
    if new_state == current_state:
        return

    _do_transition(new_state)


## Shared transition logic. Never call this directly — use
## _on_transition_requested (internal) or request_transition (external).
func _do_transition(new_state: State) -> void:
    if new_state == current_state:
        return

    _transitioning = true
    current_state.exit()
    current_state = new_state
    current_state.enter()
    _transitioning = false

    # Reset accumulators on transition so the new state gets a full tick interval
    # before its first update — avoids a leftover accumulator from the old state
    # causing an immediate tick on entry.
    _process_accumulator = 0.0
    _physics_accumulator = 0.0
