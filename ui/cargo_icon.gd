class_name CargoIcon
extends Control

var kind: String = ""
var filled: bool = false
var alpha: float = 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if custom_minimum_size == Vector2.ZERO:
        custom_minimum_size = Vector2(54, 54)

func set_kind(value: String, is_filled: bool = true, opacity: float = 1.0) -> void:
    kind = value
    filled = is_filled
    alpha = opacity
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.29
    var color := VisualFactory.kind_color(kind)
    color.a *= alpha
    var outline := Color("#203044")
    outline.a = 0.22 * alpha

    if not filled or kind.is_empty():
        var empty := Color("#B9C8D2")
        empty.a = 0.42 * alpha
        draw_circle(center, radius * 0.22, empty)
        return

    match kind:
        "red":
            draw_circle(center + Vector2(0, 2), radius, outline)
            draw_circle(center, radius * 0.92, color)
            draw_circle(center - Vector2(radius * 0.28, radius * 0.30), radius * 0.15, Color(1, 1, 1, 0.42 * alpha))
        "blue":
            var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
            var outline_rect := rect.grow(radius * 0.08)
            draw_style_box(_rounded_box(outline, radius * 0.28), outline_rect)
            draw_style_box(_rounded_box(color, radius * 0.24), rect)
            draw_circle(center - Vector2(radius * 0.28, radius * 0.30), radius * 0.12, Color(1, 1, 1, 0.34 * alpha))
        "yellow":
            var points := PackedVector2Array([
                center + Vector2(0, -radius * 1.08),
                center + Vector2(radius * 1.00, radius * 0.82),
                center + Vector2(-radius * 1.00, radius * 0.82),
            ])
            var outline_points := PackedVector2Array()
            for p in points:
                outline_points.append(center + (p - center) * 1.08 + Vector2(0, 2))
            draw_colored_polygon(outline_points, outline)
            draw_colored_polygon(points, color)
            draw_circle(center + Vector2(-radius * 0.16, -radius * 0.30), radius * 0.11, Color(1, 1, 1, 0.34 * alpha))
        _:
            draw_circle(center, radius, color)

func _rounded_box(color: Color, radius: float) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    var r := int(max(1.0, radius))
    box.corner_radius_top_left = r
    box.corner_radius_top_right = r
    box.corner_radius_bottom_left = r
    box.corner_radius_bottom_right = r
    return box
