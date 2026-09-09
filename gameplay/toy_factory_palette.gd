class_name ToyFactoryPalette
extends Resource
# The game's colours as data.
#
# These used to be constants in visual_factory.gd, which meant nobody without
# GDScript could change how the game looks. As a resource they can be edited in
# the inspector, and a second palette can be made without touching code.

@export_group("Board")
@export var floor_colour: Color = Color("#C6D3D9")
@export var floor_edge: Color = Color("#AEBFC8")
@export var floor_inset: Color = Color("#D5E1E7")
@export var rail: Color = Color("#E9F0F3")

@export_group("Belt")
@export var belt: Color = Color("#28384C")
@export var belt_inner: Color = Color("#51677C")
@export var belt_slat: Color = Color("#6E8294")

@export_group("Machines")
@export var machine_body: Color = Color("#F7F9FB")
@export var machine_dark: Color = Color("#26384C")

@export_group("Cargo")
## Changing these breaks the colour coding the game is built on. They are
## deliberately exposed anyway, for a colourblind palette.
@export var cargo_red: Color = Color("#F45B69")
@export var cargo_blue: Color = Color("#4F8EF7")
@export var cargo_yellow: Color = Color("#F4C542")

@export_group("Accents")
@export var accent_green: Color = Color("#59D3A5")
@export var accent_orange: Color = Color("#FF9B62")


func cargo_colour(kind: String) -> Color:
    match kind:
        "red": return cargo_red
        "blue": return cargo_blue
        "yellow": return cargo_yellow
        _: return Color.WHITE
