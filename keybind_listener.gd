extends Node

# KeybindListener Singleton (Autoload)
# Purpose: Translates hardware input into semantic game signals.
# This architecture allows switching between Keyboard/Gamepad or remapping via external data.

# Semantic Signals
signal move_throttle_changed(value: float) # W/S or Joystick Y
signal steer_direction_changed(direction: Vector2) # Mouse pos or AD keys
signal action_triggered(action_name: String, data: Dictionary)

# Action Names Constant (To avoid typos)
const ACTION_JUMP = "jump"
const ACTION_DASH = "dash"
const ACTION_ATTACK = "attack"
const ACTION_SKILL_1 = "chain_lightning"
const ACTION_SKILL_2 = "fire_chains"
const ACTION_ULTIMATE = "meteor_strike"
const ACTION_CLEAVE_SWARM = "cleave_swarm"
const ACTION_INTERACT = "interact"
const ACTION_INVENTORY = "inventory"

# Internal Input Map (Configurable via external DB later)
var key_map = {
	KEY_SPACE: ACTION_JUMP,
	KEY_Z: ACTION_DASH,
	KEY_4: ACTION_ATTACK,
	KEY_3: ACTION_SKILL_1,
	KEY_F: ACTION_SKILL_2,
	KEY_R: ACTION_ULTIMATE,
	KEY_1: ACTION_CLEAVE_SWARM,
	KEY_E: ACTION_INTERACT,
	KEY_I: ACTION_INVENTORY
}

func _unhandled_input(event: InputEvent):
	# Handle key presses (One-shot actions)
	if event is InputEventKey and event.pressed and not event.is_echo():
		if key_map.has(event.keycode):
			var action = key_map[event.keycode]
			emit_signal("action_triggered", action, {"source": "keyboard"})

	# Mouse Right-Click (Special Steer Mode)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		# Just an example of how we might signal state changes
		emit_signal("action_triggered", "toggle_mouse_steer", {"active": event.pressed})

func _process(_delta):
	# Continious Input (Throttle/Steering)
	_process_movement_input()
	# Mouse Right-Click (Special Steer Mode)
	if Input.is_key_pressed(KEY_I):
		print("[KBL] Inventory key pressed")
		emit_signal("action_triggered", "inventory", {})
	if Input.is_key_pressed(KEY_E):
		print("[KBL] Interact key pressed")
		emit_signal("action_triggered", "interact", {})

func _process_movement_input():
	# THROTTLE (Advance/Backup)
	var throttle = 0.0
	if Input.is_key_pressed(KEY_D): throttle += 1.0
	if Input.is_key_pressed(KEY_A): throttle -= 1.0 # Note: Back to -1.0 for Backup logic
	
	# STEERING
	var steer_vec = Vector2.ZERO
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Semantic "Mouse Aim"
		steer_vec = get_viewport().get_mouse_position()
	else:
		# Semantic "Keyboard Turn"
		if Input.is_key_pressed(KEY_A): steer_vec = Vector2.LEFT
		if Input.is_key_pressed(KEY_D): steer_vec = Vector2.RIGHT
	
	# These signals would be watched by the PlayerController
	emit_signal("move_throttle_changed", throttle)
	if steer_vec != Vector2.ZERO:
		emit_signal("steer_direction_changed", steer_vec)
