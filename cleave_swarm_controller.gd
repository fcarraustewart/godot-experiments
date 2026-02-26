extends Node

# cleave_swarm_controller.gd
# Specialized swarm-based melee skill for the player.
# Inspired by death_chains but closer range and perspective-based.

@export var DAMAGE = 5.0
@export var UNIT_COUNT = 64
@export var LIFETIME = 1.8
@export var REPEL_FORCE = 400.0

var game_node: Node2D
var player: PlayerController

func _ready():
	player = get_parent()

func cast_cleave(type: int):
	if not game_node: 
		game_node = get_parent().get_parent() # Fallback
	
	var swarm = BaseFlockSwarm.new()
	swarm.unit_count = UNIT_COUNT
	swarm.spawn_radius = 100.0
	swarm.max_speed = 1000.0 # Fast burst
	
	# Swarm behavior weights
	swarm.separation_weight = 0.0
	swarm.alignment_weight = -2.05
	swarm.cohesion_weight = 4.05
	swarm.target_attraction_weight = -10.2
	swarm.frequency = 0.520
	swarm.damping = 1.0
	swarm.response = 0.0
	
	# Visual setup
	# swarm.texture = load("res://art/environment/leaf/leaf1.png")
	swarm.unit_mesh_scale = Vector2(0.2, 0.2)
	swarm.use_colors = true
	swarm.debug_mode = true
	
	game_node.add_child(swarm)

	# Spawn from approximate left hand position
	var offset = Vector2(1, -1) if player.facing_right else Vector2(-1, -1)
	var spawn_pos = player.global_position + offset
	swarm.global_position = spawn_pos
	

	swarm.spawn_flock()
	
	# Dispersion Tween for visuals
	var t = create_tween()
	t.parallel().tween_property(swarm, "unit_scale", 2.0, LIFETIME)
	t.parallel().tween_property(swarm, "modulate:a", 0.5, LIFETIME)
	t.parallel().tween_property(swarm, "target_attraction_weight", 0.9, LIFETIME * 0.5)
	
	# Dir for repulsion
	var move_dir = Vector2.RIGHT if player.facing_right else Vector2.LEFT
	
	# For NativeSwarmManager, we'd need a way to set initial velocities or targets per unit
	# For now, let's just use the swarm logic.
	# If we want the scale/color tweens, we need to expose them in C++.
	
	# Perspective Tweens - This won't work easily with MultiMesh unless we animate uniform arrays.
	# For this task, we focus on the physics migration.

		
	# Immediate Cleave Damage in front of player
	_apply_cleave_damage()

	# Cleanup swarm after lifetime
	get_tree().create_timer(LIFETIME).timeout.connect(func(): if is_instance_valid(swarm): swarm.queue_free())

func _apply_cleave_damage():
	var forward = Vector2.RIGHT if player.facing_right else Vector2.LEFT
	var cleave_origin = player.global_position + forward * 30.0
	
	# Find enemies in range
	var enemies = get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = cleave_origin.distance_to(enemy.global_position)
			if dist < 120.0: # Cleave range
				# Check if in front (dot product)
				var to_enemy = (enemy.global_position - player.global_position).normalized()
				if to_enemy.dot(forward) > 0.5: # 60 degree cone
					if CombatManager:
						CombatManager.request_interaction(player, enemy, "damage", {"amount": DAMAGE})
						print("Cleave hit enemy: ", enemy.name)
