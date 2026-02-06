extends Node

# death_chains_controller.gd
# Specialized version of fire chains for the Death boss.
# Spawns a flocking swarm that tracks the target, with chains linking the boss to each swarm unit.

# --- SETTINGS ---
@export var COOLDOWN_MAX = 8.0
var cooldown = 0.0
@export var RANGE = 600.0
@export var DURATION = 8.0 # How long the swarm/chains last
@export var UNIT_COUNT = 20

@export_group("Swarm Behavior")
@export var separation_weight: float = 0.5/20
@export var alignment_weight: float = -1.50/20
@export var cohesion_weight: float = 2.0/10
@export var target_attraction_weight: float = 0.2 # Lazier tracking
@export var freq: float = 15.8 # Slightly faster than 0.005 so they move, but still slow
@export var damp: float = 0.009
@export var resp: float = 0.4

var launch_timer: float = 0.0
const LAUNCH_TIME = 1.5 # 1 second launch phase

var game_node: Node2D
var is_casting = false
var cast_timer = 0.0
var current_target: Node2D = null
var current_swarm: BaseFlockSwarm = null

# List of visual links and their associated physics bodies and swarm units
var active_visual_chains = []

func _ready():
	# Note: We don't use DataManager here as this is a custom boss script, 
	# but we could if we added "death_chains" to spells.json
	pass

func _exit_tree():
	stop_all_chains()
	if is_instance_valid(current_swarm):
		current_swarm.queue_free()

func stop_all_chains():
	for c in active_visual_chains:
		if c.has("physics_body"):
			PhysicsManager.unregister_object(c.physics_body)
		if is_instance_valid(c.line):
			c.line.queue_free()
	active_visual_chains.clear()
	if is_instance_valid(current_swarm):
		current_swarm.queue_free()
		current_swarm = null

func _process(delta):
	if cooldown > 0:
		cooldown -= delta
		
	_update_visuals(delta)
	
	# Live Parameter Syncing & Launch Logic
	if is_instance_valid(current_swarm):
		if launch_timer > 0:
			launch_timer -= delta
			current_swarm.target_node = get_parent()
			current_swarm.target_attraction_weight = -0.05 # Repel from boss
			if Engine.get_frames_drawn() % 60 == 0:
				print("[DeathChains] Launching... timer: ", launch_timer)
		else:
			if current_swarm.target_node != current_target:
				print("[DeathChains] Launch finished. Switching to player.")
				current_swarm.target_node = current_target
			
			current_swarm.target_attraction_weight = target_attraction_weight # 0.5
		
		# Sync other parameters
		current_swarm.separation_weight = separation_weight
		current_swarm.alignment_weight = alignment_weight
		current_swarm.cohesion_weight = cohesion_weight
		current_swarm.frequency = freq
		current_swarm.damping = damp
		current_swarm.response = resp
	# Damage logic for swarm units
	if is_instance_valid(current_swarm) and is_instance_valid(current_target):
		for unit in current_swarm.members:
			if is_instance_valid(unit) and unit.global_position.distance_to(current_target.global_position) < 30.0:
				# Deal periodic small damage
				if CombatManager:
					CombatManager.request_interaction(get_parent(), current_target, "damage", {"amount": 0.05})

func _physics_process(delta):
	# CRITICAL: Anchors must be updated in physics process to sync with the solver
	for i in range(active_visual_chains.size() - 1, -1, -1):
		var c = active_visual_chains[i]
		if not is_instance_valid(c.unit) or not is_instance_valid(get_parent()):
			continue
			
		var body = c.physics_body
		
		# 1. Update Anchors
		var boss_pos = get_parent().global_position
		if "skull" in get_parent() and is_instance_valid(get_parent().skull):
			boss_pos = get_parent().skull.global_position
			
		var unit_pos = c.unit.global_position
		
		body.anchors[0] = boss_pos
		body.anchors[body.points.size() - 1] = unit_pos

func try_cast(start_pos: Vector2) -> bool:
	if cooldown <= 0 and not is_casting:
		var target = CombatManager.get_nearest_target(start_pos, RANGE, get_parent(), CombatManager.Faction.PLAYER)
		if target:
			print("[DeathChains] Initiating Cast on: ", target.name)
			current_target = target
			is_casting = true
			fire_death_chains()
			return true
		else:
			# Only print periodically to avoid log spam
			if Engine.get_frames_drawn() % 60 == 0:
				print("[DeathChains] No target found in range: ", RANGE)
	return false

func fire_death_chains():
	print("[DeathChains] FIRING! Spawning swarm with ", UNIT_COUNT, " units.")
	if not game_node or not current_target: 
		is_casting = false
		return
	is_casting = false
	cooldown = COOLDOWN_MAX
	
	# 1. Create the Swarm
	current_swarm = BaseFlockSwarm.new()
	current_swarm.unit_count = UNIT_COUNT
	current_swarm.spawn_radius = 60.0 # Spread units around the boss
	current_swarm.separation_weight = separation_weight
	current_swarm.alignment_weight = alignment_weight
	current_swarm.cohesion_weight = cohesion_weight
	current_swarm.target_attraction_weight = target_attraction_weight
	current_swarm.damping = damp
	current_swarm.response = resp
	current_swarm.max_speed = 600.0 # Limit speed for Death Swarm specifically
	
	# INITIAL LAUNCH STATE
	launch_timer = LAUNCH_TIME
	current_swarm.target_node = get_parent() # Start with death itself
	current_swarm.target_attraction_weight = -5.5 # Repel
	
	# Determine spawn center (Skull)
	var boss_pos = get_parent().global_position
	if "skull" in get_parent() and is_instance_valid(get_parent().skull):
		boss_pos = get_parent().skull.global_position
	
	# Package a simple red visual for the units
	var unit_packer = PackedScene.new()
	var unit_node = Node2D.new()
	unit_node.set_script(load("res://death_swarm_unit.gd"))
	
	# Add red visual to unit
	var visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([Vector2(0,-4), Vector2(4,0), Vector2(0,4), Vector2(-4,0)])
	visual.color = Color(1, 1, 1, 26.08) # Glowing red
	unit_node.add_child(visual)
	
	unit_packer.pack(unit_node)
	current_swarm.unit_scene = unit_packer
	
	current_swarm.global_position = boss_pos
	game_node.add_child(current_swarm)
	
	# 2. Spawn one chain per unit
	# Swarm spawn happens in _ready of swarm, but we need the units now.
	# We force spawn_flock if it hasn't happened.
	if current_swarm.members.is_empty():
		current_swarm.spawn_flock()
		
	var skull_pos = get_parent().global_position
	if "skull" in get_parent() and is_instance_valid(get_parent().skull):
		skull_pos = get_parent().rh.global_position
		
	for unit in current_swarm.members:
		_spawn_physics_chain(skull_pos, unit)

func _spawn_physics_chain(start_pos: Vector2, unit: Node2D):
	var line = Line2D.new()
	line.width = 30.0 
	line.texture = load("res://art/fire_chain.png")
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.modulate = Color(1, 1, 1, 20.7) # Blood Red tint
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://fire_chain.gdshader")
	mat.set_shader_parameter("tiling", 8.0)
	line.material = mat
	game_node.add_child(line)
	line.global_position = Vector2.ZERO # Force line to world origin so point math works

	var num_points = 4 # FEWER POINTS = Snappier tracking at slow speeds
	var points = []
	var start_anchor = start_pos
	var end_target = unit.global_position
	
	for j in range(num_points):
		var t = float(j) / (num_points - 1.0)
		var p = start_anchor.lerp(end_target, t)
		points.append(p)

	var body = PhysicsManager.register_soft_body("death_chain_" + str(line.get_instance_id()), points, 30.0) # Higher stiffness
	
	active_visual_chains.append({
		"line": line,
		"unit": unit,
		"physics_body": body,
		"timer": DURATION
	})

func _update_visuals(delta):
	for i in range(active_visual_chains.size() - 1, -1, -1):
		var c = active_visual_chains[i]
		var body = c.physics_body
		c.timer -= delta
		
		if c.timer <= 0 or not is_instance_valid(c.unit) or not is_instance_valid(get_parent()):
			PhysicsManager.unregister_object(body)
			c.line.queue_free()
			active_visual_chains.remove_at(i)
			continue

		# Map Physics to Line
		c.line.clear_points()
		for j in range(body.points.size()):
			var p = body.points[j]
			# Add small wavy effect
			var t = float(j) / (body.points.size() - 1)
			var wave = sin(Time.get_ticks_msec() * 0.01 + t * 5.0) * 2.0
			c.line.add_point(p + Vector2(0, wave))
		
	# Clean up swarm if all chains are gone
	if active_visual_chains.is_empty() and is_instance_valid(current_swarm):
		current_swarm.queue_free()
		current_swarm = null
