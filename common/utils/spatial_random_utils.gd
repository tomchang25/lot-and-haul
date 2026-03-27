class_name SpatialRandomUtils
extends RefCounted

static func random_angle(rng: RandomNumberGenerator = null) -> float:
    var resolved_rng := _resolve_rng(rng)
    return resolved_rng.randf_range(0.0, TAU)


static func random_unit_vector(rng: RandomNumberGenerator = null) -> Vector2:
    return Vector2.RIGHT.rotated(random_angle(rng))


static func random_point_in_circle(center: Vector2, radius: float, rng: RandomNumberGenerator = null) -> Vector2:
    if radius <= 0.0:
        return center

    var resolved_rng := _resolve_rng(rng)
    var angle := resolved_rng.randf_range(0.0, TAU)
    var distance := sqrt(resolved_rng.randf()) * radius

    return center + Vector2.RIGHT.rotated(angle) * distance


static func random_point_in_annulus(center: Vector2, min_radius: float, max_radius: float, rng: RandomNumberGenerator = null) -> Vector2:
    if max_radius < min_radius:
        var temp := min_radius
        min_radius = max_radius
        max_radius = temp

    min_radius = maxf(0.0, min_radius)
    max_radius = maxf(0.0, max_radius)

    if max_radius <= 0.0:
        return center

    var resolved_rng := _resolve_rng(rng)
    var angle := resolved_rng.randf_range(0.0, TAU)

    var min_sq := min_radius * min_radius
    var max_sq := max_radius * max_radius
    var distance := sqrt(resolved_rng.randf_range(min_sq, max_sq))

    return center + Vector2.RIGHT.rotated(angle) * distance


static func _resolve_rng(rng: RandomNumberGenerator = null) -> RandomNumberGenerator:
    if rng != null:
        return rng

    var fallback_rng := RandomNumberGenerator.new()
    fallback_rng.randomize()
    return fallback_rng
