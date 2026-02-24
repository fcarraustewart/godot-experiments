extends Node2D

class_name AimComponent

## AimComponent
## Handles all aiming mouse → game interaction dispatch for the player.
## Called from PlayerController._on_aim_update() — keeps the match block out of PlayerController.
var _player: PlayerController
var is_active: bool
var aim_direction: Vector2
var aim_indicator: Node2D

func _on_aim_direction_changed(direction):
	aim_direction = direction

func _init(player: PlayerController) -> void:
	_player = player

func _ready():
	aim_direction = Vector2.RIGHT
	aim_indicator = Node2D.new()
	if _player: 
		_setup_visuals(_player)
		if _player.action_component:
			_player.action_component.aim_direction_changed.connect(_on_aim_direction_changed)
			print("[AimComponent] Connected to ActionComponent signals.")
		else:
			print("[AimComponent] Warning: PlayerController has no ActionComponent. AimComponent will be inactive.")
			is_active = false
			return
		is_active = true
		aim_indicator.visible = true
		aim_indicator.scale = Vector2(0.5, 0.5)	
		print("[AimComponent] Initialized and connected to ActionComponent signals.")
	else:
		is_active = false

func _setup_visuals(parent):
# --- AIM INDICATOR Visuals ---
# tab space fix
	var aim_arrow_line = Line2D.new()
	aim_arrow_line.points = PackedVector2Array([Vector2(50,0), Vector2(42.5, -5), Vector2(50,0), Vector2(42.5, 5)])
	aim_arrow_line.width = 3.0
	aim_arrow_line.default_color = Color(1.0, 1.0, 4.0, 1.6)
	aim_indicator.add_child(aim_arrow_line)
	parent.add_child(aim_indicator)

func update():
	var dir = Vector2.ZERO 
	if _player.casting_component: 
		dir = _player.casting_component.casting_direction if _player.current_state == BaseEntity.State.CASTING else aim_direction
	else:
		dir = aim_direction
	aim_indicator.rotation = (dir).angle()
