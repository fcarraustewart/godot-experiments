extends Node

# arcane_missiles.gd
# Logic for spawning arcane missiles that seek a target using Native Swarm.

@export var DAMAGE = 8.0
@export var UNIT_COUNT = 3
@export var LIFETIME = 3.50
@export var SPEED = 100.0

var game_node: Node2D
var host: Node2D

func _ready():
	host = get_parent()


func cast_missiles(target: Node2D):
	if not is_instance_valid(target): return
	
	if not game_node:
		game_node = host.get_parent()
		
	var swarm = BaseFlockSwarm.new()
	swarm.unit_count = UNIT_COUNT
	swarm.spawn_radius = 20.0
	swarm.max_speed = SPEED
	
	swarm.separation_weight = -0.5
	swarm.alignment_weight = 1.0
	swarm.cohesion_weight = 1.5
	swarm.target_attraction_weight = 8.0
	swarm.frequency = 0.35
	swarm.damping = 0.1
	swarm.response = 0.12
	
	swarm.texture = load("res://art/barbudo32p32p/ArcaneMissile.png") # TODO: Arcane missile texture
	swarm.unit_mesh_scale = Vector2(0.4, 0.4)
	swarm.use_colors = true
	swarm.debug_mode = false
	swarm.set_target_node(target)
	
	swarm.global_position = host.global_position + Vector2(0, -30)
	swarm.add_to_group("ArcaneMissile")
	game_node.add_child(swarm)
	swarm.spawn_flock()
	
	var thinker = MissileThinker.new()
	swarm.add_child(thinker)
	thinker.setup(swarm, target, DAMAGE, LIFETIME)

class MissileThinker extends Node:
	var swarm: BaseFlockSwarm
	var target: Node2D
	var damage: float
	var lifetime: float
	var timer = 0.0
	var hit_cooldown = 0.0
	
	func setup(p_swarm, p_target, p_damage, p_lifetime):
		swarm = p_swarm
		target = p_target
		damage = p_damage
		lifetime = p_lifetime
	func impact():
		if is_instance_valid(swarm): swarm.queue_free()

	func _process(delta):
		timer += delta
		if timer > lifetime or not is_instance_valid(swarm):
			if is_instance_valid(swarm): swarm.queue_free()
			return
			
		if not is_instance_valid(target): return
		
		if(timer > lifetime/2):
			swarm.update_material(load("res://art/barbudo32p32p/ArcaneMissile.png"))
		else:
			swarm.update_material(load("res://art/barbudo32p32p/ArcaneMissile2.png"))

		hit_cooldown -= delta
		if hit_cooldown > 0: return
		
		# Check collisions using native positions
		var count = swarm.get_unit_count()
		for i in range(count):
			var pos = swarm.get_unit_position(i)
			if pos.distance_to(target.global_position) < 40.0:
				if CombatManager:
					CombatManager.request_interaction(swarm, target, "damage", {"amount": damage})
				hit_cooldown = 0.2
				break

	func on_interaction_failed():
		impact()
		pass

	func on_interaction_success():
		# On CombatManager ack: Explode the missile that hit player
		pass
