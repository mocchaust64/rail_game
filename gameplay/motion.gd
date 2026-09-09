class_name Motion
extends RefCounted
# Single place that decides how long animation lasts, so the reduced-motion
# setting reaches every tween instead of being honoured in some places only.

# Reduced motion keeps a trace of the transition rather than cutting to the end
# state, which reads as a bug. Tweens reject a zero duration, hence the floor.
const REDUCED_FACTOR := 0.08
const MINIMUM_SECONDS := 0.01


static func scale() -> float:
    return REDUCED_FACTOR if SaveService.reduced_motion else 1.0


static func duration(base_seconds: float) -> float:
    return maxf(MINIMUM_SECONDS, base_seconds * scale())


static func is_reduced() -> bool:
    return SaveService.reduced_motion


# Every gameplay and UI tween is created through here so the reduced-motion
# setting reaches all of them. Speed scale is used rather than editing each
# duration: it cannot be forgotten at a call site, and it keeps chained and
# parallel tweens in step with each other.
static func tween(node: Node) -> Tween:
    var t := node.create_tween()
    if SaveService.reduced_motion:
        t.set_speed_scale(1.0 / REDUCED_FACTOR)
    return t
