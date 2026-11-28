extends Node3D
## Standalone first-flight prototype. Open skyhill.tscn and run current scene.

const FLIGHT := preload("res://game/skyhill/flight_model.gd")
const AVATARS := preload("res://game/avatars/catalog.gd")
enum State { DECK, FLYING, MEADOW }
const GROUND_CLEARANCE := 0.85

@onready var launch: Marker3D = $Course/Launch
@onready var meadow: Marker3D = $Course/MeadowCenter
@onready var landing_bounds: BoxShape3D = $Course/MeadowCenter/LandingArea/LandingBounds.shape
@onready var lift_zone: Marker3D = $Course/WaterfallLift
@onready var lift_bounds: CylinderShape3D = $Course/WaterfallLift/LiftArea/LiftBounds.shape
@onready var glider: Node3D = $Glider
@onready var camera: Camera3D = $Camera3D
@onready var hud: CanvasLayer = $HUD
@onready var prompt: Label = $HUD/Top/Instructions
@onready var action: Button = $HUD/Action
@onready var stick: Control = $HUD/Stick
@onready var knob: ColorRect = $HUD/Stick/Knob

var state := State.DECK
var flight := FLIGHT.new()
var touch_index := -1
var touch_steer := 0.0
var _touch_seen := false
var _was_in_lift := false
var _cue: AudioStreamPlayer
var _elapsed := 0.0

func _ready() -> void:
	var rider := AVATARS.instantiate(AVATARS.DEFAULT)
	$Glider/RiderAnchor.add_child(rider)
	action.pressed.connect(_action)
	_touch_seen = DisplayServer.is_touchscreen_available()
	_cue = AudioStreamPlayer.new()
	add_child(_cue)
	_cue.volume_db = -14.0
	_cue.stream = _make_lift_cue()
	_on_deck()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		_action()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_stick()

func _input(event: InputEvent) -> void:
	if state != State.FLYING:
		return
	if event is InputEventScreenTouch and event.pressed and not _touch_seen:
		_touch_seen = true
		stick.show()
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0 and stick.get_global_rect().has_point(event.position):
			touch_index = event.index
			_set_touch(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_index:
			_clear_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_set_touch(event.position)
		get_viewport().set_input_as_handled()

func _set_touch(point: Vector2) -> void:
	var center := stick.get_global_rect().get_center()
	touch_steer = clampf((point.x - center.x) / 40.0, -1.0, 1.0)
	knob.position.x = 38.0 + touch_steer * 35.0

func _clear_stick() -> void:
	touch_index = -1
	touch_steer = 0.0
	if is_instance_valid(knob):
		knob.position.x = 38.0

func _action() -> void:
	match state:
		State.DECK: _launch()
		State.FLYING, State.MEADOW: _on_deck()

func _on_deck() -> void:
	state = State.DECK
	flight.reset(launch.global_position, launch.global_rotation.y)
	_glider_pose()
	_camera_pose(1.0)
	_set_hud("A / D or touch stick to steer", "Launch (E)")

func _launch() -> void:
	state = State.FLYING
	flight.reset(launch.global_position, launch.global_rotation.y)
	_set_hud("Follow the windsocks to the meadow, or catch the rising wind.", "Return to deck (E)")

func _land(where: Vector3) -> void:
	state = State.MEADOW
	flight.position = Vector3(where.x, meadow.global_position.y + GROUND_CLEARANCE, where.z)
	flight.bank = 0.0
	_glider_pose()
	_set_hud("Nice landing! Ready for another flight?", "Ride back up (E)")

func _set_hud(label_text: String, button_text: String) -> void:
	_clear_stick()
	_was_in_lift = false
	prompt.text = label_text
	action.text = button_text
	stick.visible = _touch_seen and state == State.FLYING

func lift_at(point: Vector3) -> float:
	var local := lift_zone.to_local(point)
	if absf(local.y) > lift_bounds.height * 0.5:
		return 0.0
	var distance := Vector2(local.x, local.z).length() / lift_bounds.radius
	return 1.0 - smoothstep(0.65, 1.0, distance)

func in_meadow(point: Vector3) -> bool:
	var local := meadow.to_local(point)
	return absf(local.x) <= landing_bounds.size.x * 0.5 and absf(local.z) <= landing_bounds.size.z * 0.5

func _physics_process(delta: float) -> void:
	if state != State.FLYING:
		return
	var keys := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	step_flight(delta, touch_steer if touch_index >= 0 else keys)

func step_flight(delta: float, steer: float) -> void:
	if state != State.FLYING:
		return
	var prev := flight.position
	var wind := lift_at(prev)
	var next := flight.advance(delta, steer, wind)
	if wind > 0.10 and not _was_in_lift:
		_cue.play()
	_was_in_lift = wind > 0.10
	if next.y <= meadow.global_position.y + GROUND_CLEARANCE and in_meadow(next):
		_land(next)
		return
	var terrain := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(prev, next, 1))
	if not terrain.is_empty() or next.y < meadow.global_position.y - 1.5 or absf(next.x) > 105.0 or next.z < -195.0 or next.z > 65.0:
		_on_deck()
		prompt.text = "Back at the deck. Follow the windsocks for an easy flight."
		return
	_glider_pose()

func _process(delta: float) -> void:
	_elapsed += delta
	var ribbons := $Scenery/UpdraftRibbons
	ribbons.position = lift_zone.position
	for marker: Node3D in ribbons.get_children():
		var initial: float = float(marker.get_meta("base_y", marker.position.y))
		marker.set_meta("base_y", initial)
		marker.position.y = initial + sin(_elapsed * 2.2 + initial * 0.3) * 0.65
	$Scenery/Waterfall/Foam.position.y = -7.35 + sin(_elapsed * 3.0) * 0.06
	_camera_pose(1.0 - exp(-5.0 * delta))

func _glider_pose() -> void:
	glider.global_position = flight.position
	glider.rotation = Vector3(0.0, flight.heading, flight.bank)

func _camera_pose(weight: float) -> void:
	var offset := Vector3(0.0, 4.0, 9.4)
	var focus := Vector3(0.0, 0.8, -6.5)
	if state == State.DECK:
		offset = Vector3(7.8, 8.0, 11.8)
		focus = Vector3(0.0, 0.7, -3.5)
	var target := flight.position + offset.rotated(Vector3.UP, flight.heading)
	camera.global_position = camera.global_position.lerp(target, weight)
	camera.look_at(flight.position + focus.rotated(Vector3.UP, flight.heading), Vector3.UP)

func _make_lift_cue() -> AudioStreamWAV:
	var pcm := PackedByteArray()
	var hz := 22050
	for i in int(hz * 0.34):
		var t := float(i) / hz
		var envelope := sin(PI * t / .34)
		var tone := sin(TAU * (260.0 * t + 350.0 * t * t)) * 0.55 + sin(TAU * (386.0 * t + 430.0 * t * t)) * 0.28
		var sample := int(clampf(envelope * tone, -1.0, 1.0) * 26000.0)
		pcm.append(sample & 255)
		pcm.append((sample >> 8) & 255)
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = hz
	result.data = pcm
	return result
