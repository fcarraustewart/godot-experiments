extends BaseEntity

class_name PlayerController

# --- CONFIG ---
const SPEED = 500.0
# ... (rest of constants)
const ATTACK_DURATION = 0.3
const JUMP_DURATION = 0.7
const DASH_DURATION = 0.2
const JUMP_HEIGHT = 80.0
const SPEED_WHILE_JUMPING = 0.7
const SPEED_WHILE_DASHING = 4.5
const INTERRUPTED_DURATION = 7.0
const STUNNED_DURATION = 3.0
 
# --- ANIMATION ASSETS ---
const CASTING_TEXTURES = {
	0: "res://art/CastingAnims.png",
	1: "res://art/CastingAnimUndead.png"
}
const SUCCESS_TEXTURES = {
	0: "res://art/SuccessfulCastingAnims.png"
}

enum Reason { SILENCED, STUNNED, KICKED, PARRIED, HIT, OTHER }
var casting_time = 10.0
var hit_count: int = 0
# --- COMPONENTS ---
var sprite: Sprite2D
var casting: Sprite2D
var casting_success: Sprite2D
var running: Sprite2D
var jumping: Sprite2D
var dash: Sprite2D
var attack1: Sprite2D
var chain_lightning_ctrl
var fire_chains_ctrl
var meteor_strike_ctrl
var from_above = false

var axe_ctrl # Procedural axe controller
var crow_pet
var player_cast_bar: ProgressBar
var active_skill_ctrl = null
var aim_indicator: Node2D
var aim_arrow_line: Line2D

# --- PROGRESSION DATA ---
var global_charge: float = 0.0 # From 0 to 130
const MAX_CHARGE = 130.0
signal charge_changed(new_val)

# --- DATA ---
var casting_direction = Vector2.ZERO
# Physics simulation
var is_rooted_active = false
var is_slowed_active = false
var active_slow_factor = 1.0
var last_cast_success = true



# --- INPUT STATE (Populated by KeybindListener) ---
var input_throttle = 0.0
var input_steer_target = Vector2.ZERO # Either Mouse Pos or Direction Vector
var is_mouse_steering = false

# --- REFS ---
var game_node: Node2D # Reference to main world for spawning effects if needed

signal cast_start(duration)
signal cast_finished
signal jumped
signal dashed

signal struck
signal slowed
signal rooted
signal cast_interrupted

func kicked():
	if current_state == State.CASTING:
		emit_signal("cast_interrupted", Reason.KICKED)

func silenced():
	if current_state == State.CASTING:
		emit_signal("cast_interrupted", Reason.SILENCED)

func parried():
	if current_state == State.ATTACKING:
		emit_signal("cast_interrupted", Reason.PARRIED)

func stunned():
	emit_signal("cast_interrupted", Reason.STUNNED)

func stun(duration: float):
	emit_signal("cast_interrupted", Reason.STUNNED)
	state_timer = duration

func hit():
	if(not current_state == State.JUMPING and not current_state == State.DASHING):
		hit_count += 1
		emit_signal("struck")
func apply_slow(duration: int, slow_amount: float):
	emit_signal("slowed", duration, slow_amount)
func apply_root(duration: float):
	emit_signal("rooted", duration)


func _on_cast_interrupted(reason: Reason):
	print("Player detected cast interruption!")
	
	match(reason):		
		Reason.SILENCED, Reason.KICKED, Reason.PARRIED:
			chain_lightning_ctrl.cooldown = chain_lightning_ctrl.CHAIN_COOLDOWN_MAX * 4.5
			state_timer = INTERRUPTED_DURATION
			change_state(State.INTERRUPTED)
			
		Reason.STUNNED:
			change_state(State.STUNNED)
		
		Reason.HIT:
			print("Player hit %d during cast. Adding time 0.01!", hit_count)
			if(hit_count < 3):
				state_timer -= 0.01 # brief draw back on hit

		Reason.OTHER:
			change_state(State.IDLE)
		
func _on_jumped():
	if(is_rooted_active):
		return
	if current_state == State.CASTING or current_state == State.ATTACKING:
		emit_signal("cast_interrupted", Reason.OTHER)

	if current_state != State.JUMPING:
		change_state(State.JUMPING)
		state_timer = JUMP_DURATION
		
func _on_dashed():
	if(is_rooted_active):
		return
	if current_state == State.CASTING or current_state == State.ATTACKING:
		emit_signal("cast_interrupted", Reason.OTHER)
	else: 
		if current_state != State.DASHING:
			state_timer = DASH_DURATION
			change_state(State.DASHING)

func _on_struck():
	if current_state != State.JUMPING and current_state != State.DASHING:
		if current_state == State.CASTING:
			emit_signal("cast_interrupted", Reason.HIT)
		hit_count = 0

func _on_rooted(duration: float):
	if is_rooted_active:
		return
	is_rooted_active = true
	
	var time_elapsed = 0.0
	print("Applying root for duration %f", duration)
	while time_elapsed <= duration:
		# velocity = Vector2.ZERO # Handled in check_movement_input
		await get_tree().create_timer(0.01).timeout
		time_elapsed += 0.01
	print("Root ended")
	is_rooted_active = false


func _on_slowed(duration: int, slow_amount: float):
	if is_slowed_active:
		return
	is_slowed_active = true
	active_slow_factor = slow_amount

	var time_elapsed = 0.0
	print("Applying slow of amount %f for duration %d", slow_amount, duration)
	while time_elapsed <= duration:
		# velocity *= slow_amount # Handled in check_movement_input
		time_elapsed += 0.01
		await get_tree().create_timer(0.01).timeout
	
	print("Slow ended")
	active_slow_factor = 1.0
	is_slowed_active = false
	

	
func _ready():
	super._ready()
	# 1. Idle Sprite
	sprite = Sprite2D.new()
	sprite.texture = load("res://art/Inanimate-patas.png")
	sprite.region_enabled = false
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.visible = true
	add_child(sprite)

	# 2. Casting Sprite
	casting = Sprite2D.new()
	casting.texture = load("res://art/CastingAnims.png")
	casting.region_enabled = false
	casting.hframes = 22
	casting.vframes = 1
	casting.visible = false
	add_child(casting)

	# 3. Success Sprite
	casting_success = Sprite2D.new()
	casting_success.texture = load("res://art/SuccessfulCastingAnims.png")
	casting_success.region_enabled = false
	casting_success.hframes = 8
	casting_success.vframes = 1
	casting_success.visible = false
	add_child(casting_success)
	
	# 4. Running Sprite
	running = Sprite2D.new()
	running.texture = load("res://art/RunningFastAnims.png")
	running.region_enabled = false
	running.hframes = 8 
	running.vframes = 1
	running.visible = false
	add_child(running)

	# 5. Jump Sprite
	jumping = Sprite2D.new()
	jumping.texture = load("res://art/JumpingAnims.png")
	jumping.region_enabled = false
	jumping.hframes = 11
	jumping.vframes = 1
	jumping.visible = false
	add_child(jumping)

	# 6. Dash Sprite
	dash = Sprite2D.new()
	dash.texture = load("res://art/ShoulderDashAnims.png")
	dash.region_enabled = false
	dash.hframes = 7
	dash.vframes = 1
	dash.visible = false
	add_child(dash)

	# 6. Dash Sprite
	attack1 = Sprite2D.new()
	attack1.texture = load("res://art/SwordAttack1Anims.png")
	attack1.region_enabled = false
	attack1.hframes = 4
	attack1.vframes = 1
	attack1.visible = false
	add_child(attack1)
	
	# Instantiate Skills
	chain_lightning_ctrl = load("res://with_physics_manager_chain_lightning_controller.gd").new()
	chain_lightning_ctrl.game_node = game_node # Pass main node for enemy access
	add_child(chain_lightning_ctrl)
	
	fire_chains_ctrl = load("res://with_physics_manager_fire_chains_controller.gd").new()
	fire_chains_ctrl.game_node = game_node
	add_child(fire_chains_ctrl)
	
	meteor_strike_ctrl = load("res://meteor_strike_controller.gd").new()
	meteor_strike_ctrl.game_node = game_node
	add_child(meteor_strike_ctrl)
	
	crow_pet = load("res://crow_pet.gd").new()
	crow_pet.host = self # Orbit this node
	# Crow usually added to main scene to avoid rotation inheritance issues, 
	# but adding to player is fine if we manage rotation carefully or use position
	# User previous code added it to main scene. Let's keep it consistent if possible, 
	# but for encapsulation, adding to Player is better. 
	# BUT `crow_pet.gd` uses `position` relative to parent. If parent is player, it orbits player correctly.
	add_child(crow_pet)


	# --- SETUP PLAYER CAST BAR ---
	player_cast_bar = ProgressBar.new()
	player_cast_bar.size = Vector2(50, 1)
	player_cast_bar.position = Vector2(-25, 40) # Centered below sprite
	player_cast_bar.show_percentage = false
	# Style it
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.5)
	player_cast_bar.add_theme_stylebox_override("background", bg_style)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1.0, 0.9, 0.2) # Yellow Charging
	player_cast_bar.add_theme_stylebox_override("fill", fill_style)
	
	player_cast_bar.visible = false
	# Attach to player directly
	add_child(player_cast_bar)
	
	# --- AIM INDICATOR ---
	aim_indicator = Node2D.new()
	aim_arrow_line = Line2D.new()
	aim_arrow_line.points = PackedVector2Array([Vector2(0,0), Vector2(50,0), Vector2(42.5, -5), Vector2(50,0), Vector2(42.5, 5)])
	aim_arrow_line.width = 2.0
	aim_arrow_line.default_color = Color(1.0, 1.0, 1.0, 0.6)
	aim_indicator.add_child(aim_arrow_line)
	aim_indicator.visible = false
	add_child(aim_indicator)

	# Connect Internal Signals
	cast_interrupted.connect(_on_cast_interrupted)
	jumped.connect(_on_jumped)
	dashed.connect(_on_dashed)
	struck.connect(_on_struck)
	slowed.connect(_on_slowed)
	rooted.connect(_on_rooted)

	# --- LINK TO KEYBIND LISTENER ---
	if KeybindListener:
		KeybindListener.move_throttle_changed.connect(_on_input_throttle)
		KeybindListener.steer_direction_changed.connect(_on_input_steer)
		KeybindListener.action_triggered.connect(_on_input_action)

func _exit_tree():
	if CombatManager:
		CombatManager.unregister_entity(self)

func _process(delta):
	# State Management
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.RUNNING:
			process_running(delta)
		State.ATTACKING:
			process_attacking(delta)
		State.CASTING:
			process_casting(delta)
		State.JUMPING:
			process_jumping(delta)
		State.DASHING:
			process_dashing(delta)
		State.STUNNED:
			process_stunned(delta)
		State.INTERRUPTED:
			process_interrupted(delta)
		State.HURT:
			process_hurt(delta) # Stays here but is avoided in change_state
		State.CASTING_COMPLETE:
			# Temporary state to handle post-cast logic if needed
			process_casting_complete(delta)
			
	# Global Loop (Cooldowns, Pet) - handled by children automatically
	
	# Apply Movement - HANDLED BY PhysicsManager
	# position += velocity * delta
	
	# Animation & Visuals
	update_animation(delta)	

# --- STATE HANDLERS ---

func process_idle(_delta):
	check_movement_input()
	check_action_input()
	update_aim_indicator()

func process_running(_delta):
	check_movement_input()
	check_action_input()
	update_aim_indicator()

func process_hurt(delta):
	check_movement_input()
	check_action_input()
	update_aim_indicator()
	if state_timer <= 0:
		change_state(State.IDLE)

func process_attacking(delta):
	velocity = Vector2.ZERO # Root while attacking? Or allow slide? Let's root for impact.
	state_timer -= delta
	if state_timer <= 0:
		change_state(State.IDLE)

func process_casting(delta):
	check_movement_input() # Allow air control
	check_action_input()

	# --- UI UPDATE ---
	player_cast_bar.visible = true
	player_cast_bar.max_value = casting_time
	player_cast_bar.value = state_timer
	# -----------------
	# Casting logic
	state_timer += delta

	if active_skill_ctrl:
		from_above = !from_above
		active_skill_ctrl.cast(state_timer, from_above)

	if state_timer >= casting_time and (not active_skill_ctrl or not active_skill_ctrl.is_casting):
		if last_cast_success:
			# Successful Cast! 
			# Handle Charge Generation & Consumption
			var spell_data = DataManager.get_spell(active_skill_ctrl.get_spell_id() if active_skill_ctrl.has_method("get_spell_id") else "")
			if spell_data:
				if spell_data.has("charge_gen"):
					add_charge(spell_data.charge_gen)
				if spell_data.has("charge_cost"):
					consume_charge(spell_data.charge_cost)

			state_timer = 0.5 # Animation lock for 'SuccessfulCasting'
			player_cast_bar.visible = false
			change_state(State.CASTING_COMPLETE)
		else:
			# Failed or interrupted interaction
			change_state(State.IDLE)
		return

func process_casting_complete(delta):
	check_movement_input() # Allow air control
	check_action_input()
	update_aim_indicator()

	# Casting logic handled by controllers usually, but here we enforce state
	# Skills might finish casting and call back, or we poll
	# sprite.modulate = Color(1.5, 1.5, 1.9) # Slight blue tint while casting
	state_timer -= delta
	if state_timer <= 0:
		change_state(State.IDLE)

func process_jumping(delta):
	check_movement_input() # Allow air control
	
	# Only land if we are actually touching the floor AND not moving upwards
	if is_on_floor_physics and velocity.y >= 0:
		change_state(State.IDLE)


func process_dashing(delta):
	check_movement_input() # Allow dash control
	state_timer -= delta
	if state_timer <= 0:
		# Reset any movement action-specific visuals
		change_state(State.IDLE)

func process_stunned(delta):
	velocity = Vector2.ZERO
	state_timer -= delta
	if state_timer <= 0:
		change_state(State.IDLE)

func process_interrupted(delta):
	state_timer -= delta

	player_cast_bar.modulate = Color(1.0, 0.2, 0.2) # Red tint
	player_cast_bar.visible = true
	player_cast_bar.value = float(state_timer) / INTERRUPTED_DURATION * player_cast_bar.max_value
	
	# Maybe flash yellow/interrupted effect
	if state_timer <= 0:
		change_state(State.IDLE)

func check_movement_input():
	if is_rooted_active:
		velocity.x = 0
		return

	# --- HORIZONTAL MOVEMENT ---
	var move_dir = 0.0
	if input_throttle != 0:
		move_dir = input_throttle
		facing_right = move_dir > 0
	
	# Start with base speed
	var current_horizontal_speed = SPEED
	
	# Apply state modifiers (ONLY to horizontal speed)
	if current_state == State.DASHING:
		current_horizontal_speed *= SPEED_WHILE_DASHING
	elif current_state == State.JUMPING:
		current_horizontal_speed *= SPEED_WHILE_JUMPING
		
	# Apply slow
	if is_slowed_active:
		current_horizontal_speed *= active_slow_factor

	# Set the velocity
	if(current_state != State.CASTING):
		velocity.x = move_dir * current_horizontal_speed
	else:
		velocity.x = 0 # Rooted during casting

	# Update Animation States
	if move_dir != 0:
		if current_state == State.IDLE:
			change_state(State.RUNNING)
	elif current_state == State.RUNNING:
		change_state(State.IDLE)

func check_action_input():
	# Now handled via _on_input_action signals
	pass

# --- SIGNAL HANDLERS FOR KEYBIND LISTENER ---

func _on_input_throttle(val: float):
	input_throttle = val

func _on_input_steer(dir: Vector2):
	input_steer_target = dir

func _on_input_action(action_name: String, data: Dictionary):
	match action_name:
		"toggle_mouse_steer":
			is_mouse_steering = data.get("active", false)
		
		"jump":
			if is_on_floor_physics:
				velocity.y = -500.0 # Jump Impulse
				print("Jumping!")
				emit_signal("jumped")
		
		"dash":
			if current_state != State.JUMPING and current_state != State.DASHING:
				emit_signal("dashed")

		# instants:
		"attack":
			if current_state != State.ATTACKING:
				change_state(State.ATTACKING)
				state_timer = ATTACK_DURATION
				emit_signal("cast_start", ATTACK_DURATION)
				if is_instance_valid(axe_ctrl):
					axe_ctrl.start_attack()

		"fire_chains":
			_try_start_cast(fire_chains_ctrl, "fire_chains")
		
		# casted
		"chain_lightning":
			if current_state != State.JUMPING and current_state != State.DASHING:
				_try_start_cast(chain_lightning_ctrl, "chain_lightning")
		"meteor_strike":
			if current_state != State.JUMPING and current_state != State.DASHING:
				_try_start_cast(meteor_strike_ctrl, "meteor_strike")

func _try_start_cast(ctrl, spell_id: String):
	if current_state == State.CASTING: return
	if not ctrl: return
	
	var data = DataManager.get_spell(spell_id)
	var cost = data.get("charge_cost", 0)
	
	if global_charge < cost:
		CombatManager._create_floating_text(position, "NOT ENOUGH CHARGE!", Color.ORANGE)
		return

	if ctrl.has_method("can_cast") and not ctrl.can_cast(): # Optional cooldown check
		return
		
	# Special case for existing controllers that use try_cast instead of can_cast
	# but we've refactored them to be managed here.
	# For now, let's keep it simple:
	var target_pos = Vector2.ZERO
	if ctrl.has_method("try_cast"): target_pos = ctrl.try_cast(position)
	elif ctrl.has_method("try_cast_chain_lightning"): target_pos = ctrl.try_cast_chain_lightning(position)
	
	if ctrl.is_casting:
		state_timer = 0.0
		last_cast_success = true # Reset success flag
		active_skill_ctrl = ctrl
		casting_time = data.get("cast_time", 1.0)
		casting_direction = target_pos
		
		# --- SWAP ANIMATION TEXTURES ---
		var c_id = data.get("casting_anim_id", 0)
		var s_id = data.get("success_anim_id", 0)
		
		if CASTING_TEXTURES.has(c_id):
			casting.texture = load(CASTING_TEXTURES[c_id])
			casting.hframes = data.get("casting_frames", 22)
			
		if SUCCESS_TEXTURES.has(s_id):
			casting_success.texture = load(SUCCESS_TEXTURES[s_id])
			casting_success.hframes = data.get("success_frames", 8)
		
		change_state(State.CASTING)

# --- UTILS ---
func sprite_swap():
	_hide_all_sprites()
	var active = get_active_sprite()
	if active: 
		active.visible = true
		active.position.y = 0
		
		# --- BULLETPROOF REGION-BOUNDED hframes ---
		# We define the 'Real Area' and let Godot's hframes divide only THAT.
		active.region_enabled = true
		var tex = active.texture
		if tex:
			var total_w = tex.get_width()
			var total_h = tex.get_height()
			
			# Determine frame count and optional junk padding
			var h_cnt = 1
			
			if active == running: 
				h_cnt = running.hframes 
			if active == jumping:
				h_cnt = jumping.hframes 
			if active == dash:
				h_cnt = dash.hframes 
			if active == attack1:
				h_cnt = attack1.hframes 
			elif active == casting: 
				h_cnt = casting.hframes
			elif active == casting_success: 
				h_cnt = casting_success.hframes
			elif active == sprite: 
				h_cnt = sprite.hframes
			
			# Define the playable region
			active.region_rect = Rect2(0, 0, total_w, total_h)
			active.hframes = h_cnt
			active.vframes = 1
			
			# --- AUTO-SCALE ---
			var frame_w = float(total_w) / float(h_cnt)
			var frame_h = float(total_h) / float(active.vframes)
			
			var target_size = 64
			# Temporary fix: Action sheets have more padding/blank space, so we use a larger target size
			if active != sprite:
				target_size = 64*2.0
				
			var s_x = target_size / frame_w
			var s_y = target_size / frame_h
			
			# Apply Scale & Facing
			if (not facing_right):
				active.scale = Vector2(-s_x, s_y)
			else:
				active.scale = Vector2(s_x, s_y)

			# --- USER DEBUG PRINT ---
			if Engine.get_process_frames() % 60 == 0:
				print("[PlayerPhysics] OnFloor: %s | VelY: %.1f | State: %s" % [
					is_on_floor_physics,
					velocity.y,
					State.keys()[current_state]
				])
		
		# Special colors for states
		if active == casting or active == casting_success:
			active.modulate = Color(1.0, 0.6, 1.9, 1.0)
		elif current_state == State.STUNNED:
			active.modulate = Color(0.5, 0.5, 0.5)
		else:
			active.modulate = Color.WHITE

func reset_animations():
	sprite_swap()
	for sprite in [sprite, casting, casting_success, running, jumping, dash, attack1]:
		sprite.frame = 0

func change_state(new_state):
	if current_state == new_state: return
			
	# Exit Logic
	if new_state == State.HURT:
		emit_signal("struck")
		return

	reset_animations() # Stop all animations until we set the correct one for the new state

	if current_state == State.CASTING or current_state == State.CASTING_COMPLETE:
		emit_signal("cast_finished")
		if active_skill_ctrl and active_skill_ctrl.is_casting:
			active_skill_ctrl.interrupt_charging()
		player_cast_bar.visible = false
		casting_success.frame = 0
		casting.frame = 0

	if current_state == State.DASHING or current_state == State.JUMPING:
		# Reset any movement action-specific visuals
		pass

	if current_state == State.INTERRUPTED:
		player_cast_bar.modulate = Color.WHITE
		player_cast_bar.visible = false
		if state_timer > 0:
			return # Can't exit interrupted until timer done

	if current_state == State.STUNNED:
		if state_timer > 0:
			return # Can't exit stunned until timer done

	current_state = new_state
	# Visibility handled in _process nuclear loop now

	# Enter Logic
	match current_state:
		State.CASTING:
			# --- FLIP DIRECTION SYNC ---
			var dir_is_right = casting_direction.x > position.x
			facing_right = dir_is_right
		State.IDLE:
			player_cast_bar.visible = false

func _hide_all_sprites():
	sprite.visible = false
	casting.visible = false
	casting_success.visible = false
	running.visible = false
	jumping.visible = false
	dash.visible = false
	attack1.visible = false
	# Ensure they are opaque when they DO appear
	sprite.modulate.a = 1.0
	casting.modulate.a = 1.0
	casting_success.modulate.a = 1.0
	running.modulate.a = 1.0
	jumping.modulate.a = 1.0
	dash.modulate.a = 1.0
	attack1.modulate.a = 1.0

func get_active_sprite() -> Sprite2D:
	match current_state:
		State.ATTACKING: return attack1
		State.RUNNING: return running
		State.JUMPING: return jumping
		State.DASHING: return dash
		State.CASTING: return casting
		State.CASTING_COMPLETE: return casting_success
		_: return sprite

func update_animation(_delta):
	sprite_swap()
	# Frame Logic only. 
	# We set .frame here, and _process uses it to calculate region_rect.
	match current_state:
		State.ATTACKING:
			var t = Time.get_ticks_msec() / 100.0 
			attack1.frame = (int(t)) % attack1.hframes

		State.CASTING_COMPLETE:
			var h_cnt : int = 0
			if active_skill_ctrl:
				var data = DataManager.get_spell(active_skill_ctrl.get_spell_id())
				if data: h_cnt = data.get("success_frames", 8)
			if(casting_success.frame < h_cnt-1): 
				var t : int = int(Time.get_ticks_msec() / 30.0)
				casting_success.frame = int(t) % (h_cnt)
				print("Casting Success Frame: %d / %d" % [casting_success.frame, h_cnt])
		State.CASTING:
			var t = Time.get_ticks_msec() / 100.0
			var h_cnt : int = 0
			if active_skill_ctrl:
				var data = DataManager.get_spell(active_skill_ctrl.get_spell_id())
				if data: h_cnt = data.get("casting_frames", 22)
			casting.frame = int(t) % h_cnt
		State.RUNNING:
			var t = Time.get_ticks_msec() / 100.0 
			running.frame = (int(t)) % running.hframes
		State.JUMPING:
			var t = Time.get_ticks_msec() / 70.0 
			jumping.frame = (int(t)) % jumping.hframes
		State.DASHING:
			var t = Time.get_ticks_msec() / 50.0 
			dash.frame = (int(t)) % dash.hframes
		State.IDLE:
			sprite.frame = 0

# --- HITBOX HELPERS (For compatibility with Main Scene collision check) ---
const SWORD_HITBOX_SIZE = Vector2(60, 13.3)
const PLAYER_SWORD_HITBOX_OFFSET = Vector2(26.7, 0)


# --- AIM HELPER ---
func update_aim_indicator():
	if is_mouse_steering:
		aim_indicator.visible = true
		var mouse_pos = get_global_mouse_position()
		aim_indicator.rotation = (mouse_pos - position).angle()
	else:
		aim_indicator.visible = false



func get_sword_hitbox() -> Rect2:
	if current_state != State.ATTACKING: return Rect2()
	
	var offset = PLAYER_SWORD_HITBOX_OFFSET
	if not facing_right: offset.x = -offset.x
	
	var box_center = position + Vector2(offset.x, offset.y)
	
	var top_left = box_center - (SWORD_HITBOX_SIZE / 2.0)
	return Rect2(top_left, SWORD_HITBOX_SIZE)

func is_enemy():
	return false # Player is not an enemy

func add_charge(amount: float):
	global_charge = clamp(global_charge + amount, 0, MAX_CHARGE)
	emit_signal("charge_changed", global_charge)

func consume_charge(amount: float):
	global_charge = clamp(global_charge - amount, 0, MAX_CHARGE)
	emit_signal("charge_changed", global_charge)
	print("Power Surge: %d/%d" % [global_charge, MAX_CHARGE])

func on_interaction_success(_msg, _meta):
	last_cast_success = true

func on_interaction_fail(reason: String):
	# If we are currently casting and we get a failure, track it
	if current_state == State.CASTING or current_state == State.CASTING_COMPLETE:
		if reason == "OUT_OF_RANGE" or reason == "TARGET_INVALID":
			last_cast_success = false
			# Force jump back to IDLE if the interaction failed mid-cast
			change_state(State.IDLE)
