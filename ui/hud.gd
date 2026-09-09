class_name FlowHud
extends CanvasLayer

signal restart_requested
signal next_requested
signal pause_requested
signal resume_requested
signal debug_previous_requested
signal debug_next_requested

var _level_label: Label
var _buffer_slots: Array[PanelContainer] = []
var _buffer_icons: Array[CargoIcon] = []
var _buffer_panel: PanelContainer
var _buffer_row: HBoxContainer
var _upcoming_icons: Array[CargoIcon] = []
var _tutorial: PanelContainer
var _tutorial_label: Label

var _dim: ColorRect
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_subtitle: Label
var _overlay_primary: Button
var _overlay_secondary: Button
var _settings_row: HBoxContainer
var _sound_button: Button
var _haptic_button: Button
var _debug_row: HBoxContainer
var _overlay_mode: String = ""

func _ready() -> void:
    _build()

func set_level(level_number: int, title: String) -> void:
    _level_label.text = "LEVEL %02d  •  %s" % [level_number, title]

func set_upcoming(kinds: Array) -> void:
    for i in range(_upcoming_icons.size()):
        if i < kinds.size():
            _upcoming_icons[i].set_kind(String(kinds[i]), true, 1.0 if i == 0 else 0.72)
        else:
            _upcoming_icons[i].set_kind("", false, 0.48)

func set_buffer(kinds: Array, capacity: int) -> void:
    while _buffer_slots.size() < capacity:
        _add_buffer_slot()
    for i in range(_buffer_slots.size()):
        var visible_slot := i < capacity
        _buffer_slots[i].visible = visible_slot
        if not visible_slot:
            continue
        if i < kinds.size():
            _buffer_icons[i].set_kind(String(kinds[i]), true)
        else:
            _buffer_icons[i].set_kind("", false)

    var pressure := 0.0
    if capacity > 0:
        pressure = float(kinds.size()) / float(capacity)
    _apply_buffer_pressure(pressure)

func flash_buffer() -> void:
    if _buffer_panel == null:
        return
    var tween := _buffer_panel.create_tween()
    tween.tween_property(_buffer_panel, "scale", Vector2(1.025, 1.025), 0.08)
    tween.tween_property(_buffer_panel, "scale", Vector2.ONE, 0.12)

func set_tutorial_visible(value: bool, text: String = "TAP THE GLOWING SWITCH") -> void:
    _tutorial_label.text = text
    _tutorial.visible = value

func hide_overlay() -> void:
    _overlay_mode = ""
    _dim.visible = false
    _overlay.visible = false

func show_win(duration: float, mistakes: int) -> void:
    _overlay_mode = "win"
    _overlay_title.text = "FLOW CLEARED"
    if mistakes == 0:
        _overlay_subtitle.text = "Perfect routing  •  %.1fs" % duration
    else:
        _overlay_subtitle.text = "%s  •  %.1fs" % ["1 recovery" if mistakes == 1 else "%d recoveries" % mistakes, duration]
    _overlay_primary.text = "NEXT LEVEL"
    _overlay_secondary.text = "REPLAY"
    _overlay_secondary.visible = true
    _settings_row.visible = false
    _debug_row.visible = false
    _show_overlay()

func show_fail(reason: String) -> void:
    _overlay_mode = "fail"
    _overlay_title.text = "BUFFER FULL"
    _overlay_subtitle.text = reason
    _overlay_primary.text = "TRY AGAIN"
    _overlay_secondary.visible = false
    _settings_row.visible = false
    _debug_row.visible = false
    _show_overlay()

func show_pause() -> void:
    _overlay_mode = "pause"
    _overlay_title.text = "PAUSED"
    _overlay_subtitle.text = "Plan the next switches before the line starts moving again."
    _overlay_primary.text = "RESUME"
    _overlay_secondary.text = "RESTART LEVEL"
    _overlay_secondary.visible = true
    _settings_row.visible = true
    _debug_row.visible = OS.is_debug_build()
    _refresh_setting_buttons()
    _show_overlay()

func _show_overlay() -> void:
    _dim.visible = true
    _overlay.visible = true
    _overlay.scale = Vector2(0.94, 0.94)
    _overlay.modulate.a = 0.0
    var tween := _overlay.create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_overlay, "scale", Vector2.ONE, 0.20)
    tween.tween_property(_overlay, "modulate:a", 1.0, 0.14)

func _on_overlay_primary() -> void:
    AudioService.play("ui", 1.0, -7.0)
    match _overlay_mode:
        "win": next_requested.emit()
        "fail": restart_requested.emit()
        "pause": resume_requested.emit()

func _on_overlay_secondary() -> void:
    AudioService.play("ui", 0.96, -7.0)
    if _overlay_mode == "win" or _overlay_mode == "pause":
        restart_requested.emit()

func _toggle_audio() -> void:
    AudioService.set_enabled(not SaveService.audio_enabled)
    _refresh_setting_buttons()
    AudioService.play("ui", 1.0, -8.0)

func _toggle_haptic() -> void:
    SaveService.set_haptic_enabled(not SaveService.haptic_enabled)
    if SaveService.haptic_enabled:
        HapticService.light()
    _refresh_setting_buttons()

func _refresh_setting_buttons() -> void:
    _sound_button.text = "SOUND  %s" % ("ON" if SaveService.audio_enabled else "OFF")
    _haptic_button.text = "HAPTIC  %s" % ("ON" if SaveService.haptic_enabled else "OFF")

func _build() -> void:
    var root := Control.new()
    root.name = "HudRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    var top := MarginContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.add_theme_constant_override("margin_left", 36)
    top.add_theme_constant_override("margin_top", 34)
    top.add_theme_constant_override("margin_right", 36)
    root.add_child(top)

    var top_box := HBoxContainer.new()
    top_box.add_theme_constant_override("separation", 12)
    top.add_child(top_box)

    _level_label = Label.new()
    _level_label.text = "LEVEL 01"
    _level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _level_label.add_theme_font_size_override("font_size", 25)
    _level_label.add_theme_color_override("font_color", Color("#203044"))
    top_box.add_child(_level_label)

    var restart := Button.new()
    restart.text = "↻"
    restart.tooltip_text = "Restart"
    restart.custom_minimum_size = Vector2(64, 64)
    restart.add_theme_font_size_override("font_size", 29)
    _style_button(restart, false)
    restart.pressed.connect(func() -> void:
        AudioService.play("ui", 0.92, -8.0)
        restart_requested.emit()
    )
    top_box.add_child(restart)

    var pause := Button.new()
    pause.text = "Ⅱ"
    pause.tooltip_text = "Pause"
    pause.custom_minimum_size = Vector2(64, 64)
    pause.add_theme_font_size_override("font_size", 23)
    _style_button(pause, false)
    pause.pressed.connect(func() -> void:
        AudioService.play("ui", 1.0, -8.0)
        pause_requested.emit()
    )
    top_box.add_child(pause)

    var upcoming := PanelContainer.new()
    upcoming.set_anchors_preset(Control.PRESET_CENTER_TOP)
    upcoming.position = Vector2(-236, 108)
    upcoming.size = Vector2(472, 104)
    upcoming.add_theme_stylebox_override("panel", _panel_style(Color("#F7FAFCEB"), 24, Color(0, 0, 0, 0.08), 9))
    root.add_child(upcoming)

    var upcoming_row := HBoxContainer.new()
    upcoming_row.alignment = BoxContainer.ALIGNMENT_CENTER
    upcoming_row.add_theme_constant_override("separation", 10)
    upcoming.add_child(upcoming_row)

    var next_label := Label.new()
    next_label.text = "NEXT"
    next_label.add_theme_font_size_override("font_size", 17)
    next_label.add_theme_color_override("font_color", Color("#677B8C"))
    upcoming_row.add_child(next_label)

    for i in range(4):
        var icon := CargoIcon.new()
        icon.custom_minimum_size = Vector2(67 if i == 0 else 58, 67 if i == 0 else 58)
        upcoming_row.add_child(icon)
        _upcoming_icons.append(icon)

    _tutorial = PanelContainer.new()
    _tutorial.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _tutorial.position = Vector2(-210, 235)
    _tutorial.size = Vector2(420, 64)
    _tutorial.add_theme_stylebox_override("panel", _panel_style(Color("#203044E8"), 22, Color(0, 0, 0, 0.12), 8))
    root.add_child(_tutorial)
    _tutorial_label = Label.new()
    _tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _tutorial_label.text = "TAP THE GLOWING SWITCH"
    _tutorial_label.add_theme_font_size_override("font_size", 18)
    _tutorial_label.add_theme_color_override("font_color", Color.WHITE)
    _tutorial.add_child(_tutorial_label)
    _tutorial.visible = false

    var buffer_margin := MarginContainer.new()
    buffer_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    buffer_margin.offset_top = -184
    buffer_margin.offset_bottom = -30
    buffer_margin.add_theme_constant_override("margin_left", 38)
    buffer_margin.add_theme_constant_override("margin_right", 38)
    root.add_child(buffer_margin)

    _buffer_panel = PanelContainer.new()
    _buffer_panel.pivot_offset = Vector2(500, 76)
    _buffer_panel.add_theme_stylebox_override("panel", _panel_style(Color("#EEF4F7EC"), 25, Color(0, 0, 0, 0.11), 10))
    buffer_margin.add_child(_buffer_panel)

    var buffer_v := VBoxContainer.new()
    buffer_v.add_theme_constant_override("separation", 8)
    _buffer_panel.add_child(buffer_v)

    var buffer_title := Label.new()
    buffer_title.text = "WAITING BUFFER"
    buffer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    buffer_title.add_theme_font_size_override("font_size", 18)
    buffer_title.add_theme_color_override("font_color", Color("#53687A"))
    buffer_v.add_child(buffer_title)

    _buffer_row = HBoxContainer.new()
    _buffer_row.name = "Slots"
    _buffer_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _buffer_row.add_theme_constant_override("separation", 13)
    buffer_v.add_child(_buffer_row)
    for i in range(6):
        _add_buffer_slot(_buffer_row)

    _dim = ColorRect.new()
    _dim.color = Color(0.06, 0.10, 0.15, 0.38)
    _dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _dim.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_dim)

    _overlay = PanelContainer.new()
    _overlay.set_anchors_preset(Control.PRESET_CENTER)
    _overlay.position = Vector2(-372, -290)
    _overlay.size = Vector2(744, 580)
    _overlay.pivot_offset = Vector2(372, 290)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.add_theme_stylebox_override("panel", _panel_style(Color("#F9FBFCFC"), 36, Color(0, 0, 0, 0.21), 24))
    root.add_child(_overlay)

    var overlay_margin := MarginContainer.new()
    overlay_margin.add_theme_constant_override("margin_left", 54)
    overlay_margin.add_theme_constant_override("margin_right", 54)
    overlay_margin.add_theme_constant_override("margin_top", 48)
    overlay_margin.add_theme_constant_override("margin_bottom", 48)
    _overlay.add_child(overlay_margin)

    var overlay_v := VBoxContainer.new()
    overlay_v.alignment = BoxContainer.ALIGNMENT_CENTER
    overlay_v.add_theme_constant_override("separation", 18)
    overlay_margin.add_child(overlay_v)

    _overlay_title = Label.new()
    _overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_title.add_theme_font_size_override("font_size", 42)
    _overlay_title.add_theme_color_override("font_color", Color("#203044"))
    overlay_v.add_child(_overlay_title)

    _overlay_subtitle = Label.new()
    _overlay_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _overlay_subtitle.custom_minimum_size = Vector2(0, 84)
    _overlay_subtitle.add_theme_font_size_override("font_size", 21)
    _overlay_subtitle.add_theme_color_override("font_color", Color("#667B8E"))
    overlay_v.add_child(_overlay_subtitle)

    _settings_row = HBoxContainer.new()
    _settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _settings_row.add_theme_constant_override("separation", 12)
    overlay_v.add_child(_settings_row)

    _sound_button = Button.new()
    _sound_button.custom_minimum_size = Vector2(245, 58)
    _sound_button.add_theme_font_size_override("font_size", 18)
    _style_button(_sound_button, false)
    _sound_button.pressed.connect(_toggle_audio)
    _settings_row.add_child(_sound_button)

    _haptic_button = Button.new()
    _haptic_button.custom_minimum_size = Vector2(245, 58)
    _haptic_button.add_theme_font_size_override("font_size", 18)
    _style_button(_haptic_button, false)
    _haptic_button.pressed.connect(_toggle_haptic)
    _settings_row.add_child(_haptic_button)

    _debug_row = HBoxContainer.new()
    _debug_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _debug_row.add_theme_constant_override("separation", 12)
    overlay_v.add_child(_debug_row)

    var prev := Button.new()
    prev.text = "DEBUG  PREV LEVEL"
    prev.custom_minimum_size = Vector2(245, 52)
    prev.add_theme_font_size_override("font_size", 16)
    _style_button(prev, false)
    prev.pressed.connect(func() -> void: debug_previous_requested.emit())
    _debug_row.add_child(prev)

    var next := Button.new()
    next.text = "DEBUG  NEXT LEVEL"
    next.custom_minimum_size = Vector2(245, 52)
    next.add_theme_font_size_override("font_size", 16)
    _style_button(next, false)
    next.pressed.connect(func() -> void: debug_next_requested.emit())
    _debug_row.add_child(next)

    _overlay_primary = Button.new()
    _overlay_primary.custom_minimum_size = Vector2(0, 76)
    _overlay_primary.add_theme_font_size_override("font_size", 24)
    _style_button(_overlay_primary, true)
    _overlay_primary.pressed.connect(_on_overlay_primary)
    overlay_v.add_child(_overlay_primary)

    _overlay_secondary = Button.new()
    _overlay_secondary.custom_minimum_size = Vector2(0, 62)
    _overlay_secondary.add_theme_font_size_override("font_size", 20)
    _style_button(_overlay_secondary, false)
    _overlay_secondary.pressed.connect(_on_overlay_secondary)
    overlay_v.add_child(_overlay_secondary)

    hide_overlay()

func _add_buffer_slot(forced_parent: HBoxContainer = null) -> void:
    var row: HBoxContainer = forced_parent if forced_parent != null else _buffer_row
    if row == null:
        return
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(78, 78)
    panel.add_theme_stylebox_override("panel", _panel_style(Color("#DCE7EC"), 19, Color(0, 0, 0, 0.04), 2))
    var icon := CargoIcon.new()
    icon.set_kind("", false)
    panel.add_child(icon)
    row.add_child(panel)
    _buffer_slots.append(panel)
    _buffer_icons.append(icon)

func _apply_buffer_pressure(pressure: float) -> void:
    var bg := Color("#EEF4F7EC")
    if pressure >= 0.99:
        bg = Color("#FFE4E6F2")
    elif pressure >= 0.66:
        bg = Color("#FFF2DCF0")
    _buffer_panel.add_theme_stylebox_override("panel", _panel_style(bg, 25, Color(0, 0, 0, 0.11), 10))

func _style_button(button: Button, primary: bool) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#203044") if primary else Color("#E4EDF2")
    normal.corner_radius_top_left = 18
    normal.corner_radius_top_right = 18
    normal.corner_radius_bottom_left = 18
    normal.corner_radius_bottom_right = 18
    normal.content_margin_left = 22
    normal.content_margin_right = 22
    normal.content_margin_top = 12
    normal.content_margin_bottom = 12
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#142335") if primary else Color("#D3E0E7")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", normal)
    var font_color := Color.WHITE if primary else Color("#203044")
    button.add_theme_color_override("font_color", font_color)
    button.add_theme_color_override("font_hover_color", font_color)
    button.add_theme_color_override("font_pressed_color", font_color)

func _panel_style(bg: Color, radius: int, shadow: Color, shadow_size: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.shadow_color = shadow
    style.shadow_size = shadow_size
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style
