extends Node

# arcane_missiles.gd
# Logic for spawning arcane missiles that seek a target.
# Reuses logic from cleave_swarm_controller.gd

@export var DAMAGE = 8.0
@export var UNIT_COUNT = 3
@export var LIFETIME = 1.50
@export var SPEED = 100.0

var game_node: Node2D
var host: Node2D # The caster (Mage)

func _ready():
	host = get_parent()

func cast_missiles(target: Node2D):
	if not is_instance_valid(target): return
	
	# Find game_node to spawn projectiles into (so they don't move with the parent)
	if not game_node:
		game_node = host.get_parent() # Usually the main scene
		
	var swarm = BaseFlockSwarm.new()
	swarm.unit_count = UNIT_COUNT
	swarm.spawn_radius = 20.0 # Spawn closely packed
	swarm.max_speed = SPEED
	
	# Swarm behavior weights for "Seeking Missile" feel
	swarm.separation_weight = 0.020 # Keep them apart slightly
	swarm.alignment_weight = 2.0
	swarm.cohesion_weight = 1.5
	swarm.target_attraction_weight = 1.0 # Strong pull to target
	swarm.frequency = 1.0
	swarm.damping = 0.5
	
	# Visual setup
	var unit_packer = PackedScene.new()
	var unit_node = Node2D.new()
	unit_node.set_script(load("res://arcane_missile_flock_unit.gd"))
	unit_packer.pack(unit_node)
	swarm.unit_scene = unit_packer
	
	swarm.target_node = target # Homing target
	
	game_node.add_child(swarm)
	
	# Spawn at caster position
	swarm.global_position = host.global_position + Vector2(0, -30)
	
	# Force spawn
	swarm.spawn_flock()
	
	# Add initial burst/spread
	for unit in swarm.members:
		if not is_instance_valid(unit): continue
		
		# --- ADD INDIVIDUAL PROJECTILE GLOW ---
		var light = load("res://light_spirit.gd").new()
		light.color = Color(1.0, 0.4, 1.0, 0.6) # Arcane Purple/Pink
		light.radius = 32.0
		light.intensity = 1.0
		unit.add_child(light) # Light now follows each missile!
		# --------------------------------------

		# Random spread
		var angle = randf_range(0, TAU)
		var burst = Vector2(cos(angle), sin(angle)) * 100.0
		
		# Use PhysicsManager/SecondOrder to init pos if possible, or just force set
		# FlockUnit usually reads from PhysicsManager if registered, or uses local if not.
		# BaseFlockSwarm registers them.
		
		# Let's just let them fly.
		
		# Effect: Scale up
		unit.scale = Vector2(0.1, 0.1)
		var tween = unit.create_tween()
		tween.tween_property(unit, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Damage Logic: Check for impacts periodically or use a timer?
	# Since FlockUnits are physics objects in this system, maybe we simulate impact?
	# For simplicity, we can do a proximity check here in _process or a timer loop.
	# Let's stick to a simple timer loop in the swarm or here.
	
	# We'll create a thinker node to handle collision/damage for this specific swarm instance
	# We'll create a thinker node to handle collision/damage for this specific swarm instance
	var thinker = MissileThinker.new()
	thinker.name = "MissileLogic"
	swarm.add_child(thinker)
	
	# Inject logic into thinker
	thinker.setup(swarm, target, DAMAGE, LIFETIME)


# Inner class for handling the missile impact logic
class MissileThinker extends Node:
	var swarm
	var target
	var damage
	var lifetime
	var timer = 0.0
	var hit_cooldown = 0.0
	
	func setup(p_swarm, p_target, p_damage, p_lifetime):
		swarm = p_swarm
		target = p_target
		damage = p_damage
		lifetime = p_lifetime
		
	func _process(delta):
		timer += delta
		if timer > lifetime:
			print_rich("[color=yellow]Missiles Despawning... (Lifetime: %s)[/color]" % lifetime)
			swarm.queue_free()
			return
			
		if not is_instance_valid(target): return
		
		hit_cooldown -= delta
		if hit_cooldown > 0: return
		
		# Check collisions
		for unit in swarm.members:
			if not is_instance_valid(unit): continue
			
			if unit.global_position.distance_to(target.global_position) < 40.0:
				# HIT
				print("Arcane Missile hit!")
				if CombatManager:
					CombatManager.request_interaction(swarm, target, "damage", {"amount": damage})
				
				# Visual impact
				# ...
				
				# Destroy unit? Or just repel?
				# Let's repel to simulate impact and keep swarming (annoying missiles)
				var repel = (unit.global_position - target.global_position).normalized() * 300.0
				# Reset physics pos (hacky access to manager?)
				# Just visual:
				unit.modulate = Color(10,1,1) # Flash
				var t = unit.create_tween()
				t.tween_property(unit, "modulate", Color(1,0.4,0.8), 0.2)
				
				hit_cooldown = 0.2 # Prevent instant shotgun death
