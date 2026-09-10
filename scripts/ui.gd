extends CanvasLayer

@export var manager_path: NodePath
@onready var manager: GameManager = get_node(manager_path)

func _ready() -> void:
	$Bottom/Wood.pressed.connect(func(): _select(GameManager.AmmoType.WOOD))
	$Bottom/Stone.pressed.connect(func(): _select(GameManager.AmmoType.STONE))
	$Bottom/Fire.pressed.connect(func(): _select(GameManager.AmmoType.FIRE))
	$Bottom/Wild.pressed.connect(func(): _select(GameManager.AmmoType.WILD))
	$WinPanel/Center/Box/Retry.pressed.connect(_reload)
	$LosePanel/Center/Box/Retry.pressed.connect(_reload)

func _select(type: int) -> void:
	manager.set_selected_ammo(type)

func _reload() -> void:
	get_tree().reload_current_scene()
