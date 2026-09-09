extends Node

func light() -> void:
    if SaveService.haptic_enabled:
        Input.vibrate_handheld(12)

func medium() -> void:
    if SaveService.haptic_enabled:
        Input.vibrate_handheld(28)

func heavy() -> void:
    if SaveService.haptic_enabled:
        Input.vibrate_handheld(52)
