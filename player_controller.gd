extends BaseEntity

class_name PlayerController

# --- CONFIG ---
const SPEED = 600.0
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

# --- NEW LAYERED SPRITES (Split Body/Legs) ---
var body_running_idle: Sprite2D
var legs_running_idle: Sprite2D
var body_running: Sprite2D
var legs_running: Sprite2D
var body_jumping: Sprite2D
var legs_jumping: Sprite2D
var body_dash: Sprite2D
var legs_dash: Sprite2D

var body_combat: Sprite2D
var legs_combat: Sprite2D
var body_hurt: Sprite2D
var legs_hurt: Sprite2D
var body_knockdown: Sprite2D
var legs_knockdown: Sprite2D
var body_cast1: Sprite2D
var legs_cast1: Sprite2D
var body_cast2: Sprite2D
var legs_cast2: Sprite2D

var current_body_layer: Sprite2D
var current_legs_layer: Sprite2D

var body_landing: Sprite2D
var legs_landing: Sprite2D
# ---------------------------------------------

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
var aim_component: AimComponent
# var knockback_component: KnockbackComponent moved to baseentity
var interaction_component: InteractionComponent
var inventory_component: InventoryComponent

# --- INPUT STATE (Populated by KeybindListener) ---
var input_throttle = 0.0
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
	if current_state == State.CASTING:
		casting_component.interrupt(reason)

	match (reason):
		BaseEntity.Reason.SILENCED, BaseEntity.Reason.KICKED:
			casting_component.emit_signal("cast_locked_out", INTERRUPTED_DURATION)
			state_timer = INTERRUPTED_DURATION
			change_state(State.INTERRUPTED)

		BaseEntity.Reason.PARRIED:
			if current_state == State.ATTACKING or current_state == State.ATTACKING_2 or current_state == State.ATTACKING_3:
				change_state(State.STUNNED)

		BaseEntity.Reason.STUNNED:
			change_state(State.STUNNED)
		
		BaseEntity.Reason.HIT:
			if current_state == BaseEntity.State.CASTING or current_state == State.ATTACKING or current_state == State.ATTACKING_2 or current_state == State.ATTACKING_3:
				casting_component.interrupt(reason)
		
		BaseEntity.Reason.OTHER:
			change_state(State.IDLE)

func apply_hit(amount: float, source: Node2D):
	if source and source.is_in_group("ArcaneMissile"):
		# Knockdown interrupts EVERYTHING
		casting_component.interrupt(BaseEntity.Reason.HIT)
		
		if current_state != State.KNOCKDOWN:
			change_state(State.KNOCKDOWN)
			state_timer = 1.0 # 1 second knockdown
			
			var dir = (global_position - source.global_position).normalized()
			if dir == Vector2.ZERO: dir = Vector2.UP
			
			knockback_component.apply_impulse(dir, 100.0)

		return
		
	# Standard hit
	state_timer = 0.2
	change_state(State.HURT)

func _on_jumped():
	print("[player_controller]Player jumped!")
	if (is_rooted_active):
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
	if self.is_incapacitated():
		return
	if current_state != BaseEntity.State.FALLING:
		change_state(BaseEntity.State.FALLING)

func _on_dashed():
	if (is_rooted_active):
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
	running.texture = load("res://art/RunningAnimsBodyLegs/RunningAnimsBody-Run.png")
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

	# --- LAYERED SPRITES INITIALIZATION ---
	# 1. Idle (Layered) - 3 Frames
	body_running_idle = Sprite2D.new()
	body_running_idle.texture = load("res://art/RunningAnimsBodyLegs/RunningAnimsBody-Idle.png")
	body_running_idle.hframes = 3
	body_running_idle.visible = false
	add_child(body_running_idle)
	
	legs_running_idle = Sprite2D.new()
	legs_running_idle.texture = load("res://art/RunningAnimsBodyLegs/RunningAnimsLegs-Idle.png")
	legs_running_idle.hframes = 3
	legs_running_idle.visible = false
	add_child(legs_running_idle)

	# 2. Running (Layered) - 8 Frames
	body_running = Sprite2D.new()
	body_running.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsBody-Run.png")
	body_running.hframes = 8
	body_running.visible = false
	add_child(body_running)
	
	legs_running = Sprite2D.new()
	legs_running.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsLegs-Run.png")
	legs_running.hframes = 8
	legs_running.visible = false
	add_child(legs_running)

	# 3. Jumping (Layered) - 11 Frames
	body_jumping = Sprite2D.new()
	body_jumping.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsBody-Jump.png")
	body_jumping.hframes = 11
	body_jumping.visible = false
	add_child(body_jumping)
	
	legs_jumping = Sprite2D.new()
	legs_jumping.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsLegs-Jump.png")
	legs_jumping.hframes = 11
	legs_jumping.visible = false
	add_child(legs_jumping)

	# 4. Dash (Layered) - 7 Frames (Assuming same frame count as old dash)
	body_dash = Sprite2D.new()
	body_dash.texture = load("res://art/RunningAnimsBodyLegs/RunningAnimsBody-Shoulder Dash.png")
	body_dash.hframes = 7
	body_dash.visible = false
	add_child(body_dash)
	
	legs_dash = Sprite2D.new()
	legs_dash.texture = load("res://art/RunningAnimsBodyLegs/RunningAnimsLegs-Shoulder Dash.png")
	legs_dash.hframes = 7
	legs_dash.visible = false
	add_child(legs_dash)

	# 5. Combat (Layered) - 3 Frames
	body_combat = Sprite2D.new()
	body_combat.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsBody-Combat.png")
	body_combat.hframes = 3
	body_combat.visible = false
	add_child(body_combat)
	
	legs_combat = Sprite2D.new()
	legs_combat.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsLegs-Combat.png")
	legs_combat.hframes = 3
	legs_combat.visible = false
	add_child(legs_combat)

	# 6. Hurt (Layered) - 2 Frames
	body_hurt = Sprite2D.new()
	body_hurt.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsBody-Hurt.png")
	body_hurt.hframes = 2
	body_hurt.visible = false
	add_child(body_hurt)
	
	legs_hurt = Sprite2D.new()
	legs_hurt.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsLegs-Hurt.png")
	legs_hurt.hframes = 2
	legs_hurt.visible = false
	add_child(legs_hurt)

	# 7. Knockdown (Layered) - 6 Frames
	body_knockdown = Sprite2D.new()
	body_knockdown.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsBody-Knockdown.png")
	body_knockdown.hframes = 6
	body_knockdown.visible = false
	add_child(body_knockdown)
	
	legs_knockdown = Sprite2D.new()
	legs_knockdown.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsLegs-Knockdown.png")
	legs_knockdown.hframes = 6
	legs_knockdown.visible = false
	add_child(legs_knockdown)
	
	# 8. Cast 1 (Layered) - 6 Frames
	body_cast1 = Sprite2D.new()
	body_cast1.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsBody-Cast1.png")
	body_cast1.hframes = 6
	body_cast1.visible = false
	add_child(body_cast1)
	
	legs_cast1 = Sprite2D.new()
	legs_cast1.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsLegs-Cast1.png")
	legs_cast1.hframes = 6
	legs_cast1.visible = false
	add_child(legs_cast1)

	# 9. Cast 2 (Layered) - 6 Frames
	body_cast2 = Sprite2D.new()
	body_cast2.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsBody-Cast2.png")
	body_cast2.hframes = 6
	body_cast2.visible = false
	add_child(body_cast2)
	
	legs_cast2 = Sprite2D.new()
	legs_cast2.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsLegs-Cast2.png")
	legs_cast2.hframes = 6
	legs_cast2.visible = false
	add_child(legs_cast2)
	
	# 10. Landing (Layered) - 6 Frames
	body_landing = Sprite2D.new()
	body_landing.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsBody-Landing.png")
	body_landing.hframes = 6
	body_landing.visible = false
	add_child(body_landing)
	
	legs_landing = Sprite2D.new()
	legs_landing.texture = load("res://art/64by64RunningAnimsBodyLegs/64by64RunningAnimsLegs-Landing.png")
	legs_landing.hframes = 6
	legs_landing.visible = false
	add_child(legs_landing)
	
	# --------------------------------------
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
	
	meteor_strike_ctrl = load("res://meteor_strike_controller.gd").new()
	meteor_strike_ctrl.name = "MeteorStrikeController"
	meteor_strike_ctrl.game_node = game_node
	add_child(meteor_strike_ctrl)
	
	jump_component = JumpComponent.new(self )
	add_child(jump_component)

	movement_component = MovementComponent.new(self )
	add_child(movement_component)

	action_component = ActionComponent.new(self )
	add_child(action_component)

	aim_component = AimComponent.new(self )
	add_child(aim_component)

	interaction_component = InteractionComponent.new(self )
	add_child(interaction_component)

	inventory_component = InventoryComponent.new()
	add_child(inventory_component)

	casting_component = CastingComponent.new(self )
	add_child(casting_component)
	
	interruption_component = InterruptionComponent.new(self )
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
	

	# Connect Internal Signals
	interruption_component.interrupted.connect(_on_interruption)
	
	casting_component.cast_started.connect(func(dur):
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
		KeybindListener.action_triggered.connect(_on_input_action)

func _exit_tree():
	if CombatManager:
		CombatManager.unregister_entity(self )

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
	velocity += knockback_component.current_velocity

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
		State.DASHING:
			process_dashing(delta)
		State.LANDING:
			process_running(delta) # Landing is a subset of movement logic now
		State.KNOCKDOWN:
			process_knockdown(delta)
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
		state_timer -= _delta
		if state_timer <= 0:
			if input_throttle != 0:
				change_state(State.RUNNING)
			else:
				change_state(State.IDLE)

func process_knockdown(delta):
	state_timer -= delta
	print("[player_controller] Knockdown timer: %f", state_timer)
	if state_timer <= 0:
		change_state(State.IDLE)

func process_hurt(delta):
	check_movement_input()
	check_action_input()
	update_aim_indicator()
	if state_timer <= 0:
		change_state(State.IDLE)

func process_attacking(delta):
	check_movement_input()
	check_action_input()
	update_aim_indicator()
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

func _on_jump_input():
	if jump_component:
		jump_component.handle_jump_input()

# instants:
func _on_input_action(action_name: String, data: Dictionary):
	if action_component:
		action_component.handle_action(action_name, data)
		return

# LEGACY _try_start_cast removed, moved to CastingComponent

# --- UTILS ---
func sprite_swap():
	_hide_all_sprites()
	var actives = get_active_sprites()
	for active in actives:
		if not is_instance_valid(active): continue
		active.visible = true
		# active.position.y = 0
		
		# --- BULLETPROOF REGION-BOUNDED hframes ---
		var tex = active.texture
		if tex:
			var total_w = tex.get_width()
			var total_h = tex.get_height()
			
			active.region_enabled = true
			var cell_width = total_w / active.hframes

			var expected_width = active.hframes * cell_width
			
			if expected_width > total_w:
				expected_width = total_w
			
			active.region_enabled = true
			active.region_rect = Rect2(0, 0, expected_width, total_h)
			active.vframes = 1
			
			# --- AUTO-SCALE ---
			var target_display_size: float = 128.0
			
			# SKIP SCALING for 64x64 folder assets - they should be 1:1 (rendered at 64px)
			if active.texture.resource_path.contains("64by64"):
				target_display_size = 64.0
			
			var frame_w = float(cell_width)
			var frame_h = float(total_h)
			
			if (active == stationary):
				frame_w = 128
				frame_h = 128

			var s_x = target_display_size / frame_w
			var s_y = target_display_size / frame_h

			# Apply Scale & Facing
			if (not facing_right):
				active.scale = Vector2(-s_x, s_y)
			else:
				active.scale = Vector2(s_x, s_y)

		
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
	var all_renderers = [
		sprite, casting, casting_success, running, jumping, dash,
		attack1, attack2, attack3, idle, stationary,
		body_running_idle, legs_running_idle, body_running, legs_running,
		body_jumping, legs_jumping, body_dash, legs_dash
	]
	for s in all_renderers:
		if is_instance_valid(s):
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
	
	if new_state == State.LANDING:
		state_timer = 0.3 # Duration of landing animation

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
	var all_sprites = [
		sprite, casting, casting_success, running, jumping, dash,
		attack1, attack2, attack3, idle, stationary,
		body_running_idle, legs_running_idle,
		body_running, legs_running,
		body_jumping, legs_jumping,
		body_dash, legs_dash,
		body_combat, legs_combat,
		body_hurt, legs_hurt,
		body_knockdown, legs_knockdown,
		body_cast1, legs_cast1, body_cast2, legs_cast2,
		body_landing, legs_landing
	]
	for s in all_sprites:
		if is_instance_valid(s):
			s.visible = false
			s.modulate.a = 1.0

func get_active_sprites() -> Array:
	var leg_layers = []
	if not is_on_floor():
		leg_layers = [legs_jumping]
	elif velocity.length() > 50:
		leg_layers = [legs_running]
	else:
		# Standalone state case logic below
		pass

	match current_state:
		State.ATTACKING:
			if leg_layers.size() > 0: return [attack1] + leg_layers
			return [attack1]
		State.ATTACKING_2:
			if leg_layers.size() > 0: return [body_cast2] + leg_layers
			return [body_cast2, legs_cast2]
		State.ATTACKING_3:
			if leg_layers.size() > 0: return [body_cast1] + leg_layers
			return [body_cast1, legs_cast1]
		State.RUNNING: return [body_running, legs_running]
		State.LANDING: return [body_landing, legs_landing]
		State.JUMPING, State.JUMP_PEAK, State.FALLING: return [body_jumping, legs_jumping]
		State.DASHING: return [body_dash, legs_dash]
		State.CASTING: return [casting]
		State.CASTING_COMPLETE: return [casting_success]
		State.HURT: return [body_hurt, legs_hurt]
		State.KNOCKDOWN: return [body_knockdown, legs_knockdown]
		State.COMBAT:
			if leg_layers.size() > 0: return [body_combat] + leg_layers
			return [body_combat, legs_combat]
		State.IDLE:
			# Automatically swap to Combat Stance if enemies near
			var in_combat_range = false
			for e in get_tree().get_nodes_in_group("Enemy"):
				if e.global_position.distance_to(global_position) < 250.0:
					in_combat_range = true
					break
			if in_combat_range:
				if leg_layers.size() > 0: return [body_combat] + leg_layers
				return [body_combat, legs_combat]
			return [body_running_idle, legs_running_idle]
		State.STATIONARY: return [stationary]
		_: return [sprite]

func update_animation(_delta):
	sprite_swap()
	# Frame Logic only. 
	# We set .frame here, and _process uses it to calculate region_rect.
	match current_state:
		State.ATTACKING, State.ATTACKING_2, State.ATTACKING_3:
			var actives = get_active_sprites()
			# Map 0.3s ATTACK_DURATION to 6 frames roughly (50ms per frame)
			var t = Time.get_ticks_msec() / 50.0
			for active in actives:
				if is_instance_valid(active):
					active.frame = (int(t)) % active.hframes
		State.CASTING_COMPLETE:
			var h_cnt: int = 0
			var ctrl = casting_component.active_skill_ctrl
			if ctrl:
				var data = DataManager.get_spell(ctrl.get_spell_id() if ctrl.has_method("get_spell_id") else "")
				if data: h_cnt = data.get("success_frames", 8)
			if (casting_success.frame < h_cnt - 1):
				var t: int = int(Time.get_ticks_msec() / 30.0)
				casting_success.frame = int(t) % (h_cnt)
		State.CASTING:
			var t = Time.get_ticks_msec() / 100.0
			var h_cnt: int = 0
			var ctrl = casting_component.active_skill_ctrl
			if ctrl:
				var data = DataManager.get_spell(ctrl.get_spell_id() if ctrl.has_method("get_spell_id") else "")
				if data: h_cnt = data.get("casting_frames", 22)
			casting.frame = int(t) % h_cnt
		State.RUNNING:
			var t = Time.get_ticks_msec() / 100.0
			body_running.frame = (int(t)) % body_running.hframes
			legs_running.frame = (int(t)) % legs_running.hframes
		State.JUMPING:
			var t = Time.get_ticks_msec() / 100.0
			body_jumping.frame = clamp(int(t) % 11, 0, 5)
			legs_jumping.frame = clamp(int(t) % 11, 0, 5)
		State.JUMP_PEAK:
			body_jumping.frame = 6
			legs_jumping.frame = 6
		State.FALLING:
			body_jumping.frame = 9
			legs_jumping.frame = 9
		State.DASHING:
			var t = Time.get_ticks_msec() / 50.0
			body_dash.frame = (int(t)) % body_dash.hframes
			legs_dash.frame = (int(t)) % legs_dash.hframes
		State.IDLE, State.COMBAT:
			var t = Time.get_ticks_msec() / 150.0
			var active_body = body_combat if current_state == State.COMBAT else body_running_idle
			var active_legs = legs_combat if current_state == State.COMBAT else legs_running_idle
			
			# Internal logic: get_active_sprites might have returned combat due to proximity
			var current_actives = get_active_sprites()
			if body_combat in current_actives:
				body_combat.frame = (int(t)) % body_combat.hframes
				legs_combat.frame = (int(t)) % legs_combat.hframes
			else:
				body_running_idle.frame = (int(t)) % body_running_idle.hframes
				legs_running_idle.frame = (int(t)) % legs_running_idle.hframes
		State.LANDING:
			var t = Time.get_ticks_msec() / 100.0
			body_landing.frame = (int(t)) % body_landing.hframes
			legs_landing.frame = (int(t)) % legs_landing.hframes
		State.HURT:
			var t = Time.get_ticks_msec() / 100.0
			body_hurt.frame = (int(t)) % body_hurt.hframes
			legs_hurt.frame = (int(t)) % legs_hurt.hframes
		State.KNOCKDOWN:
			var t = Time.get_ticks_msec() / 100.0
			# First 4 frames are the flicnh/tumble
			if state_timer > 0.8:
				body_knockdown.frame = (int(t)) % 4
				legs_knockdown.frame = (int(t)) % 4
			elif velocity.length() > 50.0:
				body_knockdown.frame = 3
				legs_knockdown.frame = 3
			else:
				body_knockdown.frame = 5
				legs_knockdown.frame = 5
		State.STATIONARY:
			var t = Time.get_ticks_msec() / 200.0
			stationary.frame = (int(t)) % stationary.hframes

# --- HITBOX HELPERS (For compatibility with Main Scene collision check) ---
const SWORD_HITBOX_SIZE = Vector2(60, 13.3)
const PLAYER_SWORD_HITBOX_OFFSET = Vector2(26.7, 0)


# --- AIM HELPER ---
func update_aim_indicator():
	if aim_component and aim_component.is_active:
		aim_component.update()


func get_sword_hitbox() -> Rect2:
	if current_state != State.ATTACKING: return Rect2()
	
	var offset = PLAYER_SWORD_HITBOX_OFFSET
	if not facing_right: offset.x = - offset.x
	
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
			casting_component.interrupt(BaseEntity.Reason.FAILED)
			print("[player_controller] recvd CombatManager fail")
			casting_component.last_cast_success = false
			# Force jump back to IDLE if the interaction failed mid-cast
			change_state(State.IDLE)
