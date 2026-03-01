extends Node

class_name ActionComponent

## ActionComponent
## Handles all action keybind → game interaction dispatch for the player.
## Called from PlayerController._on_input_action() — keeps the match block out of PlayerController.

var _player
signal aim_direction_changed(direction: Vector2)

func _init(player) -> void:
	_player = player

## Main dispatch. Called by PlayerController._on_input_action().
func handle_action(action_name: String, data: Dictionary) -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("is_incapacitated") and _player.is_incapacitated(): 
		return
	match action_name:
		"mouse_direction":
			# Use global space, not viewport screen space, for accurate aiming
			var aim_direction : Vector2 = (_player.get_global_mouse_position() - _player.global_position).normalized()
			emit_signal("aim_direction_changed", aim_direction)
		"inventory":
			if _player.inventory_component:
				_player.inventory_component._on_action(action_name, data)
		"toggle_mouse_steer":
			_player.is_mouse_steering = data.get("active", false)

		"jump":
			if _player.jump_component:
				_player.jump_component.handle_jump_input()

		"dash":
			var s = _player.current_state
			if s != _player.State.JUMPING and s != _player.State.JUMP_PEAK \
			   and s != _player.State.FALLING and s != _player.State.DASHING:
				_player.emit_signal("dashed")

		# --- INSTANT ATTACKS ---
		"attack":
			if _player.current_state != _player.State.ATTACKING:
				_player.change_state(_player.State.ATTACKING)
				_player.state_timer = _player.ATTACK_DURATION
				if is_instance_valid(_player.axe_ctrl):
					_player.axe_ctrl.start_attack()

		"cleave_swarm":
			var s = _player.current_state
			if s != _player.State.ATTACKING and s != _player.State.ATTACKING_2 \
			   and s != _player.State.ATTACKING_3:
				if _player.input_throttle != 0:
					_player.facing_right = _player.input_throttle > 0
				_player.cleave_count += 1
				var type = 1 if _player.cleave_count % 2 == 1 else 2
				_player.change_state(_player.State.ATTACKING_2 if type == 1 else _player.State.ATTACKING_3)
				_player.state_timer = _player.ATTACK_DURATION * 2
				if is_instance_valid(_player.cleave_swarm_ctrl):
					_player.cleave_swarm_ctrl.cast_cleave(type)

		# --- CAST SKILLS ---
		"fire_chains":
			var ctrl = _player.get_node_or_null("FireChainsController")
			_player.casting_component.try_start_cast(ctrl, "fire_chains", _player.global_charge)

		"chain_lightning":
			var s = _player.current_state
			if s != _player.State.JUMPING and s != _player.State.DASHING \
			   and s != _player.State.JUMP_PEAK and s != _player.State.FALLING:
				var ctrl = _player.get_node_or_null("ChainLightningController")
				_player.casting_component.try_start_cast(ctrl, "chain_lightning", _player.global_charge)

		"meteor_strike":
			var s = _player.current_state
			if s != _player.State.JUMPING and s != _player.State.DASHING \
			   and s != _player.State.JUMP_PEAK and s != _player.State.FALLING:
				var ctrl = _player.get_node_or_null("MeteorStrikeController")
				_player.casting_component.try_start_cast(ctrl, "meteor_strike", _player.global_charge)
