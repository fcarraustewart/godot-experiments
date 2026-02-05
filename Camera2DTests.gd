extends Camera2D

# Flock swarm test spawner
var icon = preload("res://swarm_test.tscn")
@export var swarm_params: FlockParams = FlockParams.new()


# example repulsion
# unit_cnt = 20
# spawn_radius = 1.0
# separation_wt = 0.01
# alignment_wt = 0.001
# cohesion_wt = 0.05
# t_attraction_wt = -0.6

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Track active swarms to update them in real-time
var active_swarms: Array[BaseFlockSwarm] = []

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
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
			
	if Input.is_action_just_pressed("mouse"):
		print("spawn swarm AT MOUSE")
		var icon_instance = icon.instantiate()
		get_parent().add_child(icon_instance)
		icon_instance.position = get_global_mouse_position()

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
		
		# --- Initialize Flock ---
		# We need to package the unit script as a PackedScene, or just assign it if the script handles new()
		# Since base_flock_swarm expects a PackedScene, let's create a temporary one or modify it to accept scripts
		# For now, let's just make a dummy packed scene wrapper
		var unit_packer = PackedScene.new()
		var unit_node = Node2D.new()
		unit_node.set_script(load("res://flock_unit.gd"))
		unit_packer.pack(unit_node)
		swarm.unit_scene = unit_packer
		
		swarm.target_node = icon_instance.get_child(0) # Follow the axe
		swarm.target_node.add_child(swarm)
		
		active_swarms.append(swarm)

		var tween = create_tween()
		tween.parallel().tween_property(swarm, "modulate:a", 0.0, 3.5)
		tween.parallel().tween_property(swarm, "scale", Vector2(3.5, 3.5), 3.5)
		tween.tween_callback(icon_instance.queue_free)

	# Clean up invalid swarms
	for i in range(active_swarms.size() - 1, -1, -1):
		if not is_instance_valid(active_swarms[i]):
			active_swarms.remove_at(i)
	pass
