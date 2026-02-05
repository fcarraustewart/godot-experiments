extends BaseEntity

class_name DeathController

# --- BOSS CONFIG ---
@export var WANDER_SPEED = 80.0
@export var CHASE_SPEED = 160.0
@export var AGGRO_RANGE = 500.0

# --- DYNAMICS PARAMETERS (Live Editing) ---
# Separate settings for Skull vs Body for different "weight" feel
@export_group("Skull Dynamics")
@export var skull_f: float = 2.5
@export var skull_z: float = 0.6
@export var skull_r: float = 2.0

@export_group("Joint Dynamics")
@export var joint_f: float = 1.5
@export var joint_z: float = 0.4
@export var joint_r: float = 1.5

# --- OFFSETS (Target relative to Skull) ---
@export_group("Offsets")
@export var skull_center_offset: Vector2 = Vector2(0, -20)
@export var body_target_offset: Vector2 = Vector2(0, 10)
@export var rh_target_offset: Vector2 = Vector2(25, 5)
@export var lh_target_offset: Vector2 = Vector2(-25, 5)

# Visual Nodes
var skull: Sprite2D
var body: Sprite2D
var rh: Sprite2D
var lh: Sprite2D
var sprite: Sprite2D # Compatibility reference for Managers

# Simulation IDs
var skull_sim
var body_sim
var rh_sim
var lh_sim

# --- ATTACK CONFIG ---
@export_group("Death Chains Swarm")
@export var swarm_unit_count: int = 2
@export var swarm_attraction: float = 0.2
@export var swarm_separation: float = 2.0
@export var swarm_frequency: float = 0.8

var death_chains_ctrl
var target_player: Node2D
var wander_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO

func _ready():
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print("!!! DEATH BOSS BOOTING UP !!!")
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	super._ready() # Registers with managers
	add_to_group("Enemy")
	
	# 1. Create Sprite Parts
	skull = _setup_part("res://art/death_skull.png")
	sprite = skull # Set main part as the 'sprite' for managers
	body = _setup_part("res://art/death_bdy.png")
	rh = _setup_part("res://art/death_RH.png")
	lh = _setup_part("res://art/death_LH.png")
	
	# 2. Setup Death Chains Spell
	death_chains_ctrl = load("res://death_chains_controller.gd").new()
	death_chains_ctrl.UNIT_COUNT = swarm_unit_count
	death_chains_ctrl.target_attraction_weight = swarm_attraction
	death_chains_ctrl.separation_weight = swarm_separation
	death_chains_ctrl.freq = swarm_frequency
	
	# Important: Find the root game node or pass a reference
	# For simplicity, we assume the parent or a global is the game node
	death_chains_ctrl.game_node = get_parent()
	add_child(death_chains_ctrl)
	
	# 3. Register with PhysicsManager (SOD)
	if PhysicsManager:
		var start_pos = global_position
		skull_sim = PhysicsManager.register_second_order("Death_Skull_" + str(get_instance_id()), start_pos, skull_f, skull_z, skull_r)
		body_sim  = PhysicsManager.register_second_order("Death_Body_" + str(get_instance_id()), start_pos + body_target_offset, joint_f, joint_z, joint_r)
		rh_sim    = PhysicsManager.register_second_order("Death_RH_" + str(get_instance_id()), start_pos + rh_target_offset, joint_f, joint_z, joint_r)
		lh_sim    = PhysicsManager.register_second_order("Death_LH_" + str(get_instance_id()), start_pos + lh_target_offset, joint_f, joint_z, joint_r)
	print("[DeathController] _ready finished. Parts and Sim IDs created.")

func _setup_part(path: String) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = load(path)
	# Center them relative to their own local space, but we move them globally
	add_child(s)
	return s

func is_enemy(): return true

func _process(delta):
	if Engine.get_frames_drawn() % 30 == 0:
		print("[DeathController] PROCESS_CHECK - Frame: ", Engine.get_frames_drawn())

	state_timer -= delta
	
	# Find target player if needed
	if not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			target_player = players[0]
			print("[DeathController] Found player in group: ", target_player.name)
		elif Engine.get_frames_drawn() % 60 == 0:
			print("[DeathController] WARNING: No player found in 'Player' group.")
			
	_process_ai(delta)
	
	if current_state == State.CASTING:
		velocity = Vector2.ZERO
		if state_timer <= 0:
			change_state(State.RUNNING)
			
	_update_joint_dynamics(delta)
	_update_visuals(delta)

func _process_ai(delta):
	if Engine.get_frames_drawn() % 10 == 0:
		print("--- DEATH AI TICK --- Target: ", is_instance_valid(target_player))
	# Simple Aggro/Chase
	if is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist < AGGRO_RANGE:
			if current_state != State.RUNNING:
				print("[DeathAI] Aggro! Chasing player.")
				change_state(State.RUNNING)
				
			var dir = (target_player.global_position - global_position).normalized()
			velocity = dir * CHASE_SPEED
			facing_right = dir.x > 0
				
			# Attempt to cast Death Chains while chasing
			if death_chains_ctrl:
				if death_chains_ctrl.try_cast(global_position):
					change_state(State.CASTING)
					state_timer = 0.8 # Cast wind-up time
			else:
				print("[DeathAI] ERROR: death_chains_ctrl is NULL")
			return

	# Wander if no player or out of range
	wander_timer -= delta
	if wander_timer <= 0:
		wander_timer = randf_range(1.0, 4.0)
		if randf() > 0.4:
			wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			change_state(State.RUNNING)
		else:
			wander_dir = Vector2.ZERO
			change_state(State.IDLE)
			
	velocity = wander_dir * WANDER_SPEED
	if wander_dir.x != 0:
		facing_right = wander_dir.x > 0

func _update_joint_dynamics(delta):
	if not PhysicsManager: return
	
	# Update simulation parameters for live editing
	PhysicsManager.update_dynamics_for_sim(skull_sim, skull_f, skull_z, skull_r)
	PhysicsManager.update_dynamics_for_sim(body_sim, joint_f, joint_z, joint_r)
	PhysicsManager.update_dynamics_for_sim(rh_sim, joint_f, joint_z, joint_r)
	PhysicsManager.update_dynamics_for_sim(lh_sim, joint_f, joint_z, joint_r)
	
	if death_chains_ctrl:
		death_chains_ctrl.UNIT_COUNT = swarm_unit_count
		death_chains_ctrl.target_attraction_weight = swarm_attraction
		death_chains_ctrl.separation_weight = swarm_separation
		death_chains_ctrl.freq = swarm_frequency

	# Calculate flipped offsets
	var flipped_skull_off = skull_center_offset
	var flipped_body_off = body_target_offset
	var flipped_rh_off = rh_target_offset
	var flipped_lh_off = lh_target_offset
	
	if not facing_right:
		flipped_skull_off.x *= -1
		flipped_body_off.x *= -1
		flipped_rh_off.x *= -1
		flipped_lh_off.x *= -1
	
	# 1. Skull is the "hook" point, following the root node
	var skull_target = global_position + flipped_skull_off
	PhysicsManager.set_second_order_target(skull_sim.id, skull_target)
	skull.global_position = PhysicsManager.get_second_order_pos(skull_sim.id)
	
	# 2. Others follow the Skull (not the root) for child-like floating effect
	var current_skull_pos = skull.global_position
	
	PhysicsManager.set_second_order_target(body_sim.id, current_skull_pos + flipped_body_off - flipped_skull_off)
	PhysicsManager.set_second_order_target(rh_sim.id, current_skull_pos + flipped_rh_off - flipped_skull_off)
	PhysicsManager.set_second_order_target(lh_sim.id, current_skull_pos + flipped_lh_off - flipped_skull_off)
	
	body.global_position = PhysicsManager.get_second_order_pos(body_sim.id)
	rh.global_position    = PhysicsManager.get_second_order_pos(rh_sim.id)
	lh.global_position    = PhysicsManager.get_second_order_pos(lh_sim.id)

func _update_visuals(delta):
	# Handle flipping via scale
	var s = 1.0 if facing_right else -1.0
	skull.scale.x = s
	body.scale.x = s
	rh.scale.x = s
	lh.scale.x = s
	
	# Rotation based on velocity of each part for extra organic feel
	_rotate_part_by_velocity(skull, skull_sim.id, delta, 2.0)
	_rotate_part_by_velocity(body, body_sim.id, delta, 1.0)
	_rotate_part_by_velocity(rh, rh_sim.id, delta, 5.0)
	_rotate_part_by_velocity(lh, lh_sim.id, delta, 5.0)

func _rotate_part_by_velocity(part: Node2D, sim_id: String, delta: float, factor: float):
	var vel = PhysicsManager.get_second_order_velocity(sim_id)
	var tilt = vel.x * 0.002 * factor
	part.rotation = lerp_angle(part.rotation, tilt, 5.0 * delta)

func apply_physics():
	# Inherited character physics (gravity/floor)
	pass

func get_sword_hitbox() -> Rect2:
	# Boss doesn't have a sword attack yet, returning empty box
	return Rect2()
