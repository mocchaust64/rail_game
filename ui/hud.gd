class_name FlowHud
extends CanvasLayer

signal restart_requested
signal next_requested
signal pause_requested
signal resume_requested
signal debug_previous_requested
signal debug_next_requested
signal text_scale_changed
signal game_speed_changed

var _level_label: Label
var _upcoming_icons: Array[CargoIcon] = []
var _buffer_icons: Array[CargoIcon] = []
var _buffer_panel: PanelContainer
var _buffer_row: HBoxContainer
var _tutorial: PanelContainer
var _tutorial_label: Label

var _dim: ColorRect
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_subtitle: Label
var _overlay_primary: Button
var _overlay_secondary: Button
var _settings_row: GridContainer
var _sound_button: Button
var _haptic_button: Button
var _motion_button: Button
var _text_button: Button
var _speed_button: Button
var _debug_row: HBoxContainer
var _overlay_mode := ""


func _ready() -> void:
    _build()


func set_level(level_number: int, title: String) -> void:
    _level_label.text = "%02d" % level_number


func set_upcoming(kinds: Array) -> void:
    for i in range(_upcoming_icons.size()):
        if i < kinds.size():
            _upcoming_icons[i].set_kind(String(kinds[i]), true, 1.0 if i == 0 else 0.52)
        else:
            _upcoming_icons[i].set_kind("", false, 0.16)


func set_buffer(kinds: Array, capacity: int) -> void:
    while _buffer_icons.size() < capacity:
        _add_buffer_slot()
    for i in range(_buffer_icons.size()):
        var slot := _buffer_icons[i].get_parent()
        slot.visible = i < capacity
        if i >= capacity:
            continue
        _buffer_icons[i].set_kind(String(kinds[i]) if i < kinds.size() else "", i < kinds.size())
    var pressure := float(kinds.size()) / float(maxi(1, capacity))
    _apply_buffer_pressure(pressure)


func flash_buffer() -> void:
    if _buffer_panel == null:
        return
    var tween := Motion.tween(_buffer_panel)
    tween.tween_property(_buffer_panel, "scale", Vector2(1.055, 1.055), 0.065)
    tween.tween_property(_buffer_panel, "scale", Vector2.ONE, 0.105)


func set_tutorial_visible(value: bool, text: String = "") -> void:
    # The junction itself pulses; this is deliberately icon-only so the first
    # screen reads like the reference instead of a tutorial card.
    _tutorial_label.text = "↓"
    _tutorial.visible = value


func hide_overlay() -> void:
    _overlay_mode = ""
    _dim.visible = false
    _overlay.visible = false


func show_win(duration: float, mistakes: int) -> void:
    _overlay_mode = "win"
    _overlay_title.text = tr("UI_FLOW_CLEARED")
    _overlay_subtitle.text = tr("UI_PERFECT_ROUTING") % duration if mistakes == 0 else tr("UI_RESULT_FORMAT") % [tr("UI_RECOVERY_ONE") if mistakes == 1 else tr("UI_RECOVERY_MANY") % mistakes, duration]
    _overlay_primary.text = tr("UI_NEXT_LEVEL")
    _overlay_secondary.text = tr("UI_REPLAY")
    _overlay_secondary.visible = true
    _settings_row.visible = false
    _debug_row.visible = false
    _show_overlay()


func show_fail(reason: String) -> void:
    _overlay_mode = "fail"
    _overlay_title.text = tr("UI_BUFFER_FULL")
    _overlay_subtitle.text = reason
    _overlay_primary.text = tr("UI_TRY_AGAIN")
    _overlay_secondary.visible = false
    _settings_row.visible = false
    _debug_row.visible = false
    _show_overlay()


func show_pause() -> void:
    _overlay_mode = "pause"
    _overlay_title.text = tr("UI_PAUSED")
    _overlay_subtitle.text = tr("UI_PAUSE_HINT")
    _overlay_primary.text = tr("UI_RESUME")
    _overlay_secondary.text = tr("UI_RESTART_LEVEL")
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
    var tween := Motion.tween(_overlay)
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_overlay, "scale", Vector2.ONE, 0.18)
    tween.tween_property(_overlay, "modulate:a", 1.0, 0.13)


func _on_overlay_primary() -> void:
    AudioService.play("ui", 1.0, -7.0)
    match _overlay_mode:
        "win": next_requested.emit()
        "fail": restart_requested.emit()
        "pause": resume_requested.emit()


func _on_overlay_secondary() -> void:
    AudioService.play("ui", 0.96, -7.0)
    if _overlay_mode in ["win", "pause"]:
        restart_requested.emit()


func _build() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.theme = _build_theme()
    add_child(root)

    var insets := _safe_area_insets()

    # Minimal top controls: enough utility for an MVP, no large banner/card.
    var top := HBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 22
    top.offset_right = -22
    top.offset_top = 18 + insets.x
    top.offset_bottom = 66 + insets.x
    top.add_theme_constant_override("separation", 8)
    root.add_child(top)

    _level_label = Label.new()
    _level_label.text = "01"
    _level_label.custom_minimum_size = Vector2(44, 44)
    _level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _level_label.add_theme_font_size_override("font_size", _font_size(18))
    _level_label.add_theme_color_override("font_color", Color("#625A51"))
    _level_label.add_theme_stylebox_override("normal", _panel_style(Color("#F6E8D7B8"), 15, Color(0, 0, 0, 0.05), 3))
    top.add_child(_level_label)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer)

    var restart := Button.new()
    restart.text = "↻"
    restart.custom_minimum_size = Vector2(44, 44)
    restart.add_theme_font_size_override("font_size", _font_size(22))
    _style_button(restart, false)
    restart.pressed.connect(func() -> void: restart_requested.emit())
    top.add_child(restart)

    var pause := Button.new()
    pause.text = "Ⅱ"
    pause.custom_minimum_size = Vector2(44, 44)
    pause.add_theme_font_size_override("font_size", _font_size(17))
    _style_button(pause, false)
    pause.pressed.connect(func() -> void: pause_requested.emit())
    top.add_child(pause)

    # Global future queue remains because it is planning information, but the
    # card is gone. It now reads as four loose balls above the feeder area.
    var upcoming := PanelContainer.new()
    upcoming.set_anchors_preset(Control.PRESET_CENTER_TOP)
    upcoming.position = Vector2(-116, 70 + insets.x)
    upcoming.size = Vector2(232, 52)
    upcoming.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0), 0, Color(0, 0, 0, 0), 0))
    root.add_child(upcoming)

    var upcoming_row := HBoxContainer.new()
    upcoming_row.alignment = BoxContainer.ALIGNMENT_CENTER
    upcoming_row.add_theme_constant_override("separation", -1)
    upcoming.add_child(upcoming_row)
    for i in range(4):
        var icon := CargoIcon.new()
        icon.custom_minimum_size = Vector2(50 if i == 0 else 44, 50 if i == 0 else 44)
        upcoming_row.add_child(icon)
        _upcoming_icons.append(icon)

    _tutorial = PanelContainer.new()
    _tutorial.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _tutorial.position = Vector2(-25, 123 + insets.x)
    _tutorial.size = Vector2(50, 42)
    _tutorial.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0), 0, Color(0, 0, 0, 0), 0))
    root.add_child(_tutorial)
    _tutorial_label = Label.new()
    _tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _tutorial_label.add_theme_font_size_override("font_size", _font_size(28))
    _tutorial_label.add_theme_color_override("font_color", Color("#6B6258D8"))
    _tutorial.add_child(_tutorial_label)
    _tutorial.visible = false

    # Reference-style waiting buffer: circular sand-coloured sockets, no white
    # container chrome or label. Occupied slots simply reveal their cargo icon.
    _buffer_panel = PanelContainer.new()
    _buffer_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _buffer_panel.position = Vector2(-190, -82 - insets.y)
    _buffer_panel.size = Vector2(380, 58)
    _buffer_panel.pivot_offset = Vector2(190, 29)
    _buffer_panel.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0), 0, Color(0, 0, 0, 0), 0))
    root.add_child(_buffer_panel)

    _buffer_row = HBoxContainer.new()
    _buffer_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _buffer_row.add_theme_constant_override("separation", 8)
    _buffer_panel.add_child(_buffer_row)
    for i in range(6):
        _add_buffer_slot()

    _dim = ColorRect.new()
    _dim.color = Color(0.10, 0.08, 0.06, 0.30)
    _dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _dim.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_dim)

    _overlay = PanelContainer.new()
    _overlay.set_anchors_preset(Control.PRESET_CENTER)
    _overlay.position = Vector2(-330, -270)
    _overlay.size = Vector2(660, 540)
    _overlay.pivot_offset = Vector2(330, 270)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.add_theme_stylebox_override("panel", _panel_style(Color("#FFF9F2FA"), 34, Color(0, 0, 0, 0.22), 22))
    root.add_child(_overlay)

    var margin := MarginContainer.new()
    for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 42)
    _overlay.add_child(margin)

    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 14)
    margin.add_child(v)

    _overlay_title = Label.new()
    _overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_title.add_theme_font_size_override("font_size", _font_size(38))
    _overlay_title.add_theme_color_override("font_color", Color("#4A4540"))
    v.add_child(_overlay_title)

    _overlay_subtitle = Label.new()
    _overlay_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _overlay_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _overlay_subtitle.custom_minimum_size = Vector2(0, 74)
    _overlay_subtitle.add_theme_font_size_override("font_size", _font_size(19))
    _overlay_subtitle.add_theme_color_override("font_color", Color("#736D66"))
    v.add_child(_overlay_subtitle)

    _settings_row = GridContainer.new()
    _settings_row.columns = 2
    _settings_row.add_theme_constant_override("h_separation", 10)
    _settings_row.add_theme_constant_override("v_separation", 8)
    v.add_child(_settings_row)
    _sound_button = _make_setting_button(_toggle_audio)
    _haptic_button = _make_setting_button(_toggle_haptic)
    _motion_button = _make_setting_button(_toggle_reduced_motion)
    _text_button = _make_setting_button(_toggle_large_text)
    _speed_button = _make_setting_button(_cycle_game_speed)

    _debug_row = HBoxContainer.new()
    _debug_row.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_child(_debug_row)
    var prev := Button.new()
    prev.text = tr("UI_DEBUG_PREV")
    prev.pressed.connect(func() -> void: debug_previous_requested.emit())
    _debug_row.add_child(prev)
    var next := Button.new()
    next.text = tr("UI_DEBUG_NEXT")
    next.pressed.connect(func() -> void: debug_next_requested.emit())
    _debug_row.add_child(next)

    _overlay_primary = Button.new()
    _overlay_primary.custom_minimum_size = Vector2(0, 68)
    _overlay_primary.add_theme_font_size_override("font_size", _font_size(22))
    _style_button(_overlay_primary, true)
    _overlay_primary.pressed.connect(_on_overlay_primary)
    v.add_child(_overlay_primary)

    _overlay_secondary = Button.new()
    _overlay_secondary.custom_minimum_size = Vector2(0, 56)
    _overlay_secondary.add_theme_font_size_override("font_size", _font_size(18))
    _style_button(_overlay_secondary, false)
    _overlay_secondary.pressed.connect(_on_overlay_secondary)
    v.add_child(_overlay_secondary)

    hide_overlay()


func _add_buffer_slot() -> void:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(54, 54)
    panel.add_theme_stylebox_override("panel", _buffer_slot_style(Color("#D7C8B2CC")))
    var icon := CargoIcon.new()
    icon.set_kind("", false)
    panel.add_child(icon)
    _buffer_row.add_child(panel)
    _buffer_icons.append(icon)


func _apply_buffer_pressure(pressure: float) -> void:
    var empty_colour := Color("#D7C8B2CC")
    if pressure >= 0.99:
        empty_colour = Color("#E8AB99E6")
    elif pressure >= 0.66:
        empty_colour = Color("#E6C79FDD")
    for icon in _buffer_icons:
        var slot := icon.get_parent() as PanelContainer
        if slot != null:
            slot.add_theme_stylebox_override("panel", _buffer_slot_style(empty_colour))


func _buffer_slot_style(bg: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.corner_radius_top_left = 27
    style.corner_radius_top_right = 27
    style.corner_radius_bottom_left = 27
    style.corner_radius_bottom_right = 27
    style.shadow_color = Color(0, 0, 0, 0.08)
    style.shadow_size = 3
    style.shadow_offset = Vector2(0, 2)
    style.content_margin_left = 3
    style.content_margin_right = 3
    style.content_margin_top = 3
    style.content_margin_bottom = 3
    return style


func _make_setting_button(handler: Callable) -> Button:
    var b := Button.new()
    b.custom_minimum_size = Vector2(230, 54)
    b.add_theme_font_size_override("font_size", _font_size(16))
    _style_button(b, false)
    b.pressed.connect(handler)
    _settings_row.add_child(b)
    return b


func _toggle_audio() -> void:
    AudioService.set_enabled(not SaveService.audio_enabled)
    _refresh_setting_buttons()


func _toggle_haptic() -> void:
    SaveService.set_haptic_enabled(not SaveService.haptic_enabled)
    _refresh_setting_buttons()


func _toggle_reduced_motion() -> void:
    SaveService.set_reduced_motion(not SaveService.reduced_motion)
    _refresh_setting_buttons()


func _toggle_large_text() -> void:
    SaveService.set_large_text(not SaveService.large_text)
    _refresh_setting_buttons()
    text_scale_changed.emit()


func _cycle_game_speed() -> void:
    var options: Array = SaveService.SPEED_OPTIONS
    var index := options.find(SaveService.game_speed)
    SaveService.set_game_speed(float(options[(index + 1) % options.size()]))
    _refresh_setting_buttons()
    game_speed_changed.emit()


func _refresh_setting_buttons() -> void:
    _sound_button.text = tr("UI_SOUND") % (tr("UI_ON") if SaveService.audio_enabled else tr("UI_OFF"))
    _haptic_button.text = tr("UI_HAPTIC") % (tr("UI_ON") if SaveService.haptic_enabled else tr("UI_OFF"))
    _motion_button.text = tr("UI_REDUCED_MOTION") % (tr("UI_REDUCED") if SaveService.reduced_motion else tr("UI_FULL"))
    _text_button.text = tr("UI_TEXT_SIZE") % (tr("UI_LARGE") if SaveService.large_text else tr("UI_NORMAL"))
    _speed_button.text = tr("UI_GAME_SPEED") % ("%d%%" % roundi(SaveService.game_speed * 100.0))


func _font_size(base: int) -> int:
    return int(round(float(base) * SaveService.text_scale()))


func _style_button(button: Button, primary: bool) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#D97858") if primary else Color("#F6E8D7B8")
    normal.corner_radius_top_left = 15
    normal.corner_radius_top_right = 15
    normal.corner_radius_bottom_left = 15
    normal.corner_radius_bottom_right = 15
    normal.content_margin_left = 16
    normal.content_margin_right = 16
    normal.content_margin_top = 9
    normal.content_margin_bottom = 9
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#C8684A") if primary else Color("#E3D4C1D0")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", normal)
    var fc := Color.WHITE if primary else Color("#625A51")
    button.add_theme_color_override("font_color", fc)
    button.add_theme_color_override("font_hover_color", fc)
    button.add_theme_color_override("font_pressed_color", fc)


func _panel_style(bg: Color, radius: int, shadow: Color, shadow_size: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.shadow_color = shadow
    style.shadow_size = shadow_size
    style.shadow_offset = Vector2(0, 4)
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    return style


func _build_theme() -> Theme:
    var font := SystemFont.new()
    font.font_names = PackedStringArray(["SF Pro Rounded", "SF Pro Text", "Roboto", "Noto Sans", "sans-serif"])
    font.font_weight = 600
    var theme := Theme.new()
    theme.default_font = font
    return theme


func _safe_area_insets() -> Vector2:
    var safe := DisplayServer.get_display_safe_area()
    var window_size := DisplayServer.window_get_size()
    if window_size.y <= 0 or safe.size.y <= 0:
        return Vector2.ZERO
    var window_top := DisplayServer.window_get_position().y
    var window_bottom := window_top + window_size.y
    var scale := get_viewport().get_visible_rect().size.y / float(window_size.y)
    var top := maxf(0.0, float(safe.position.y - window_top)) * scale
    var bottom := maxf(0.0, float(window_bottom - (safe.position.y + safe.size.y))) * scale
    return Vector2(top, bottom)
