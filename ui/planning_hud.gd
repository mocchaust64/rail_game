class_name PlanningHud
extends CanvasLayer

signal run_requested

var _root: Control
var _title: Label
var _run_button: Button


func _ready() -> void:
    _build()


func show_planning() -> void:
    if _root == null:
        return
    _root.visible = true
    _title.text = "SET ROUTES"
    _run_button.disabled = false
    _run_button.text = "RUN"


func show_running() -> void:
    if _root == null:
        return
    _root.visible = false


func _build() -> void:
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    panel.position = Vector2(-155, -168)
    panel.size = Vector2(310, 102)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _panel_style())
    _root.add_child(panel)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 8)
    panel.add_child(box)

    _title = Label.new()
    _title.text = "SET ROUTES"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 17)
    _title.add_theme_color_override("font_color", Color("#5A5148"))
    box.add_child(_title)

    _run_button = Button.new()
    _run_button.text = "RUN"
    _run_button.custom_minimum_size = Vector2(220, 50)
    _run_button.mouse_filter = Control.MOUSE_FILTER_STOP
    _run_button.add_theme_font_size_override("font_size", 21)
    _style_run_button(_run_button)
    _run_button.pressed.connect(func() -> void: run_requested.emit())
    box.add_child(_run_button)


func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#F7E9D9E8")
    style.corner_radius_top_left = 24
    style.corner_radius_top_right = 24
    style.corner_radius_bottom_left = 24
    style.corner_radius_bottom_right = 24
    style.shadow_color = Color(0, 0, 0, 0.08)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 4)
    style.content_margin_left = 18
    style.content_margin_right = 18
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
    normal.content_margin_top = 10
    normal.content_margin_bottom = 10
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#C8684A")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", normal)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
