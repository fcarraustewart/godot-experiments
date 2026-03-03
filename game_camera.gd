extends Camera2D

# GameCamera
# Handles smooth player following with a slight delay (interpolation)

@export var lerp_speed: float = 4.0
@export var target_offset: Vector2 = Vector2(1.0, 64.0)
@export var zoom_lerp_speed: float = 2.0

var target: Node2D
var shake_strength: float = 0.0
var shake_decay: float = 15.0
var base_zoom: Vector2 = Vector2(1.0, 1.0)
var target_zoom: Vector2 = Vector2(1.0, 1.0)

var game_size = Vector2(320, 180) # Should match the logical size of the game viewport
var window_scale = get_viewport().size.x / game_size.x
var actual_cam_pos = global_position

func _process_subpixel_fix(p_target: Node2D, delta: float):
	if not is_instance_valid(p_target) or not Globals.viewport:
		return
		
	# 1. Dynamic Zoom
	zoom = zoom.lerp(target_zoom, zoom_lerp_speed * delta)

	# 2. Screenshake
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		var shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		offset = shake_offset # Camera2D internal offset
	else:
		offset = Vector2.ZERO

	# 3. Mouse Position
	var mouse_pos = (Globals.viewport.get_mouse_position() / window_scale) - (game_size / 2) + p_target.global_position
	
	# Using a lerp, the cameras position is moved towards the mouse position
	var cam_pos = lerp(p_target.global_position, mouse_pos, 0.7)
	
	# Use another lerp to make the movement smooth
	actual_cam_pos = lerp(actual_cam_pos, cam_pos, 5 * delta)
	
	# Calculate the "subpixel" position of the new camera position
	var cam_subpixel_pos = actual_cam_pos.round() - actual_cam_pos
	
	# Update the Main ViewportContainer's shader uniform (Godot 4 uses set_shader_parameter)
	if Globals.viewport_container and Globals.viewport_container.material:
		Globals.viewport_container.material.set_shader_parameter("cam_offset", cam_subpixel_pos)
	
	# Set the camera's position to the new position and round it.
	global_position = actual_cam_pos.round()

func _init():
	print("[CameraDebug] Script _init called.")

func _ready():
	print("[CameraDebug] Script _ready called.")

	game_size = Vector2(320, 180) # Should match the logical size of the game viewport
	window_scale = (get_viewport().size.x / game_size.x)
	actual_cam_pos = global_position
	
	# Initialize zoom to whatever it is in the inspector
	base_zoom = zoom
	target_zoom = base_zoom
	if is_instance_valid(target):
		position = target.position + target_offset

func setup(player_node: Node2D):
	target = player_node
	set_process(true)
	set_physics_process(true)
	print("[CameraDebug] Target setup: ", target != null, " | Processing: ", is_processing())

	if player_node.casting_component:
		# Connect Player Signals for FX
		player_node.casting_component.cast_started.connect(_on_player_cast_start)
		player_node.casting_component.cast_done.connect(_on_player_cast_finished)
		pass
	if target:
		position = target.position + target_offset

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
	
	# 1. Main Follow & Jitter Fix logic
	if is_instance_valid(target):
		# Follow
		var target_pos = target.position + target_offset
		position = position.lerp(target_pos, lerp_speed * delta)
		
		# Jitter Fix (Mouse lean + subpixel offset)
		_process_subpixel_fix(target, delta)
		
		if Engine.get_process_frames() % 120 == 0:
			print("[CameraDebug] Target: %s | CamPos: %s | TargetPos: %s" % [target.name, position, target_pos])
	else:
		# If no target, ensure actual_cam_pos stays in sync to avoid logic jumps if target reappears
		actual_cam_pos = global_position


# Optional: Add screen shake or zoom effects here if needed in the future
func _on_player_cast_start(duration):
	# if spell_id == "sword_attack":
	self.add_shake(12.0)
	self.set_zoom_target(1.15) # Zoom in slightly
	if target.casting_component.active_skill_ctrl:
		var spell_id = ""
		if target.casting_component.active_skill_ctrl.has_method("get_spell_id"):
			spell_id = target.casting_component.active_skill_ctrl.get_spell_id()
		else:
			print("[ShowSpectrum] WARNING: casting_component.active_skill_ctrl has no get_spell_id method.")

		if spell_id == "chain_lightning":
			self.add_shake(12.0)
			self.set_zoom_target(1.15) # Zoom in slightly
		elif spell_id == "fire_chains":
			self.add_shake(18.0)
			self.set_zoom_target(1.2)
		elif spell_id == "meteor_strike":
			self.add_shake(25.0)
			self.set_zoom_target(0.85) # Zoom out for impact!

func _on_player_cast_finished():
	print("[ShowSpectrum] Cast finished, resetting zoom.")
	self.reset_zoom()
