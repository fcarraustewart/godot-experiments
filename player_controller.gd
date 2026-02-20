extends BaseEntity

class_name PlayerController

# --- CONFIG ---
const SPEED = 500.0
# ... (rest of constants)
const ATTACK_DURATION = 0.3
const DASH_DURATION = 0.2
const SPEED_WHILE_JUMPING = 0.7
const SPEED_WHILE_DASHING = 4.5
const INTERRUPTED_DURATION = 7.0
const STUNNED_DURATION = 3.0

const COYOTE_TIME = 0.15 # Grace period after falling
const JUMP_BUFFER = 0.15 # Buffer for early jump press
 
# --- ANIMATION ASSETS ---
const CASTING_TEXTURES = {
	0: "res://art/CastingAnims.png",
	1: "res://art/CastingAnimUndead.png"
}
const SUCCESS_TEXTURES = {
	0: "res://art/SuccessfulCastingAnims.png"
}

# --- COMPONENTS ---
var casting_component: CastingComponent
var interruption_component: InterruptionComponent
var sprite: Sprite2D
var idle: Sprite2D
var idle_timer: float = 0.0
var stationary: Sprite2D
var casting: Sprite2D
var casting_success: Sprite2D
var running: Sprite2D
var jumping: Sprite2D
var dash: Sprite2D
var attack1: Sprite2D
var attack2: Sprite2D
var attack3: Sprite2D
var cleave_count = 0
var meteor_strike_ctrl
var cleave_swarm_ctrl
var chain_lightning_ctrl
var fire_chains_ctrl
var from_above = false

var axe_ctrl # Procedural axe controller
var crow_pet
var player_cast_bar: ProgressBar
var aim_indicator: Node2D
var aim_arrow_line: Line2D

# --- PROGRESSION DATA ---
var global_charge: float = 0.0 # From 0 to 130
const MAX_CHARGE = 130.0
signal charge_changed(new_val)

# --- DATA ---
# Physics simulation
var is_slowed_active = false
var active_slow_factor = 1.0

var jump_component: JumpComponent
var movement_component: MovementComponent
var action_component: ActionComponent
var knockback_component: KnockbackComponent
var interaction_component: InteractionComponent
var inventory_component: InventoryComponent

# --- INPUT STATE (Populated by KeybindListener) ---
var input_throttle = 0.0
var input_steer_target = Vector2.ZERO # Either Mouse Pos or Direction Vector
var is_mouse_steering = false

# --- REFS ---
var game_node: Node2D # Reference to main world for spawning effects if needed

signal dashed
signal struck
signal slowed
signal rooted

func kicked():
	interruption_component.interrupt(BaseEntity.Reason.KICKED)

func silenced():
	interruption_component.interrupt(BaseEntity.Reason.SILENCED)

func parried():
	if current_state == State.ATTACKING:
		interruption_component.interrupt(BaseEntity.Reason.PARRIED)

func stunned():
	interruption_component.interrupt(BaseEntity.Reason.STUNNED)

func stun(duration: float):
	interruption_component.interrupt(BaseEntity.Reason.STUNNED)
	state_timer = duration

func hit():
	emit_signal("struck")

func apply_slow(duration: int, slow_amount: float):
	emit_signal("slowed", duration, slow_amount)
func apply_root(duration: float):
	emit_signal("rooted", duration)

func _on_interruption(reason: BaseEntity.Reason):
	print("[player_controller] detected cast interruption! Reason: %s" % BaseEntity.Reason.keys()[reason])
	
	casting_component.interrupt(reason)

	match(reason):		
		BaseEntity.Reason.SILENCED, BaseEntity.Reason.KICKED:
			casting_component.emit_signal("cast_locked_out", INTERRUPTED_DURATION)
			state_timer = INTERRUPTED_DURATION
			change_state(State.INTERRUPTED)

		BaseEntity.Reason.PARRIED:
			if current_state == State.ATTACKING or State.ATTACKING_2 or State.ATTACKING_3:
				change_state(State.STUNNED)

		BaseEntity.Reason.STUNNED:
			change_state(State.STUNNED)
		
		BaseEntity.Reason.HIT:
			if current_state == BaseEntity.State.CASTING:
				var knockback_delay = interruption_component.handle_hit(current_state, state_timer, casting_component.casting_time)
				state_timer -= knockback_delay
				casting_component.emit_signal("cast_knockback", knockback_delay)

				if knockback_delay > 0:
					print("[player_controller] Knockback applied!")
					# Use KnockbackComponent instead of raw velocity +=
					var enemy = get_node_or_null("/root/Main/Enemy")
					var dir = (position - (enemy.position if enemy else position)).normalized()
					knockback_component.apply_impulse(dir, 200.0)

		BaseEntity.Reason.OTHER:
			change_state(State.IDLE)

func _on_jumped():
	print("[player_controller]Player jumped!")
	if(is_rooted_active):
		return
	if current_state == State.CASTING or current_state == State.ATTACKING:
		emit_signal("cast_interrupted", Reason.OTHER)

	if current_state != BaseEntity.State.JUMPING or \
		current_state != BaseEntity.State.JUMP_PEAK or \
		current_state != BaseEntity.State.FALLING:
		change_state(BaseEntity.State.JUMPING)

func _on_jump_peak():
	print("[player_controller]Player reached jump peak!")
	if current_state != BaseEntity.State.JUMP_PEAK:
		change_state(BaseEntity.State.JUMP_PEAK)

func _on_falling():
	print("[player_controller]Player is falling!")
	if current_state != BaseEntity.State.FALLING:
		change_state(BaseEntity.State.FALLING)

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
	_on_interruption(BaseEntity.Reason.HIT)
	pass # handles knockback cast interrupt_component for more centralized logic

func _on_rooted(duration: float):
	if is_rooted_active:
		return
	is_rooted_active = true
	
	var time_elapsed = 0.0
	print("[player_controller]Applying root for duration %f", duration)
	while time_elapsed <= duration:
		# velocity = Vector2.ZERO # Handled in check_movement_input
		await get_tree().create_timer(0.01).timeout
		time_elapsed += 0.01
	print("[player_controller]Root ended")
	is_rooted_active = false


func _on_slowed(duration: int, slow_amount: float):
	if is_slowed_active:
		return
	is_slowed_active = true
	active_slow_factor = slow_amount

	var time_elapsed = 0.0
	print("[player_controller]Applying slow of amount %f for duration %d", slow_amount, duration)
	while time_elapsed <= duration:
		# velocity *= slow_amount # Handled in check_movement_input
		time_elapsed += 0.01
		await get_tree().create_timer(0.01).timeout
	
	print("[player_controller]Slow ended")
	active_slow_factor = 1.0
	is_slowed_active = false
	
func _ready():
	super._ready()
	add_to_group("Player")
	# 64px tall centered sprite
	feet_offset = 32.0
	# 1. Idle Sprite
	sprite = Sprite2D.new()
	sprite.texture = load("res://art/Inanimate-patas.png")
	sprite.region_enabled = false
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.visible = true
	add_child(sprite)
	# 1.1 Idle moving Sprite
	idle = Sprite2D.new()
	idle.texture = load("res://art/inanimate-anims-idle.png")
	idle.region_enabled = false
	idle.hframes = 8
	idle.vframes = 1
	idle.flip_h = true
	idle.visible = false
	add_child(idle)
	idle_timer = 0.0
	# 1.2 Stationary moving Sprite
	stationary = Sprite2D.new()
	stationary.texture = load("res://art/inanimate-anims-stationary.png")
	stationary.region_enabled = false
	stationary.hframes = 7
	stationary.vframes = 1
	stationary.flip_h = true
	stationary.visible = false
	add_child(stationary)

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

	# 7. Cleave Attack 1 (Front to Back)
	attack2 = Sprite2D.new()
	attack2.texture = load("res://art/inanimate-anims-cast2-instant.png")
	attack2.region_enabled = false
	attack2.hframes = 4
	attack2.vframes = 1
	attack2.visible = false
	attack2.flip_h = true # Assets face left by default
	add_child(attack2)

	# 8. Cleave Attack 2 (Back to Front)
	attack3 = Sprite2D.new()
	attack3.texture = load("res://art/inanimate-anims-cast1-instant.png")
	attack3.region_enabled = false
	attack3.hframes = 4
	attack3.vframes = 1
	attack3.visible = false
	attack3.flip_h = true # Assets face left by default
	add_child(attack3)
	
	# Instantiate Skills
	cleave_swarm_ctrl = load("res://cleave_swarm_controller.gd").new()
	cleave_swarm_ctrl.game_node = game_node
	add_child(cleave_swarm_ctrl)
	
	chain_lightning_ctrl = load("res://with_physics_manager_chain_lightning_controller.gd").new()
	chain_lightning_ctrl.name = "ChainLightningController"
	chain_lightning_ctrl.game_node = game_node # Pass main node for enemy access
	add_child(chain_lightning_ctrl)
	
	fire_chains_ctrl = load("res://with_physics_manager_fire_chains_controller.gd").new()
	fire_chains_ctrl.name = "FireChainsController"
	fire_chains_ctrl.game_node = game_node
	add_child(fire_chains_ctrl)
	
	var meteor_strike_ctrl = load("res://meteor_strike_controller.gd").new()
	meteor_strike_ctrl.name = "MeteorStrikeController"
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

	jump_component = JumpComponent.new(self)
	add_child(jump_component)

	movement_component = MovementComponent.new(self)
	add_child(movement_component)

	action_component = ActionComponent.new(self)
	add_child(action_component)

	knockback_component = KnockbackComponent.new(self)
	add_child(knockback_component)

	interaction_component = InteractionComponent.new(self)
	add_child(interaction_component)

	inventory_component = InventoryComponent.new()
	add_child(inventory_component)

	casting_component = CastingComponent.new(self)
	add_child(casting_component)
	
	interruption_component = InterruptionComponent.new(self)
	add_child(interruption_component)

	# --- SETUP COLLISION ---
	var col = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 16.0
	shape.height = 64.0 # Matches 32.0 feet_offset
	col.shape = shape
	col.position = Vector2(0, 0) # Centered
	add_child(col)


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
	aim_arrow_line.width = 1.0
	aim_arrow_line.default_color = Color(1.0, 1.0, 1.0, 0.6)
	aim_indicator.add_child(aim_arrow_line)
	aim_indicator.visible = false
	aim_indicator.scale = Vector2(0.5, 0.5)
	add_child(aim_indicator)

	# Connect Internal Signals
	interruption_component.interrupted.connect(_on_interruption)
	
	casting_component.cast_started.connect(func(_id, dur): 
		print("[player_controller] recvd cast_started, emit -> cast_started.")
		change_state(State.CASTING)
	)
	casting_component.cast_done.connect(func():
		player_cast_bar.visible = false
		print("[player_controller] recvd cast_done.")
		change_state(State.IDLE)
	)
	casting_component.cast_success.connect(func(spell_id):
		print("[player_controller] recvd cast_success!")
		var spell_data = DataManager.get_spell(spell_id)
		if spell_data:
			if spell_data.has("charge_gen"): add_charge(spell_data.charge_gen)
			if spell_data.has("charge_cost"): consume_charge(spell_data.charge_cost)
		
		state_timer = 0.5 # Animation lock
		player_cast_bar.visible = false
		change_state(State.CASTING_COMPLETE)
	)
	casting_component.cast_failed.connect(func(_reason):
		print("[player_controller] recvd cast_failed.")
		change_state(State.IDLE)
	)

	jump_component.jumped.connect(_on_jumped)
	jump_component.falling.connect(_on_falling)
	jump_component.jump_peak.connect(_on_jump_peak)

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

# --- PHYSICS ---
func _physics_process(delta):
	# 1. Apply Gravity (Standard Godot approach)
	if not is_on_floor():
		var gravity_val = ProjectSettings.get_setting("physics/2d/default_gravity")
		if gravity_val == 0: gravity_val = 980 # Fallback
		
		# In this specific project, PhysicsManager had 800
		gravity_val = 800.0 
		
		velocity.y += gravity_val * gravity_multiplier * delta

	# 2. Update Jump Component - Handles buffers and signals
	jump_component.update(delta)

	# 3. Movement (owned by MovementComponent)
	movement_component.update(delta)

	# 4. Knockback decay
	knockback_component.update(delta)

	# 5. Apply physics
	move_and_slide()

func _process(delta):
	# 2. Main State Machine
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.STATIONARY:
			process_idle(delta)
		State.RUNNING, State.LANDING:
			process_running(delta)
		State.ATTACKING, State.ATTACKING_2, State.ATTACKING_3:
			process_attacking(delta)
		State.CASTING:
			process_casting(delta)
		State.JUMPING, State.JUMP_PEAK, State.FALLING:
			process_jumping(delta)
		State.DASHING, State.LANDING:
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

	# Interaction scanning
	if interaction_component:
		interaction_component.update(delta)

# --- STATE HANDLERS ---

func process_idle(delta):
	idle_timer += delta
	check_movement_input()
	check_action_input()
	update_aim_indicator()
	if current_state == State.IDLE:
		if idle_timer > 5.0:
			idle_timer = 0.0
			change_state(State.STATIONARY)
	elif current_state == State.STATIONARY:
		if idle_timer > 2.0:
			idle_timer = 0.0
			change_state(State.IDLE)

func process_running(_delta):
	check_movement_input()
	check_action_input()
	update_aim_indicator()

	if current_state == State.LANDING:
		# After landing, we want to transition to idle or running based on input
		if input_throttle != 0:
			change_state(State.RUNNING)
		else:
			change_state(State.IDLE)

func process_hurt(delta):
	check_movement_input()
	check_action_input()
	update_aim_indicator()
	if state_timer <= 0:
		change_state(State.IDLE)

func process_attacking(delta):
	velocity.x = 0 # Root while attacking? Or allow slide? Let's root for impact.
	state_timer -= delta
	if state_timer <= 0:
		change_state(State.IDLE)

func process_casting(delta):
	check_movement_input() # Allow air control
	check_action_input()
	update_aim_indicator()
	casting_component.update(delta)
	# --- UI UPDATE ---
	player_cast_bar.visible = true
	player_cast_bar.max_value = casting_component.casting_time
	player_cast_bar.value = casting_component.state_timer
	# emanate some particles of charge
	# -----------------

func process_casting_complete(delta):
	check_movement_input() # Allow air control
	check_action_input()
	update_aim_indicator()

	# --- UI UPDATE ---
	player_cast_bar.max_value = casting_component.casting_time
	# emanate some particles
	#
	# -----------------

	if casting_component.handle_success_animation(delta):
		state_timer = 0.0 # Just in case

func process_jumping(_delta):
	check_movement_input() # Allow air control
	check_action_input()
	update_aim_indicator()

	# Logic now handled by jump_component.update()


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
	
	# interruption_component. update / process


	# Maybe flash yellow/interrupted effect
	if state_timer <= 0:
		change_state(State.IDLE)

func check_movement_input():
	# Delegated to MovementComponent — owns speed computation and velocity.x
	if movement_component:
		movement_component.update(0.0) # delta not critical here; _physics_process calls it with real delta

func check_action_input():
	# Now handled via _on_input_action signals
	pass

# --- SIGNAL HANDLERS FOR KEYBIND LISTENER ---

func _on_input_throttle(val: float):
	input_throttle = val

func _on_input_steer(dir: Vector2):
	input_steer_target = dir

func _on_jump_input():
	if jump_component: 
		jump_component.handle_jump_input()

# instants:
func _on_input_action(action_name: String, data: Dictionary):
	if action_component:
		action_component.handle_action(action_name, data)
		return
	# Fallback for toggle_mouse_steer if action_component fails
	if action_name == "toggle_mouse_steer":
		is_mouse_steering = data.get("active", false)

# LEGACY _try_start_cast removed, moved to CastingComponent

# --- UTILS ---
func sprite_swap():
	_hide_all_sprites()
	var active = get_active_sprite()
	if active: 
		active.visible = true
		# active.position.y = 0
		
		# --- BULLETPROOF REGION-BOUNDED hframes ---
		# We define the 'Real Area' and let Godot's hframes divide only THAT.
		# active.region_enabled = true
		var tex = active.texture
		if tex:
			var total_w = tex.get_width()
			var total_h = tex.get_height()
			
			# Determine frame count and optional junk padding
			var h_cnt = 1
			active.region_enabled = true
			
			# Determine cell width based on texture height (Standard Grid assumption)
			var cell_width = total_w / active.hframes # Square assumption for larger sprites

			# Use the HARDCODED hframes as the source of truth for "How many frames SHOULD be there"
			# This clips any padding/junk at the end of the strip.
			var expected_width = active.hframes * cell_width
			
			# Safety check: If texture is smaller than expected, we can't invent pixels, 
			# but we should still respect the grid.
			if expected_width > total_w:
				# Texture is too small for the declared frames?
				# This implies either wrong hframes or wrong cell_width.
				# Fallback to total_w
				expected_width = total_w
			
			# Set Region
			active.region_enabled = true
			active.region_rect = Rect2(0, 0, expected_width, total_h)
			
			# hframes is already set correctly by _ready logic, but we ensure it matches our region
			# Note: Godot divides region_rect.size.x by hframes.
			# If we set region width to (hframes * 64), then each frame is exactly 64. Perfect.
			active.vframes = 1
			
			# --- AUTO-SCALE ---
			# We want to display at roughly 128px height on screen
			var target_display_size : float = 128.0
			
			# Calculate scale based on the CELL size, not the full texture
			# This ensures consistent size even if texture had junk
			var frame_w = float(cell_width)
			var frame_h = float(total_h)
			
			if(active == stationary):
				frame_w = 128 # we had a problem here with the export for idle 128 vs stationary 64
				frame_h = 128

			var s_x = target_display_size / frame_w
			var s_y = target_display_size / frame_h

			# Apply Scale & Facing
			if (not facing_right):
				active.scale = Vector2(-s_x, s_y)
			else:
				active.scale = Vector2(s_x, s_y)
 
			# --- USER DEBUG PRINT ---
			if Engine.get_process_frames() % 60 == 0:
				print("[player_controller][PlayerPhysics] State: %s | TexW: %d | Frames: %d | Cell: %d" % [
					State.keys()[current_state],
					total_w,
					active.hframes,
					cell_width
				])

		
		# Special colors combined with external lighting
		var state_mod = Color.WHITE
		if active == casting or active == casting_success:
			state_mod = Color(1.0, 1.0, 1.9, 1.0)
		elif current_state == State.STUNNED:
			state_mod = Color(0.5, 0.5, 0.5)
		
		# Multiply state color by lighting color
		active.modulate = state_mod * external_lighting_modulate

func reset_animations():
	sprite_swap()
	for s in [sprite, casting, casting_success, running, jumping, dash, attack1, attack2, attack3, idle, stationary]:
		s.frame = 0

func change_state(new_state):
	if current_state == new_state: return
			
	if current_state == State.ATTACKING and new_state != State.IDLE: # jumping while attacking fix
		return

	# Exit Logic
	if new_state == State.HURT:
		emit_signal("struck")
		return
	reset_animations() # Stop all animations until we set the correct one for the new state

	if current_state == State.CASTING or current_state == State.CASTING_COMPLETE:
		if casting_component.active_skill_ctrl and casting_component.active_skill_ctrl.is_casting:
			casting_component.active_skill_ctrl.interrupt_charging()
		player_cast_bar.visible = false
		casting_success.frame = 0
		casting.frame = 0

	if current_state == State.DASHING or current_state == State.JUMPING:
		# Reset any movement action-specific visuals
		pass

	if current_state == State.INTERRUPTED:
		player_cast_bar.modulate = Color.WHITE
		player_cast_bar.visible = true
		if state_timer > 0:
			return # Can't exit interrupted until timer done

	if current_state == State.STUNNED:
		if state_timer > 0:
			return # Can't exit stunned until timer done
	
	if new_state == State.IDLE:
		idle_timer = 0.0 # Reset idle timer when we enter idle

	current_state = new_state
	# Visibility handled in _process nuclear loop now

	# Enter Logic
	match current_state:
		State.CASTING:
			# --- FLIP DIRECTION SYNC ---
			var dir_is_right = casting_component.casting_direction.x > position.x
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
	attack2.visible = false
	attack3.visible = false
	idle.visible = false
	stationary.visible = false
	# Ensure they are opaque when they DO appear
	sprite.modulate.a = 1.0
	casting.modulate.a = 1.0
	casting_success.modulate.a = 1.0
	running.modulate.a = 1.0
	jumping.modulate.a = 1.0
	dash.modulate.a = 1.0
	attack1.modulate.a = 1.0
	attack2.modulate.a = 1.0
	attack3.modulate.a = 1.0
	idle.modulate.a = 1.0
	stationary.modulate.a = 1.0

func get_active_sprite() -> Sprite2D:
	match current_state:
		State.ATTACKING: return attack1
		State.ATTACKING_2: return attack2
		State.ATTACKING_3: return attack3
		State.RUNNING, State.LANDING: return running
		State.JUMPING, State.JUMP_PEAK, State.FALLING: return jumping
		State.DASHING: return dash
		State.CASTING: return casting
		State.CASTING_COMPLETE: return casting_success
		State.IDLE: return idle
		State.STATIONARY: return stationary
		_: return sprite

func update_animation(_delta):
	sprite_swap()
	# Frame Logic only. 
	# We set .frame here, and _process uses it to calculate region_rect.
	match current_state:
		State.ATTACKING, State.ATTACKING_2, State.ATTACKING_3:
			var active = get_active_sprite()
			var t : float = 0.0
			if(active.frame < active.hframes):
				t = Time.get_ticks_msec() / 100.0 
			active.frame = (int(t)) % active.hframes
		State.CASTING_COMPLETE:
			var h_cnt : int = 0
			var ctrl = casting_component.active_skill_ctrl
			if ctrl:
				var data = DataManager.get_spell(ctrl.get_spell_id() if ctrl.has_method("get_spell_id") else "")
				if data: h_cnt = data.get("success_frames", 8)
			if(casting_success.frame < h_cnt-1): 
				var t : int = int(Time.get_ticks_msec() / 30.0)
				casting_success.frame = int(t) % (h_cnt)
				# print("[player_controller] Casting Success Frame: %d / %d" % [casting_success.frame, h_cnt])
		State.CASTING:
			var t = Time.get_ticks_msec() / 100.0
			var h_cnt : int = 0
			var ctrl = casting_component.active_skill_ctrl
			if ctrl:
				var data = DataManager.get_spell(ctrl.get_spell_id() if ctrl.has_method("get_spell_id") else "")
				if data: h_cnt = data.get("casting_frames", 22)
			casting.frame = int(t) % h_cnt
		State.RUNNING:
			var t = Time.get_ticks_msec() / 100.0 
			running.frame = (int(t)) % running.hframes
		State.JUMPING:
			# Ascending frames
			jumping.frame = 1
		State.JUMP_PEAK:
			jumping.frame = 5
		State.FALLING:
			jumping.frame = 9
		State.DASHING:
			var t = Time.get_ticks_msec() / 50.0 
			dash.frame = (int(t)) % dash.hframes
		State.IDLE:
			var t = Time.get_ticks_msec() / 150.0 
			idle.frame = (int(t)) % idle.hframes
		State.STATIONARY:
			var t = Time.get_ticks_msec() / 200.0 
			stationary.frame = (int(t)) % stationary.hframes

# --- HITBOX HELPERS (For compatibility with Main Scene collision check) ---
const SWORD_HITBOX_SIZE = Vector2(60, 13.3)
const PLAYER_SWORD_HITBOX_OFFSET = Vector2(26.7, 0)


# --- AIM HELPER ---
func update_aim_indicator():
	if is_mouse_steering:
		var dir = casting_component.casting_direction if current_state == State.CASTING else input_steer_target
		aim_indicator.visible = true
		aim_indicator.rotation = (dir - position).angle()
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
	print("[player_controller]Power Surge: %d/%d" % [global_charge, MAX_CHARGE])

func on_interaction_success(_msg, _meta):
	print("[player_controller] recvd CombatManager validation")
	casting_component.last_cast_success = true

func on_interaction_fail(reason: String):
	# If we are currently casting and we get a failure, track it
	if current_state == State.CASTING or current_state == State.CASTING_COMPLETE:
		if reason == "OUT_OF_RANGE" or reason == "TARGET_INVALID":
			print("[player_controller] recvd CombatManager fail")
			casting_component.last_cast_success = false
			# Force jump back to IDLE if the interaction failed mid-cast
			change_state(State.IDLE)
