extends Camera2D

# GameCamera
# Handles smooth player following with a slight delay (interpolation)

@export var lerp_speed: float = 4.0
@export var target_offset: Vector2 = Vector2.ZERO
@export var zoom_lerp_speed: float = 2.0

var target: Node2D
var shake_strength: float = 0.0
var shake_decay: float = 15.0
var base_zoom: Vector2 = Vector2(1.0, 1.0)
var target_zoom: Vector2 = Vector2(1.0, 1.0)

func _init():
	print("[CameraDebug] Script _init called.")

func _ready():
	print("[CameraDebug] Script _ready called.")
	# Initialize zoom to whatever it is in the inspector
	base_zoom = zoom
	target_zoom = base_zoom
	if is_instance_valid(target):
		global_position = target.global_position + target_offset

func setup(player_node: Node2D):
	target = player_node
	set_process(true)
	set_physics_process(true)
	print("[CameraDebug] Target setup: ", target != null, " | Processing: ", is_processing())
	if target:
		global_position = target.global_position + target_offset

func add_shake(strength: float):
	shake_strength = strength

func set_zoom_target(zoom_val: float):
	target_zoom = Vector2(zoom_val, zoom_val)

func reset_zoom():
	target_zoom = base_zoom

var _first_frame_done = false

func _process(delta):
	delta = float(delta)
	if not _first_frame_done:
		print("[CameraDebug] First frame of _process! Target valid: ", is_instance_valid(target))
		_first_frame_done = true
		
	# Enforce enabled state
	enabled = true
	
	# 1. Smooth Follow
	if is_instance_valid(target):
		var target_pos = target.position + target_offset
		position = position.lerp(target_pos, lerp_speed * delta)
		
		if Engine.get_process_frames() % 120 == 0:
			print("[CameraDebug] Target: %s | CamPos: %s | TargetPos: %s" % [target.name, position, target_pos])
	
	# 2. Dynamic Zoom
	zoom = zoom.lerp(target_zoom, zoom_lerp_speed * delta)
	
	# 3. Screenshake
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		var shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		offset = shake_offset # Camera2D internal offset
	else:
		offset = Vector2.ZERO


# Optional: Add screen shake or zoom effects here if needed in the future
