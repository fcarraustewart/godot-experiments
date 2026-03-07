extends Camera2D

# Flock swarm test spawner
@export var spawn_unit: PackedScene
@export var swarm_params: FlockParams = FlockParams.new()

var actual_cam_pos : Vector2
const lerp_speed = 10.0

func _ready_viewport_container_subpixel_fix():
	var vp = get_viewport()
	Globals.viewport = vp
	
	if vp is SubViewport:
		var parent = vp.get_parent()
		if parent is SubViewportContainer:
			Globals.viewport_container = parent
			print("[Camera2D] Subpixel fix: Identified parent SubViewportContainer.")
		else:
			print("[Camera2D] Subpixel fix: Running in SubViewport, but parent is not a Container.")
	else:
		print("[Camera2D] Subpixel fix: Running in root viewport.")
		
# Called when the node enters the scene tree for the first time.
func _ready():
	_ready_viewport_container_subpixel_fix()
	pass # Replace with function body.

# Track active swarms to update them in real-time
var active_swarms: Array[BaseFlockSwarm] = []

# Called every frame. 'delta' is the elapsed time since the previous frame.
func process_subpixel_fix(delta):
	actual_cam_pos = actual_cam_pos.lerp($"../Player".global_position, lerp_speed * delta)
	var cam_subpixel_offset = actual_cam_pos.round() - actual_cam_pos
	Globals.viewport_container.material.set_shader_parameter("camera_offset", cam_subpixel_offset)

	global_position = actual_cam_pos.round()
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	process_subpixel_fix(delta)
	# position = position + sin(delta * TAU) * 50 * Vector2(1, 0)
	
	# LIVE UPDATE: Apply editor properties to all active swarms
	if swarm_params:
		for s in active_swarms:
			if is_instance_valid(s):
				# Flocking
				s.separation_weight = swarm_params.separation_weight
				s.alignment_weight = swarm_params.alignment_weight
				s.cohesion_weight = swarm_params.cohesion_weight
				s.target_attraction_weight = swarm_params.target_attraction_weight
				s.perception_radius = swarm_params.perception_radius
				# Frquency/Damping/Response
				s.frequency = swarm_params.frequency
				s.damping = swarm_params.damping
				s.response = swarm_params.response
				# Visual
				s.unit_count = swarm_params.unit_count
				s.spawn_radius = swarm_params.spawn_radius
				s.debug_mode = swarm_params.debug_mode
				s.sway_strength = swarm_params.sway_strength
				s.sway_speed = swarm_params.sway_speed
			
	if Input.is_action_just_pressed("mouse"):
		if not spawn_unit:
			print("No spawn_unit assigned to Camera2DTests!")
			return
		print("spawn swarm AT MOUSE")
		var icon_instance = spawn_unit.instantiate()
		get_parent().add_child(icon_instance)
		icon_instance.global_position = get_global_mouse_position()
		icon_instance.apply_impulse(700*Vector2.RIGHT, icon_instance.global_position)# Ensure the script is attached to the instance


		# ---- SETUP FLOCK ---
		var swarm = BaseFlockSwarm.new()
		# Flocking
		swarm.separation_weight = swarm_params.separation_weight
		swarm.alignment_weight = swarm_params.alignment_weight
		swarm.cohesion_weight = swarm_params.cohesion_weight
		swarm.target_attraction_weight = swarm_params.target_attraction_weight
		swarm.perception_radius = swarm_params.perception_radius
		# Visual
		swarm.unit_count = swarm_params.unit_count
		swarm.spawn_radius = swarm_params.spawn_radius
		# Dynamics
		swarm.frequency = swarm_params.frequency
		swarm.damping = swarm_params.damping
		swarm.response = swarm_params.response
		# Spawn on position mouse click
		swarm.position = icon_instance.position 
		
		# Visual
		# swarm.texture = load("res://art/environment/leaf/leaf1.png")
		swarm.debug_mode = true
		swarm.target_node = icon_instance # Follow the axe
		swarm.target_node.get_parent().add_child(swarm)
		
		active_swarms.append(swarm)

		var tween = create_tween()
		tween.parallel().tween_property(swarm, "modulate:a", 0.0, 3.5)

		tween.tween_callback(swarm.queue_free)
		tween.tween_callback(icon_instance.queue_free)

	# Clean up invalid swarms
	for i in range(active_swarms.size() - 1, -1, -1):
		if not is_instance_valid(active_swarms[i]):
			active_swarms.remove_at(i)
	pass
