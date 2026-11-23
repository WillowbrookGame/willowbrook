
extends RefCounted
## Assign a touch once. A tap reserved by a visible HUD button never becomes a look drag.
var _hud: CanvasLayer
var _player: CharacterBody3D
var _jump: Button
var _jump_action: Callable
var _look_stick: Control
var look_motion := Vector2.ZERO
var _stick: Control
var _move_index := -1
var _mouse_stick := false
var _touches: Dictionary = {}
var _look_index := -1
var _emulated_mouse_reserved := false
var _emulated_mouse_retired := false
var _retired: Dictionary = {}


func configure(hud: CanvasLayer, player: CharacterBody3D, jump: Button, jump_action: Callable, stick: Control = null, look_stick: Control = null) -> void:
	_hud = hud
	_player = player
	_jump = jump
	_jump_action = jump_action
	_look_stick = look_stick

	_stick = stick


func release_look() -> void:
	if _look_index >= 0 and _touches.has(_look_index):
		_touches[_look_index] = {"kind":"idle"}
	_look_index = -1
	look_motion = Vector2.ZERO
	if is_instance_valid(_look_stick):
		_look_stick.recenter()


func reset_movement() -> void:
	if _move_index >= 0 and _touches.has(_move_index):
		_touches[_move_index] = {"kind":"idle"}
	_move_index = -1
	_mouse_stick = false
	if is_instance_valid(_stick):
		_stick.recenter()
	if is_instance_valid(_player):
		_player.touch_motion = Vector2.ZERO


func reset() -> void:
	reset_movement()
	for finger in _touches:
		_retired[finger] = true
	while _retired.size() > 32:
		_retired.erase(_retired.keys()[0])
	release_look()
	_touches.clear()
	_emulated_mouse_retired = _emulated_mouse_retired or _emulated_mouse_reserved
	_emulated_mouse_reserved = false

func _hit(button: Button, point: Vector2) -> bool:
	return is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point)


func _button_at(point: Vector2) -> Button:
	# In a HUD the direct controls are jump/interact, fishing buttons, and utility menus.
	# Modal windows deliberately keep native Godot GUI rather than this action routing.
	if not is_instance_valid(_hud):
		return null
	for i in range(_hud.get_child_count() - 1,-1,-1):
		var button := _hud.get_child(i) as Button
		if _hit(button,point):
			return button
	return null


func _move_stick(point: Vector2) -> void:
	if is_instance_valid(_player) and is_instance_valid(_stick):
		_player.touch_motion = _stick.aim_at(point)


func route(event: InputEvent, blocked: bool) -> bool:
	# Godot may emit a paired synthetic mouse event even if the physical touch was
	# handled. Suppress that pair only for world touches, never newer modal presses.
	if blocked and (not _touches.is_empty() or _mouse_stick or _emulated_mouse_reserved):
		reset()
	if event.device == -1 and event is InputEventMouse:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_emulated_mouse_retired = false
				_emulated_mouse_reserved = not blocked
				return _emulated_mouse_reserved
			var reserved := _emulated_mouse_reserved or _emulated_mouse_retired
			_emulated_mouse_retired = false
			_emulated_mouse_reserved = false
			return reserved
		return _emulated_mouse_reserved or _emulated_mouse_retired
	# End/reset pairs can arrive after a modal opens or after the browser
	# cancels old fingers. Don't let them activate an unrelated GUI button.
	if event is InputEventScreenTouch and _retired.has(event.index):
		if not event.pressed or event.canceled:
			_retired.erase(event.index)
			return true
		_retired.erase(event.index) # a new physical press reusing an index
	if event is InputEventScreenDrag and _retired.has(event.index):
		return true
	if blocked:
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _mouse_stick:
			reset_movement()
			return true
		if event.pressed and _button_at(event.position) == null and is_instance_valid(_stick) and _stick.contains_point(event.position):
			if _move_index < 0:
				_mouse_stick = true
				_move_stick(event.position)
			return true
	elif event is InputEventMouseMotion and _mouse_stick:
		_move_stick(event.position)
		return true
	if event is InputEventScreenTouch:
		var finger: int = event.index
		if not event.pressed or event.canceled:
			if not _touches.has(finger):
				return false
			var owner: Dictionary = _touches[finger]
			_touches.erase(finger)
			if finger == _look_index:
				release_look()
			if owner.kind == "move" and finger == _move_index:
				reset_movement()
			elif owner.kind == "button" and not event.canceled and _hit(owner.button,event.position):
				(owner.button as Button).pressed.emit()
			return true
		if _touches.has(finger):
			return true
		var button := _button_at(event.position)
		if button != null:
			if button == _jump:
				_touches[finger] = {"kind":"idle"}
				_jump_action.call()
			else:
				_touches[finger] = {"kind":"button","button":button}
		elif is_instance_valid(_stick) and _stick.contains_point(event.position):
			if _move_index < 0 and not _mouse_stick:
				_move_index = finger
				_touches[finger] = {"kind":"move"}
				_move_stick(event.position)
			else:
				_touches[finger] = {"kind":"idle"}
		elif is_instance_valid(_look_stick) and _look_stick.contains_point(event.position):
			if _look_index < 0:
				_look_index = finger
				_touches[finger] = {"kind":"look"}
				look_motion = _look_stick.aim_at(event.position)
			else:
				_touches[finger] = {"kind":"idle"}
		else:
			_touches[finger] = {"kind":"idle"}
		return true
	if event is InputEventScreenDrag:
		if event.index == _move_index:
			_move_stick(event.position)
		elif event.index == _look_index:
			look_motion = _look_stick.aim_at(event.position)
		return _touches.has(event.index)
	return false


