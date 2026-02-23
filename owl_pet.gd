extends BasePetEntity

# --- OWL SETTINGS ---
const ORBIT_SPEED = 1.5
const ORBIT_RADIUS = 60.0
const ATTACK_SPEED = 900.0
const RETURN_SPEED = 600.0
const DAMAGE = 15.0

# --- DYNAMICS PRESETS ---
const DYNAMICS_ORBIT_F = 0.4
const DYNAMICS_ORBIT_Z = 0.55
const DYNAMICS_ORBIT_R = 1.0

const DYNAMICS_ATTACK_F = 3.0
const DYNAMICS_ATTACK_Z = 0.8
const DYNAMICS_ATTACK_R = 0.5

# Visuals
var sprite: Sprite2D
var shadow: Sprite2D
var orbit_angle = 0.0

# Animation States
enum OwlVisualState { FLYING, DEACCEL, STATIONARY, TURN }
var visual_state: OwlVisualState = OwlVisualState.FLYING
var anim_timer: float = 0.0
var current_frame: int = 0
var is_turning: bool = false
var target_flip: bool = false

# Texture Constants
const TEX_FLYING = preload("res://art/owl/Owl-flying_right.png") # 7 frames
const TEX_DEACCEL = preload("res://art/owl/Owl-flying_deaccel.png") # 4 frames
const TEX_STATIONARY = preload("res://art/owl/Owl-flying_stationary.png") # 5 frames
const TEX_TURN = preload("res://art/owl/Owl-flying_turn_right.png") # 3 frames

func _ready():
	# Create visual sprite
	sprite = Sprite2D.new()
	sprite.texture = TEX_FLYING
	sprite.hframes = 6
	sprite.vframes = 1
	sprite.scale = Vector2(0.8, 0.8) # Adjust as needed
	add_child(sprite)
	
	# Add a soft shadow
	shadow = Sprite2D.new()
	shadow.texture = TEX_FLYING # We'll just tint it
	shadow.hframes = 6
	shadow.vframes = 1
	shadow.scale = Vector2(0.6, 0.4)
	shadow.modulate = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(0, 120)
	shadow.z_index = 10
	add_child(shadow)


	attack_cooldown = 1.4
	
	super._ready()

func _setup_dynamics():
	if PhysicsManager:
		dynamics_sim = PhysicsManager.register_second_order(
			"Owl_" + str(get_instance_id()), 
			global_position, 
			DYNAMICS_ORBIT_F, DYNAMICS_ORBIT_Z, DYNAMICS_ORBIT_R
		)

func _process(delta):
	super._process(delta)
	
	match current_pet_state:
		PetState.ORBIT:
			process_orbit(delta)
			if attack_timer <= 0:
				var target = find_target()
				if target:
					start_attack(target)
					
		PetState.ATTACK:
			process_attack_dive(delta)
				
		PetState.RETURN:
			process_return(delta)

	_update_visuals(delta)

func process_orbit(delta):
	if not is_instance_valid(host): return
	
	orbit_angle += ORBIT_SPEED * delta
	var x_off = cos(orbit_angle) * ORBIT_RADIUS
	# Add some subtle vertical bobbing
	var y_off = sin(orbit_angle * 0.5) * (ORBIT_RADIUS * 0.4) + sin(orbit_angle * 2.5) * 10.0
	
	var desired_pos = host.global_position + Vector2(x_off, y_off - 80) # Fly a bit higher than crow
	
	if dynamics_sim:
		PhysicsManager.set_second_order_target(dynamics_sim.id, desired_pos)
		global_position = PhysicsManager.get_second_order_pos(dynamics_sim.id)

func process_attack_dive(delta):
	if not is_instance_valid(target_entity):
		current_pet_state = PetState.RETURN
		return
		
	if dynamics_sim:
		PhysicsManager.set_second_order_target(dynamics_sim.id, target_entity.global_position)
		global_position = PhysicsManager.get_second_order_pos(dynamics_sim.id)
		
		if global_position.distance_to(target_entity.global_position) < 40.0:
			hit_target(target_entity)
			current_pet_state = PetState.RETURN
	else:
		var dir = (target_entity.global_position - global_position).normalized()
		global_position += dir * ATTACK_SPEED * delta
		if global_position.distance_to(target_entity.global_position) < 20.0:
			hit_target(target_entity)
			current_pet_state = PetState.RETURN

func process_return(delta):
	if not is_instance_valid(host): return
	
	var return_pos = host.global_position + Vector2(0, -80)
	
	if dynamics_sim:
		PhysicsManager.set_second_order_target(dynamics_sim.id, return_pos)
		global_position = PhysicsManager.get_second_order_pos(dynamics_sim.id)
		
		if global_position.distance_to(return_pos) < 50.0:
			current_pet_state = PetState.ORBIT
			attack_timer = attack_cooldown + randf()
		return

	var dir = (return_pos - global_position).normalized()
	var dist = global_position.distance_to(return_pos)
	
	global_position += dir * RETURN_SPEED * delta
	
	if dist < 20.0:
		current_pet_state = PetState.ORBIT
		attack_timer = attack_cooldown + randf()
		if dynamics_sim: 
			PhysicsManager.update_dynamics_for_sim(dynamics_sim, DYNAMICS_ORBIT_F, DYNAMICS_ORBIT_Z, DYNAMICS_ORBIT_R)
			dynamics_sim.xp = global_position
			dynamics_sim.y = global_position
			dynamics_sim.xd = Vector2.ZERO

func start_attack(target: Node2D):
	super.start_attack(target)
	if dynamics_sim:
		PhysicsManager.update_dynamics_for_sim(dynamics_sim, DYNAMICS_ATTACK_F, DYNAMICS_ATTACK_Z, DYNAMICS_ATTACK_R)

func hit_target(target: Node2D):
	if target.has_method("apply_hit"):
		target.apply_hit(DAMAGE, self)

# --- VISUAL STATE MACHINE ---

func _update_visuals(delta):
	var vel = Vector2.ZERO
	if dynamics_sim:
		vel = PhysicsManager.get_second_order_velocity(dynamics_sim.id)
	
	var speed = vel.length()
	var moving_right = vel.x > 2
	var moving_left = vel.x < -2

	# Determine intent to flip
	if not is_turning:
		if moving_right and sprite.flip_h: # Was looking left, now moving right
			_start_turn(false) # flip_h false = looking right
		elif moving_left and not sprite.flip_h: # Was looking right, now moving left
			_start_turn(true) # flip_h true = looking left
	
	# Determine Animation State (if not forced to turn)
	if not is_turning:
		if current_pet_state == PetState.ATTACK:
			# When attacking, we use flying_right -> deaccel at the end
			if is_instance_valid(target_entity):
				var dist = global_position.distance_to(target_entity.global_position)
				if dist < 80.0: # Close to target
					_change_visual_state(OwlVisualState.DEACCEL, 4)
				else:
					_change_visual_state(OwlVisualState.FLYING, 6)
			else:
				_change_visual_state(OwlVisualState.STATIONARY, 5)
		else:
			if speed > 80.0:
				_change_visual_state(OwlVisualState.FLYING, 6)
			elif speed > 45.0:
				_change_visual_state(OwlVisualState.DEACCEL, 4)
			else:
				_change_visual_state(OwlVisualState.STATIONARY, 5)

	# Process Animation Frames
	anim_timer += delta * 12.0 # Adjust frame rate
	if anim_timer >= 1.0:
		anim_timer -= 1.0
		current_frame += 1
		
		# Handle specific end-of-animation logic
		if is_turning:
			if current_frame >= sprite.hframes: 
				# Turn finished! Apply flip and return to normal logic
				sprite.flip_h = target_flip
				is_turning = false
				# Force a re-eval immediately so we don't blink
				current_frame = 0 
		else:
			# Normal looping
			current_frame = current_frame % sprite.hframes

	# Apply visuals
	sprite.frame = min(current_frame, sprite.hframes - 1)
	
	# Update Shadow
	shadow.texture = sprite.texture
	shadow.hframes = sprite.hframes
	shadow.frame = sprite.frame
	shadow.flip_h = sprite.flip_h
	
	# Minimal banking/rotation instead of full rotation
	if not is_turning and speed > 10:
		# Slight tilt based on vertical velocity
		var target_rot = vel.y * 0.002
		if sprite.flip_h:
			target_rot = -target_rot
		sprite.rotation = lerp_angle(sprite.rotation, target_rot, delta * 10.0)
	else:
		sprite.rotation = lerp_angle(sprite.rotation, 0.0, delta * 5.0)
		
	shadow.rotation = sprite.rotation

func _start_turn(target_is_left: bool):
	is_turning = true
	target_flip = target_is_left
	_change_visual_state(OwlVisualState.TURN, 4)

func _change_visual_state(new_state: OwlVisualState, frames: int):
	if visual_state != new_state:
		var last_frame = current_frame
		var last_max = sprite.hframes
		
		visual_state = new_state
		current_frame = 0
		anim_timer = 0.0
		sprite.hframes = frames
		
		match new_state:
			OwlVisualState.FLYING:
				sprite.texture = TEX_FLYING
			OwlVisualState.DEACCEL:
				sprite.texture = TEX_DEACCEL
			OwlVisualState.STATIONARY:
				sprite.texture = TEX_STATIONARY
			OwlVisualState.TURN:
				sprite.flip_h = target_flip
				sprite.texture = TEX_TURN
				
		# Try to keep phase sync if switching between flying and deaccel
		if (new_state == OwlVisualState.FLYING or new_state == OwlVisualState.DEACCEL) and last_max > 0:
			var phase = float(last_frame) / float(last_max)
			current_frame = int(phase * frames) % frames
