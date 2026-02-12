extends Node

# cleave_swarm_controller.gd
# Specialized swarm-based melee skill for the player.
# Inspired by death_chains but closer range and perspective-based.

@export var DAMAGE = 5.0
@export var UNIT_COUNT = 6
@export var LIFETIME = 0.8
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
	swarm.spawn_radius = 5.0
	swarm.max_speed = 1000.0 # Fast burst
	
	# Swarm behavior weights
	swarm.separation_weight = 1.5
	swarm.alignment_weight = 0.5
	swarm.cohesion_weight = 0.5
	swarm.target_attraction_weight = 0.2
	swarm.frequency = 4.0
	swarm.damping = 0.5
	
	# Visual setup - Use specialized Cleave Swarm Unit
	var unit_packer = PackedScene.new()
	var unit_node = Node2D.new()
	unit_node.set_script(load("res://cleave_swarm_unit.gd"))
	unit_packer.pack(unit_node)
	swarm.unit_scene = unit_packer
	
	game_node.add_child(swarm)
	
	# Spawn from approximate left hand position
	var offset = Vector2(-20, -10) if player.facing_right else Vector2(20, -10)
	var spawn_pos = player.global_position + offset
	swarm.global_position = spawn_pos
	
	# Force spawn units
	swarm.spawn_flock()
	
	# Dir for repulsion
	var move_dir = Vector2.RIGHT if player.facing_right else Vector2.LEFT
	
	# Apply initial repulsion and tweening
	for unit in swarm.members:
		if not is_instance_valid(unit): continue
		
		# Give them a random burst direction in a cone
		var angle = randf_range(-0.5, 0.5)
		var burst = move_dir.rotated(angle) * REPEL_FORCE * randf_range(0.8, 1.2)
		
		# We can't set velocity directly because FlockUnit uses SecondOrderDynamics.
		# But we can set the initial target position far away.
		if unit.has_method("initialize_flock_unit"):
			# Already initialized by swarm, let's nudge the simulation
			var sim_id = unit.id
			var current_pos = unit.global_position
			PhysicsManager.set_second_order_target(sim_id, current_pos + burst)
		
		# Perspective Tweens
		var tween = unit.create_tween().set_parallel(true)
		if type == 1:
			# Cast 1: Front to Back (Shrinks)
			unit.scale = Vector2(1.5, 1.5)
			tween.tween_property(unit, "scale", Vector2(0.3, 0.3), LIFETIME)
			print("[CleaveSwarmCtrl] cast1")
		else:
			# Cast 2: Back to Front (Grows)
			unit.scale = Vector2(0.3, 0.3)
			tween.tween_property(unit, "scale", Vector2(1.5, 1.5), LIFETIME)
			print("[CleaveSwarmCtrl] cast2")
			
		# Fade out
		unit.modulate = Color(1.2, 1.3, 2.0, 1.0) # Glowing white-blue
		tween.tween_property(unit, "modulate:a", 0.0, LIFETIME)
		
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
