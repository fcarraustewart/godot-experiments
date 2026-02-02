extends Node2D

class_name BasePetEntity

# --- PET STATE ---
enum PetState { ORBIT, ATTACK, RETURN }
var current_pet_state = PetState.ORBIT
var attack_timer: float = 0.0
var target_entity: Node2D = null

# --- REFS ---
var host: Node2D = null
var dynamics_sim = null

# --- CONFIG ---
var aggro_range: float = 600.0
var attack_cooldown: float = 2.0

func _ready():
	_setup_dynamics()

func _exit_tree():
	if PhysicsManager and dynamics_sim:
		PhysicsManager.unregister_object(dynamics_sim)

func _setup_dynamics():
	# To be overridden by specific pets
	pass

func assign_host(new_host: Node2D):
	host = new_host

func find_target() -> Node2D:
	if not CombatManager or not is_instance_valid(host): return null
	
	var host_is_enemy = host.is_enemy() if host.has_method("is_enemy") else false
	var target_faction = CombatManager.Faction.PLAYER if host_is_enemy else CombatManager.Faction.ENEMY
	
	# 1. PRIORITY: If host is attacking something, help!
	var host_state = host.get("current_state")
	if host_state == BaseEntity.State.ATTACKING:
		var targets = CombatManager.find_targets_in_hitbox(host.get_sword_hitbox(), host)
		for t in targets:
			if is_instance_valid(t):
				var t_is_enemy = t.is_enemy() if t.has_method("is_enemy") else false
				if t_is_enemy != host_is_enemy:
					return t
			
	# 2. SECONDARY: Nearest opposing entity in AGGRO range
	var nearest = CombatManager.get_nearest_target(host.global_position, aggro_range, host, target_faction)
	return nearest

func start_attack(target: Node2D):
	target_entity = target
	current_pet_state = PetState.ATTACK
	# Derived classes should handle dynamics updates here

func hit_target(target: Node2D):
	# To be overridden
	pass

func _process(delta):
	if attack_timer > 0:
		attack_timer -= delta
