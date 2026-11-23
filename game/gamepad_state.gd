extends RefCounted
## One active standard controller, with physical neutral required after a context reset.
const DEADZONE := .19
const TRIGGER_ON := .58
const TRIGGER_OFF := .33
var device := -1
var _left := Vector2.ZERO
var _right := Vector2.ZERO
var _trigger := 0.0
var _a := false
var _x := false
var _left_ready := true
var _right_ready := true
var _trigger_ready := true

static func accepts(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y,JOY_AXIS_TRIGGER_RIGHT]
	if event is InputEventJoypadButton:
		return event.button_index in [JOY_BUTTON_A,JOY_BUTTON_X]
	return false

static func _deadzone(raw: Vector2) -> Vector2:
	var magnitude := minf(raw.length(),1.0)
	if magnitude <= DEADZONE:
		return Vector2.ZERO
	return raw.normalized() * inverse_lerp(DEADZONE,1.0,magnitude)

func move() -> Vector2:
	return _deadzone(_left) if _left_ready else Vector2.ZERO

func look() -> Vector2:
	return _deadzone(_right) if _right_ready else Vector2.ZERO

func suspend() -> void:
	_left_ready = _left.length() <= DEADZONE
	_right_ready = _right.length() <= DEADZONE
	_trigger_ready = _trigger <= TRIGGER_OFF
	# Button shadow states are deliberately retained: held A/X do not re-trigger.

func follow_connected() -> void:
	if device >= 0:
		return
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		attach(pads[0])

func attach(id: int) -> void:
	device = id
	_left = Vector2(Input.get_joy_axis(id,JOY_AXIS_LEFT_X),Input.get_joy_axis(id,JOY_AXIS_LEFT_Y))
	_right = Vector2(Input.get_joy_axis(id,JOY_AXIS_RIGHT_X),Input.get_joy_axis(id,JOY_AXIS_RIGHT_Y))
	_trigger = Input.get_joy_axis(id,JOY_AXIS_TRIGGER_RIGHT)
	_a = Input.is_joy_button_pressed(id,JOY_BUTTON_A)
	_x = Input.is_joy_button_pressed(id,JOY_BUTTON_X)
	suspend()

func detach_device(id: int) -> void:
	if id != device:
		return
	device = -1
	_left = Vector2.ZERO
	_right = Vector2.ZERO
	_trigger = 0.0
	_a = false
	_x = false
	suspend()

func update(event: InputEvent, blocked: bool) -> String:
	if device == -1:
		device = event.device
	if event.device != device:
		return ""
	var action := ""
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A:
			if event.pressed and not _a:
				action = "jump"
			_a = event.pressed
		elif event.button_index == JOY_BUTTON_X:
			if event.pressed and not _x:
				action = "interact"
			_x = event.pressed
	elif event is InputEventJoypadMotion:
		var value := clampf(event.axis_value,-1.0,1.0)
		match event.axis:
			JOY_AXIS_LEFT_X: _left.x = value
			JOY_AXIS_LEFT_Y: _left.y = value
			JOY_AXIS_RIGHT_X: _right.x = value
			JOY_AXIS_RIGHT_Y: _right.y = value
			JOY_AXIS_TRIGGER_RIGHT:
				_trigger = value
				if value <= TRIGGER_OFF:
					_trigger_ready = true
				elif _trigger_ready and value >= TRIGGER_ON:
					_trigger_ready = false
					action = "primary"
		if _left.length() <= DEADZONE:
			_left_ready = true
		if _right.length() <= DEADZONE:
			_right_ready = true
	if blocked:
		suspend()
		return ""
	return action