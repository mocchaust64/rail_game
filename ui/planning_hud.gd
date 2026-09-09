class_name PlanningHud
extends CanvasLayer

signal run_requested
signal lane_requested(lane_index: int)
signal remove_requested
signal next_requested
signal replay_requested

var _root: Control
var _stats: HBoxContainer
var _gold_label: Label
var _spent_label: Label
var _best_label: Label
var _hint_label: Label
var _config_panel: PanelContainer
var _config_title: Label
var _lane_buttons: Array[Button] = []
var _remove_button: Button
var _run_button: Button
var _result_dim: ColorRect
var _result_panel: PanelContainer
var _result_title: Label
var _result_stars: Label
var _result_subtitle: Label

var _sorter_cost := 3


func _ready() -> void:
    _build()


func show_planning(gold_remaining: int = 0, spent: int = 0, optimal: int = 0, sorter_cost: int = 3) -> void:
    if _root == null:
        return
    _sorter_cost = sorter_cost
    _root.visible = true
    _result_dim.visible = false
    _result_panel.visible = false
    _stats.visible = true
    _run_button.visible = true
    _run_button.disabled = true
    clear_sorter()
    set_budget(gold_remaining, spent, optimal)
    _hint_label.text = "Tap a foundation to build • Sorter costs %d gold" % _sorter_cost


func show_running() -> void:
    if _root != null:
        _root.visible = false


func set_budget(gold_remaining: int, spent: int, optimal: int) -> void:
    if _gold_label == null:
        return
    _gold_label.text = "GOLD  %d" % gold_remaining
    _spent_label.text = "SPENT  %d" % spent
    _best_label.text = "BEST  %d" % optimal


func set_run_enabled(value: bool) -> void:
    if _run_button != null:
        _run_button.disabled = not value


func show_sorter(sorter_id: String, mapping: Array, cost: int) -> void:
    if _config_panel == null:
        return
    _config_panel.visible = true
    _config_title.text = "SORTER %s" % sorter_id
    _hint_label.text = "Choose which colour uses each black rail"
    for i in range(_lane_buttons.size()):
        var kind := String(mapping[i]) if i < mapping.size() else "red"
        _lane_buttons[i].text = "%d   %s" % [i + 1, kind.to_upper()]
        _style_lane_button(_lane_buttons[i], kind)
    _remove_button.text = "REMOVE   +%d GOLD" % cost


func clear_sorter() -> void:
    if _config_panel != null:
        _config_panel.visible = false


func flash_message(message: String) -> void:
    if _hint_label == null:
        return
    _hint_label.text = message
    _hint_label.modulate = Color("#C6674C")
    var tween := Motion.tween(_hint_label)
    tween.tween_property(_hint_label, "modulate", Color.WHITE, 0.35)


func show_result(stars: int, spent: int, optimal: int) -> void:
    if _root == null:
        return
    _root.visible = true
    _stats.visible = false
    _config_panel.visible = false
    _run_button.visible = false
    _hint_label.text = ""
    _result_dim.visible = true
    _result_panel.visible = true
    _result_title.text = "ROUTES COMPLETE"
    var star_index := clampi(stars, 1, 3)
    _result_stars.text = ["", "★☆☆", "★★☆", "★★★"][star_index]
    _result_subtitle.text = "%d GOLD USED   •   BEST %d" % [spent, optimal]
    _result_panel.scale = Vector2(0.92, 0.92)
    var tween := Motion.tween(_result_panel)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(_result_panel, "scale", Vector2.ONE, 0.20)


func _build() -> void:
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    _stats = HBoxContainer.new()
    _stats.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _stats.position = Vector2(-255, 126)
    _stats.size = Vector2(510, 48)
    _stats.alignment = BoxContainer.ALIGNMENT_CENTER
    _stats.add_theme_constant_override("separation", 8)
    _root.add_child(_stats)

    _gold_label = _stat_pill("GOLD  0")
    _spent_label = _stat_pill("SPENT  0")
    _best_label = _stat_pill("BEST  0")
    _stats.add_child(_gold_label)
    _stats.add_child(_spent_label)
    _stats.add_child(_best_label)

    _hint_label = Label.new()
    _hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _hint_label.position = Vector2(-310, -330)
    _hint_label.size = Vector2(620, 38)
    _hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _hint_label.add_theme_font_size_override("font_size", 16)
    _hint_label.add_theme_color_override("font_color", Color("#685E54"))
    _root.add_child(_hint_label)

    _config_panel = PanelContainer.new()
    _config_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _config_panel.position = Vector2(-315, -288)
    _config_panel.size = Vector2(630, 112)
    _config_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _config_panel.add_theme_stylebox_override("panel", _panel_style(Color("#F8EBDDFA"), 22, Color(0,0,0,0.10), 9))
    _root.add_child(_config_panel)

    var config_box := VBoxContainer.new()
    config_box.alignment = BoxContainer.ALIGNMENT_CENTER
    config_box.add_theme_constant_override("separation", 7)
    _config_panel.add_child(config_box)

    _config_title = Label.new()
    _config_title.text = "SORTER"
    _config_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _config_title.add_theme_font_size_override("font_size", 17)
    _config_title.add_theme_color_override("font_color", Color("#514B45"))
    config_box.add_child(_config_title)

    var lane_row := HBoxContainer.new()
    lane_row.alignment = BoxContainer.ALIGNMENT_CENTER
    lane_row.add_theme_constant_override("separation", 8)
    config_box.add_child(lane_row)

    for i in range(3):
        var button := Button.new()
        button.text = "%d   RED" % (i + 1)
        button.custom_minimum_size = Vector2(142, 42)
        button.add_theme_font_size_override("font_size", 15)
        _style_lane_button(button, "red")
        var lane_index := i
        button.pressed.connect(func() -> void: lane_requested.emit(lane_index))
        lane_row.add_child(button)
        _lane_buttons.append(button)

    _remove_button = Button.new()
    _remove_button.text = "REMOVE"
    _remove_button.custom_minimum_size = Vector2(142, 42)
    _remove_button.add_theme_font_size_override("font_size", 13)
    _style_remove_button(_remove_button)
    _remove_button.pressed.connect(func() -> void: remove_requested.emit())
    lane_row.add_child(_remove_button)

    _run_button = Button.new()
    _run_button.text = "RUN"
    _run_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _run_button.position = Vector2(-120, -154)
    _run_button.size = Vector2(240, 56)
    _run_button.mouse_filter = Control.MOUSE_FILTER_STOP
    _run_button.add_theme_font_size_override("font_size", 21)
    _style_run_button(_run_button)
    _run_button.pressed.connect(func() -> void: run_requested.emit())
    _root.add_child(_run_button)

    _result_dim = ColorRect.new()
    _result_dim.color = Color(0.10, 0.08, 0.06, 0.28)
    _result_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _result_dim.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(_result_dim)

    _result_panel = PanelContainer.new()
    _result_panel.set_anchors_preset(Control.PRESET_CENTER)
    _result_panel.position = Vector2(-280, -210)
    _result_panel.size = Vector2(560, 420)
    _result_panel.pivot_offset = Vector2(280, 210)
    _result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _result_panel.add_theme_stylebox_override("panel", _panel_style(Color("#FFF9F2FC"), 30, Color(0,0,0,0.20), 18))
    _root.add_child(_result_panel)

    var result_box := VBoxContainer.new()
    result_box.alignment = BoxContainer.ALIGNMENT_CENTER
    result_box.add_theme_constant_override("separation", 16)
    _result_panel.add_child(result_box)

    _result_title = Label.new()
    _result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _result_title.add_theme_font_size_override("font_size", 30)
    _result_title.add_theme_color_override("font_color", Color("#4D4741"))
    result_box.add_child(_result_title)

    _result_stars = Label.new()
    _result_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _result_stars.add_theme_font_size_override("font_size", 50)
    _result_stars.add_theme_color_override("font_color", Color("#DBA93E"))
    result_box.add_child(_result_stars)

    _result_subtitle = Label.new()
    _result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _result_subtitle.add_theme_font_size_override("font_size", 17)
    _result_subtitle.add_theme_color_override("font_color", Color("#71675D"))
    result_box.add_child(_result_subtitle)

    var next_button := Button.new()
    next_button.text = "NEXT"
    next_button.custom_minimum_size = Vector2(320, 58)
    next_button.add_theme_font_size_override("font_size", 20)
    _style_run_button(next_button)
    next_button.pressed.connect(func() -> void: next_requested.emit())
    result_box.add_child(next_button)

    var replay_button := Button.new()
    replay_button.text = "REPLAY"
    replay_button.custom_minimum_size = Vector2(320, 48)
    replay_button.add_theme_font_size_override("font_size", 16)
    _style_secondary_button(replay_button)
    replay_button.pressed.connect(func() -> void: replay_requested.emit())
    result_box.add_child(replay_button)

    _result_dim.visible = false
    _result_panel.visible = false
    _config_panel.visible = false


func _stat_pill(text_value: String) -> Label:
    var label := Label.new()
    label.text = text_value
    label.custom_minimum_size = Vector2(158, 42)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", Color("#5F574F"))
    label.add_theme_stylebox_override("normal", _panel_style(Color("#F6E7D6E8"), 14, Color(0,0,0,0.06), 3))
    return label


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
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style


func _style_run_button(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#D97858")
    normal.corner_radius_top_left = 18
    normal.corner_radius_top_right = 18
    normal.corner_radius_bottom_left = 18
    normal.corner_radius_bottom_right = 18
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#C7684A")
    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color("#CBB9AA")
    for state in ["normal", "hover", "focus"]:
        button.add_theme_stylebox_override(state, normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", Color("#F1E9E1"))


func _style_lane_button(button: Button, kind: String) -> void:
    var normal := StyleBoxFlat.new()
    var pressed := StyleBoxFlat.new()
    match kind:
        "red":
            normal.bg_color = Color("#F1C0B4")
            pressed.bg_color = Color("#E4A997")
        "blue":
            normal.bg_color = Color("#BDD2E6")
            pressed.bg_color = Color("#A7C1DA")
        "yellow":
            normal.bg_color = Color("#EAD79C")
            pressed.bg_color = Color("#DCC47D")
        _:
            normal.bg_color = Color("#EFE1D1")
            pressed.bg_color = Color("#DCC9B5")

    for style in [normal, pressed]:
        style.corner_radius_top_left = 14
        style.corner_radius_top_right = 14
        style.corner_radius_bottom_left = 14
        style.corner_radius_bottom_right = 14

    for state in ["normal", "hover", "focus"]:
        button.add_theme_stylebox_override(state, normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color("#473F38"))
    button.add_theme_color_override("font_hover_color", Color("#473F38"))
    button.add_theme_color_override("font_pressed_color", Color("#473F38"))


func _style_secondary_button(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#EFE1D1")
    normal.corner_radius_top_left = 14
    normal.corner_radius_top_right = 14
    normal.corner_radius_bottom_left = 14
    normal.corner_radius_bottom_right = 14
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#DCC9B5")
    for state in ["normal", "hover", "focus"]:
        button.add_theme_stylebox_override(state, normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color("#574F47"))
    button.add_theme_color_override("font_hover_color", Color("#574F47"))
    button.add_theme_color_override("font_pressed_color", Color("#574F47"))


func _style_remove_button(button: Button) -> void:
    _style_secondary_button(button)
    button.add_theme_color_override("font_color", Color("#A95E4C"))
    button.add_theme_color_override("font_hover_color", Color("#A95E4C"))
    button.add_theme_color_override("font_pressed_color", Color("#A95E4C"))
