class_name ScreenShake
extends RefCounted
# Trauma-based camera shake.
#
# Impacts add trauma, trauma decays on its own, and the offset is trauma squared
# so a small knock stays subtle while a real failure is felt. Squaring is also
# what stops the shake ending on a visible snap.

const MAX_OFFSET := 0.42
const MAX_ROLL := 0.035
const DECAY_PER_SECOND := 1.9

# Different frequencies per axis so the motion never reads as a single wobble.
const FREQUENCY_X := 27.0
const FREQUENCY_Y := 31.0
const FREQUENCY_ROLL := 23.0

var _trauma := 0.0
var _clock := 0.0
var _offset := Vector3.ZERO
var _roll := 0.0


func add_trauma(amount: float) -> void:
    _trauma = clampf(_trauma + amount, 0.0, 1.0)


func advance(delta: float) -> void:
    if SaveService.reduced_motion:
        _trauma = 0.0
        _offset = Vector3.ZERO
        _roll = 0.0
        return
    if _trauma <= 0.0:
        _offset = Vector3.ZERO
        _roll = 0.0
        return
    _clock += delta
    _trauma = maxf(0.0, _trauma - DECAY_PER_SECOND * delta)
    var strength := _trauma * _trauma
    _offset = Vector3(
        sin(_clock * FREQUENCY_X) * MAX_OFFSET * strength,
        sin(_clock * FREQUENCY_Y + 1.7) * MAX_OFFSET * strength * 0.6,
        0.0
    )
    _roll = sin(_clock * FREQUENCY_ROLL + 0.9) * MAX_ROLL * strength


func offset() -> Vector3:
    return _offset


func roll() -> float:
    return _roll
