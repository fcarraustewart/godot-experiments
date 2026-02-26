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
@export var separation_weight: float = 0.5
@export var alignment_weight: float = -1.50
@export var cohesion_weight: float = 2.0
@export var target_attraction_weight: float = 0.2
@export var freq: float = 4.5
@export var damp: float = 0.1
@export var resp: float = 0.4

var launch_timer: float = 0.0
const LAUNCH_TIME = 1.5

var game_node: Node2D
var is_casting = false
var cast_timer = 0.0
var current_target: Node2D = null
var current_swarm: BaseFlockSwarm = null

# List of visual links
var active_visual_chains = []

func _ready():
	pass

func _exit_tree():
	stop_all_chains()

func stop_all_chains():
	for c in active_visual_chains:
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
	
	if is_instance_valid(current_swarm):
		if launch_timer > 0:
			launch_timer -= delta
			current_swarm.set_target_node(get_parent())
			current_swarm.target_attraction_weight = -0.5
		else:
			current_swarm.set_target_node(current_target)
			current_swarm.target_attraction_weight = target_attraction_weight
		
		# Sync other parameters
		current_swarm.separation_weight = separation_weight
		current_swarm.alignment_weight = alignment_weight
		current_swarm.cohesion_weight = cohesion_weight
		current_swarm.frequency = freq
		current_swarm.damping = damp
		current_swarm.response = resp

	# Damage logic using native positions
	if is_instance_valid(current_swarm) and is_instance_valid(current_target):
		var count = current_swarm.get_unit_count()
		for i in range(count):
			var pos = current_swarm.get_unit_position(i)
			if pos.distance_to(current_target.global_position) < 30.0:
				if CombatManager:
					CombatManager.request_interaction(get_parent(), current_target, "damage", {"amount": 0.05})

func _physics_process(_delta):
	pass # No longer need to update physics body anchors manually

func try_cast(start_pos: Vector2) -> bool:
	if cooldown <= 0 and not is_casting:
		var target = CombatManager.get_nearest_target(start_pos, RANGE, get_parent(), CombatManager.Faction.PLAYER)
		if target:
			current_target = target
			is_casting = true
			return true
	return false

func fire_death_chains():
	if not game_node or not current_target: 
		is_casting = false
		return
	is_casting = false
	cooldown = COOLDOWN_MAX
	
	current_swarm = BaseFlockSwarm.new()
	current_swarm.unit_count = UNIT_COUNT
	current_swarm.spawn_radius = 60.0
	current_swarm.separation_weight = separation_weight
	current_swarm.alignment_weight = alignment_weight
	current_swarm.cohesion_weight = cohesion_weight
	current_swarm.target_attraction_weight = target_attraction_weight
	current_swarm.frequency = freq
	current_swarm.damping = damp
	current_swarm.response = resp
	current_swarm.max_speed = 600.0
	
	current_swarm.texture = load("res://art/death_RH.png") # Using RH texture as unit visual
	current_swarm.unit_mesh_scale = Vector2(0.4, 0.4)
	current_swarm.use_colors = true
	
	launch_timer = LAUNCH_TIME
	current_swarm.set_target_node(get_parent())
	
	var boss_pos = get_parent().global_position
	if "skull" in get_parent() and is_instance_valid(get_parent().skull):
		boss_pos = get_parent().skull.global_position
	
	current_swarm.global_position = boss_pos
	game_node.add_child(current_swarm)
	
	# Spawn one line per unit
	for i in range(UNIT_COUNT):
		_spawn_visual_chain(i)

func _spawn_visual_chain(index: int):
	var line = Line2D.new()
	line.width = 15.0 
	line.texture = load("res://art/fire_chain.png")
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.modulate = Color(1, 0.2, 0.2, 0.8)
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://fire_chain.gdshader")
	mat.set_shader_parameter("tiling", 8.0)
	line.material = mat
	game_node.add_child(line)
	line.global_position = Vector2.ZERO

	active_visual_chains.append({
		"line": line,
		"index": index,
		"timer": DURATION
	})

func _update_visuals(delta):
	var boss_pos = get_parent().global_position
	if "skull" in get_parent() and is_instance_valid(get_parent().skull):
		boss_pos = get_parent().skull.global_position
			
	for i in range(active_visual_chains.size() - 1, -1, -1):
		var c = active_visual_chains[i]
		c.timer -= delta
		
		if c.timer <= 0 or not is_instance_valid(current_swarm) or not is_instance_valid(get_parent()):
			c.line.queue_free()
			active_visual_chains.remove_at(i)
			continue

		var unit_pos = current_swarm.get_unit_position(c.index)
		
		c.line.clear_points()
		var num_pts = 4
		for j in range(num_pts):
			var t = float(j) / (num_pts - 1)
			var p = boss_pos.lerp(unit_pos, t)
			var wave = sin(Time.get_ticks_msec() * 0.01 + t * 5.0 + c.index) * 5.0
			c.line.add_point(p + Vector2(0, wave))
		
	if active_visual_chains.is_empty() and is_instance_valid(current_swarm):
		current_swarm.queue_free()
		current_swarm = null
