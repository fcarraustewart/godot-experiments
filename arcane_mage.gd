extends BaseEntity

class_name ArcaneMage

# --- CONFIG ---
const WANDER_SPEED = 80.0
const CHASE_SPEED = 120.0
const CAST_RANGE = 250.0 # Range to start casting
const AGGRO_RANGE = 400.0
const CAST_COOLDOWN = 3.0

# --- ASSETS ---
const TEX_COMBAT = preload("res://art/barbudo32p32p/barbudo32b32-combat.png")
const TEX_CAST = preload("res://art/barbudo32p32p/barbudo32b32-arcane-cast.png")
const TEX_CAST_SUCCESS = preload("res://art/barbudo32p32p/barbudo32b32-cast-success.png")

# --- STATE ---
var sprite: Sprite2D
var wander_timer: float = 0.0
var wander_direction: float = 1.0
var cast_cooldown_timer: float = 0.0
var anim_timer: float = 0.0
var current_anim_frame: float = 0.0
var last_cast_success: bool = true

var target: Node2D = null

func _ready():
	super._ready()
	
	add_to_group("Enemy")
	feet_offset = 16.0 # 32px tall sprite
	
	# Create sprite
	sprite = Sprite2D.new()
	sprite.texture = TEX_COMBAT
	sprite.hframes = 5
	sprite.vframes = 1 # Assuming horizontal strip
	
	# Center the sprite mostly
	# 32x32 original. 
	# enemy.gd scales to 192 height (approx 6x for 32px sprites).
	#sprite.scale = Vector2(1.0, 1.0)
	
	# Adjust offset if needed. 32x32 is centered usually.
	
	add_child(sprite)
	
	# Add Missile Controller
	var missile_ctrl = load("res://arcane_missiles.gd").new()
	missile_ctrl.name = "MissileController" # Name it for easy access
	add_child(missile_ctrl)

func is_enemy():
	return true

func _process(delta):
	state_timer -= delta
	cast_cooldown_timer -= delta
	
	# Find target if none
	if not is_instance_valid(target):
		target = CombatManager.get_nearest_target(global_position, AGGRO_RANGE, self, CombatManager.Faction.PLAYER)

	# State Logic
	match current_state:
		State.IDLE, State.RUNNING:
			_process_movement(delta)
			_check_attack_conditions()
		State.CASTING:
			velocity = Vector2.ZERO
			_process_casting_anim(delta)
		State.CASTING_COMPLETE:
			velocity = Vector2.ZERO
			_process_cast_success_anim(delta)
		State.HURT:
			velocity = Vector2.ZERO
			if state_timer <= 0:
				change_state(State.IDLE)
		State.INTERRUPTED:
			velocity = Vector2.ZERO
			_process_interrupted(delta)
				
	# Apply animation frame
	_update_animation(delta)
	
	# Facing direction
	if velocity.x != 0:
		facing_right = velocity.x > 0
	elif is_instance_valid(target):
		facing_right = target.global_position.x > global_position.x
		
	if facing_right:
		sprite.flip_h = false
	else:
		sprite.flip_h = true

func _process_interrupted(delta):
	state_timer -= delta
	if state_timer <= 0:
		change_state(State.IDLE)

func _process_movement(delta):
	# Simple AI: Wander if no target, Chase/Kite if target
	if is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist > CAST_RANGE * 0.8:
			# Chase
			var dir = (target.global_position - global_position).normalized()
			velocity = dir * CHASE_SPEED
			change_state(State.RUNNING)
		else:
			# In range, maybe idle
			velocity = Vector2.ZERO
			change_state(State.IDLE)
	else:
		# Wander
		wander_timer -= delta
		if wander_timer <= 0:
			wander_timer = randf_range(1.0, 3.0)
			if randf() > 0.4:
				wander_direction = 1.0 if randf() > 0.5 else -1.0
				change_state(State.RUNNING)
			else:
				wander_direction = 0.0
				change_state(State.IDLE)
		
						
		velocity.x = wander_direction * WANDER_SPEED
		# velocity.y handled by PhysicsManager (Gravity) 

func _check_attack_conditions():
	if cast_cooldown_timer <= 0 and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= CAST_RANGE:
			start_casting()

func start_casting():
	last_cast_success = true
	change_state(State.CASTING)
	# Setup Cast Sprite
	sprite.texture = TEX_CAST
	
	# Force hframes based on 32px width assumption to fix "sweeping" issues
	# If the image is a strip, width / 32 should be the correct frame count.
	var w = sprite.texture.get_width()
	sprite.hframes = int(w / 32) 
	sprite.vframes = 1
	
	current_anim_frame = 0.0
	anim_timer = 0.0
	
func _process_casting_anim(delta):
	anim_timer += delta
	# 10 FPS
	var anim_speed = 12.0
	current_anim_frame += delta * anim_speed
	
	if current_anim_frame > sprite.hframes + 3.5: # Slightly before the end to trigger on time
		current_anim_frame = sprite.hframes - 1 # Stay on last frame until we finish
		finish_cast()
	
func finish_cast():
	if is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist > CAST_RANGE + 50.0:
			on_interaction_fail("OUT_OF_RANGE")
			# on_interaction_fail handles state change usually, but we ensure last_cast_success is false
			last_cast_success = false
	else:
		on_interaction_fail("TARGET_INVALID")
		last_cast_success = false
		
	if last_cast_success:
		var missile_ctrl = get_node("MissileController")
		if missile_ctrl:
			missile_ctrl.cast_missiles(target)
		
		cast_cooldown_timer = CAST_COOLDOWN
		
		# Transition to SUCCESS state
		change_state(State.CASTING_COMPLETE)
		sprite.texture = TEX_CAST_SUCCESS
		# Dynamic frame calculation
		var w = sprite.texture.get_width()
		sprite.hframes = int(w / 32) 
		sprite.vframes = 1
		
		current_anim_frame = 0.0
		anim_timer = 0.0
	else:
		# Fail state (already handled by on_interaction_fail usually)
		if current_state == State.CASTING:
			change_state(State.IDLE)

func _process_cast_success_anim(delta):
	var anim_speed = 18.0
	current_anim_frame += delta * anim_speed
	anim_timer += delta

	if current_anim_frame >= sprite.hframes:
		# Done
		current_anim_frame = sprite.hframes - 1 # Stay on last frame until we switch back to combat sprite
	
	if anim_timer > sprite.hframes + 2.0:
		# Done
		change_state(State.IDLE)
		sprite.texture = TEX_COMBAT
		var w = sprite.texture.get_width()
		sprite.hframes = int(w / 32)
		sprite.vframes = 1

func _update_animation(_delta):
	# --- APPLY LIGHTING ---
	sprite.modulate = external_lighting_modulate
	# ----------------------
	
	# Apply frame to sprite
	if current_state == State.CASTING or current_state == State.CASTING_COMPLETE:
		sprite.frame = int(current_anim_frame) % sprite.hframes
	else:
		# Combat/Idle loop (5 frames usually, but recalculate to be safe)
		if sprite.texture == TEX_COMBAT:
			var w = sprite.texture.get_width()
			var frames = int(w / 32)
			if frames > 0:
				sprite.hframes = frames # Ensure it's set if we switch back
				sprite.frame = int(Time.get_ticks_msec() / 150.0) % frames
		else:
			sprite.frame = 0

func get_sword_hitbox() -> Rect2:
	# Keep compatibility just in case
	return Rect2(position, Vector2(10,10))

func get_active_sprite() -> Sprite2D:
	return sprite

func on_interaction_success(_msg, _meta):
	pass

func on_interaction_fail(reason: String):
	if current_state == State.CASTING:
		if reason == "OUT_OF_RANGE":
			print("Arcane Mage cast interrupted: OUT OF RANGE")
			if CombatManager:
				CombatManager._create_floating_text(global_position, "INTERRUPTED", Color.ORANGE)
			state_timer = 1.0 # Short stun/confusion
			change_state(State.INTERRUPTED)
			cast_cooldown_timer = 1.0 # Short cooldown penalty
