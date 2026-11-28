extends Node3D
## Standalone first-flight prototype. Open skyhill.tscn and run current scene.

const FLIGHT := preload("res://game/skyhill/flight_model.gd")
const AVATARS := preload("res://game/avatars/catalog.gd")
const TOWN_LINK := preload("res://game/skyhill/town_link.gd")
enum State { DECK, FLYING, LANDING, MEADOW, CRASHED }
const GROUND_CLEARANCE := 0.85
const CRASH_TUMBLE_TIME := 0.65
const CRASH_HOLD_TIME := 2.0
const COURSE_MASK := 1
const POLE_MASK := 2
const WING_OFFSET := Vector3(0.0, 0.65, 0.75)
const FLIGHT_KEYS := [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_S, KEY_UP, KEY_DOWN]
const CLIMB_ABOVE_LAUNCH := 4.0
const KEY_HINT := "A/D or Left/Right to steer. W descends, S climbs."
const TOUCH_HINT := "Drag left/right to steer, up to descend, down to climb."
const ROUTE_HINT := "\nGlide straight to land, or head right for waterfall lift."

@onready var launch: Marker3D = $Course/Launch
@onready var meadow: Marker3D = $Course/MeadowCenter
@onready var landing_bounds: BoxShape3D = $Course/MeadowCenter/LandingArea/LandingBounds.shape
@onready var lift_zone: Marker3D = $Course/WaterfallLift
@onready var lift_bounds: CylinderShape3D = $Course/WaterfallLift/LiftArea/LiftBounds.shape
@onready var glider: Node3D = $Glider
@onready var camera: Camera3D = $Camera3D
@onready var hud: CanvasLayer = $HUD
@onready var guide: PanelContainer = $HUD/WaterfallGuide
@onready var guide_label: Label = $HUD/WaterfallGuide/Caption
@onready var prompt: Label = $HUD/Top/Instructions
@onready var action: Button = $HUD/Action
@onready var town_return: Button = $HUD/TownReturn
@onready var stick: Control = $HUD/Stick
@onready var knob: ColorRect = $HUD/Stick/Knob
@onready var walk_stick: Control = $HUD/WalkStick
@onready var walker: CharacterBody3D = $Scenery/Overlook/Walker

var state := State.DECK
var flight := FLIGHT.new()
var touch_index := -1
var touch_steer := 0.0
var touch_pitch := 0.0
var _walk_touch := Vector2.ZERO
var _touch_seen := false
var _was_in_lift := false
var _cue: AudioStreamPlayer
var _elapsed := 0.0
var _town_visit := false
var _returning_to_town := false
var _crash_elapsed := 0.0
var _crash_rotation := Vector3.ZERO
var _crash_side := 1.0
var _crash_normal := Vector3.UP
var _pole_wing := BoxShape3D.new()
var _pole_query := PhysicsShapeQueryParameters3D.new()

var _flight_keys := {}
var _app_unfocused := false
var _tab_hidden := false
var _paused := false
var _pause_prompt := ""
var _pause_action := ""
var _document: JavaScriptObject
var _visibility_callback: JavaScriptObject

func _ready() -> void:
	var avatar := TOWN_LINK.take_arrival(get_tree())
	_town_visit = not avatar.is_empty()
	var rider := AVATARS.instantiate(avatar)
	$Glider/RiderAnchor.add_child(rider)
	if _town_visit:
		walker.equip(avatar)
	action.pressed.connect(_action)
	town_return.pressed.connect(_return_to_town)
	_touch_seen = DisplayServer.is_touchscreen_available()
	_cue = AudioStreamPlayer.new()
	add_child(_cue)
	_cue.volume_db = -14.0
	_cue.stream = _make_lift_cue()
	_pole_wing.size = Vector3(7.2, 0.36, 0.48)
	_pole_query.shape = _pole_wing
	_pole_query.collision_mask = POLE_MASK
	_on_deck()

	if OS.has_feature("web"):
		_document = JavaScriptBridge.get_interface("document")
		if _document != null:
			_visibility_callback = JavaScriptBridge.create_callback(_visibility_changed)
			_document.addEventListener("visibilitychange", _visibility_callback)
			_visibility_changed([])

func _exit_tree() -> void:
	if _document != null and _visibility_callback != null:
		_document.removeEventListener("visibilitychange", _visibility_callback)
	_visibility_callback = null
	_document = null

func _visibility_changed(_arguments: Array) -> void:
	_tab_hidden = bool(_document.hidden)
	_update_suspension()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_E:
		_action()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_R and town_return.visible:
		get_viewport().set_input_as_handled()
		_return_to_town()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_app_unfocused = true
		_update_suspension()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_app_unfocused = false
		_update_suspension()

func _update_suspension() -> void:
	if not is_node_ready():
		return
	var unavailable := _app_unfocused or _tab_hidden
	if unavailable:
		_flight_keys.clear()
		_clear_stick()
		if not _paused and state in [State.FLYING, State.LANDING, State.CRASHED]:
			_paused = true
			_pause_prompt = prompt.text
			_pause_action = action.text
			_cue.stop()
			guide.hide()
			stick.hide()
			prompt.text = "Flight paused. Resume when you are ready."
			action.text = "Resume" if _touch_seen else "Resume (E)"
	action.disabled = unavailable
	town_return.disabled = unavailable

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode in FLIGHT_KEYS:
		if not event.pressed:
			_flight_keys.erase(event.physical_keycode)
		elif not event.echo and not _paused and not _app_unfocused and not _tab_hidden and (state == State.FLYING or _walking_deck()):
			_flight_keys[event.physical_keycode] = true
	if _paused or _app_unfocused or _tab_hidden:
		return
	if _walking_deck():
		_handle_deck_touch(event)
		return
	if state != State.FLYING:
		return
	if event is InputEventScreenTouch and event.pressed and not _touch_seen:
		_touch_seen = true
		stick.show()
		prompt.text = TOUCH_HINT + ROUTE_HINT
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

func _handle_deck_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _touch_seen:
			_touch_seen = true
			_refresh_deck_hud()
		if event.pressed and touch_index < 0 and walk_stick.contains_point(event.position):
			touch_index = event.index
			_walk_touch = walk_stick.aim_at(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_index:
			_clear_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_walk_touch = walk_stick.aim_at(event.position)
		get_viewport().set_input_as_handled()

func _walking_deck() -> bool:
	return _town_visit and state == State.DECK

func _refresh_deck_hud() -> void:
	var can_launch: bool = walker.can_mount()
	action.visible = can_launch
	action.text = "Launch" if _touch_seen else "Launch (E)"
	town_return.text = "Back to Town" if _touch_seen else "Back to Town (R)"
	walk_stick.visible = _touch_seen
	if can_launch:
		prompt.text = "In flight: " + (TOUCH_HINT if _touch_seen else KEY_HINT)
	else:
		prompt.text = "Use the stick to walk over to the glider." if _touch_seen else "Use WASD or the arrow keys to walk over to the glider."

func _set_touch(point: Vector2) -> void:
	var travel := (point - stick.get_global_rect().get_center()) / 40.0
	touch_steer = _stick_axis(travel.x)
	touch_pitch = _stick_axis(travel.y)
	knob.position = _knob_center() + Vector2(touch_steer * 35.0, touch_pitch * 28.0)

func _stick_axis(value: float) -> float:
	return signf(value) * remap(clampf(absf(value), 0.10, 1.0), 0.10, 1.0, 0.0, 1.0)

func _knob_center() -> Vector2:
	return (stick.size - knob.size) * 0.5

func _clear_stick() -> void:
	touch_index = -1
	touch_steer = 0.0
	touch_pitch = 0.0
	_walk_touch = Vector2.ZERO
	if is_instance_valid(walk_stick):
		walk_stick.recenter()
	if is_instance_valid(stick) and is_instance_valid(knob):
		knob.position = _knob_center()

func _action() -> void:
	if _app_unfocused or _tab_hidden:
		return
	if _paused:
		_paused = false
		prompt.text = _pause_prompt
		action.text = _pause_action
		stick.visible = _touch_seen and state == State.FLYING
		return
	match state:
		State.DECK:
			if not _walking_deck() or walker.can_mount():
				_launch()
		State.FLYING, State.LANDING, State.MEADOW, State.CRASHED: _on_deck()

func _return_to_town() -> void:
	if not _town_visit or _returning_to_town or _paused or _tab_hidden or _app_unfocused:
		return
	if state != State.DECK:
		return
	_returning_to_town = true
	var result := TOWN_LINK.return_to_town(get_tree())
	if result != OK:
		_returning_to_town = false
		push_error("Couldn't return to Town: %s" % error_string(result))

func _on_deck() -> void:
	state = State.DECK
	flight.reset(launch.global_position, launch.global_rotation.y)
	walker.set_walking(_town_visit)
	$Glider/RiderAnchor.visible = not _town_visit
	_glider_pose()
	_camera_pose(1.0)
	_set_hud(TOUCH_HINT if _touch_seen else KEY_HINT, "Launch" if _touch_seen else "Launch (E)")
	if _walking_deck():
		_refresh_deck_hud()

func _launch() -> void:
	state = State.FLYING
	walker.set_walking(false)
	$Glider/RiderAnchor.show()
	flight.reset(launch.global_position, launch.global_rotation.y)
	var hint := TOUCH_HINT if _touch_seen else KEY_HINT
	_set_hud(hint + ROUTE_HINT, "Return to deck (E)")

func _land(where: Vector3) -> void:
	state = State.LANDING
	var touchdown := Vector3(where.x, meadow.global_position.y + GROUND_CLEARANCE, where.z)
	var direction := Vector3.FORWARD.rotated(Vector3.UP, flight.heading)
	var distance := flight.speed * FLIGHT.RUNOUT_TIME * 0.5
	# Leave room at the edge even when landing diagonally across the meadow.
	var local := meadow.to_local(touchdown)
	var local_direction := meadow.to_local(touchdown + direction) - local
	for axis in [Vector3.AXIS_X, Vector3.AXIS_Z]:
		var component: float = local_direction[axis]
		if absf(component) > 0.0001:
			var edge: float = signf(component) * landing_bounds.size[axis] * 0.5
			distance = minf(distance, maxf(0.0, (edge - local[axis]) / component - 0.5))
	if distance > 0.0:
		var obstacle := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(touchdown, touchdown + direction * distance, COURSE_MASK | POLE_MASK))
		if not obstacle.is_empty():
			distance = maxf(0.0, touchdown.distance_to(obstacle.position) - 0.5)
	flight.begin_runout(touchdown, distance)
	_glider_pose()
	_set_hud("Touching down...", "Return to deck (E)")

func _crash(at_rest: Vector3, message: String, normal := Vector3.UP) -> void:
	state = State.CRASHED
	_crash_elapsed = 0.0
	_crash_rotation = Vector3(flight.pitch, flight.heading, flight.bank)
	_crash_side = -1.0 if flight.bank < 0.0 else 1.0
	_crash_normal = normal
	flight.position = at_rest
	flight.speed = 0.0
	flight.climb = 0.0
	flight.lift = 0.0
	_cue.stop()
	_glider_pose()
	guide.hide()
	_set_hud(message, "Back to deck" if _touch_seen else "Back to deck (E)")

func _step_crash(delta: float) -> void:
	_crash_elapsed += delta
	if _crash_elapsed >= CRASH_HOLD_TIME:
		_on_deck()
		return
	# Tip and recoil out from the contact surface; the flight position stays fixed.
	var progress := clampf(_crash_elapsed / CRASH_TUMBLE_TIME, 0.0, 1.0)
	var tip := 1.0 - pow(1.0 - progress, 3.0)
	var wobble := sin(progress * TAU) * (1.0 - progress) * 0.3
	glider.global_position = flight.position + _crash_normal * (0.52 * tip + 0.25 * sin(progress * PI))
	glider.rotation = _crash_rotation + Vector3(-0.28 * tip + wobble, 0.0, _crash_side * (1.0 * tip + wobble))

func _set_hud(label_text: String, button_text: String) -> void:
	$GroundShadow.set_active(state != State.DECK)
	_flight_keys.clear()
	_clear_stick()
	_was_in_lift = false
	prompt.text = label_text
	action.text = button_text
	action.show()
	town_return.visible = _walking_deck()
	walk_stick.visible = _walking_deck() and _touch_seen
	town_return.text = "Back to Town" if _touch_seen else "Back to Town (R)"
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
	if _paused or _app_unfocused or _tab_hidden:
		return
	var keys := float(_flight_keys.has(KEY_D) or _flight_keys.has(KEY_RIGHT)) - float(_flight_keys.has(KEY_A) or _flight_keys.has(KEY_LEFT))
	var pitch_keys := float(_flight_keys.has(KEY_S) or _flight_keys.has(KEY_DOWN)) - float(_flight_keys.has(KEY_W) or _flight_keys.has(KEY_UP))
	if _walking_deck():
		walker.step(delta, _walk_touch if touch_index >= 0 else Vector2(keys, pitch_keys))
		_refresh_deck_hud()
		return
	if state == State.CRASHED:
		_step_crash(delta)
		return
	if state != State.FLYING and state != State.LANDING:
		return
	step_flight(delta, touch_steer if touch_index >= 0 else keys, touch_pitch if touch_index >= 0 else pitch_keys)

func step_flight(delta: float, steer: float, pitch_input := 0.0) -> void:
	if _paused or _app_unfocused or _tab_hidden:
		return
	if state == State.LANDING:
		var stopped: bool = flight.advance_runout(delta)
		_glider_pose()
		if stopped:
			state = State.MEADOW
			_set_hud("Nice landing! Ready for another flight?", "Ride back up (E)")
		return
	if state != State.FLYING:
		return
	var prev := flight.position
	var prev_pitch: float = flight.pitch
	var prev_bank: float = flight.bank
	var prev_heading: float = flight.heading
	var wind := lift_at(prev)
	var floor_y := meadow.global_position.y + GROUND_CLEARANCE
	var height := prev.y - floor_y if in_meadow(prev) else INF
	var climb_room := 1.0 - smoothstep(launch.global_position.y, launch.global_position.y + CLIMB_ABOVE_LAUNCH, prev.y)
	var next := flight.advance(delta, steer, wind, height, pitch_input, climb_room)
	if wind > 0.10 and not _was_in_lift:
		_cue.play()
	_was_in_lift = wind > 0.10
	var space := get_world_3d().direct_space_state
	var terrain := space.intersect_ray(PhysicsRayQueryParameters3D.create(prev, next, COURSE_MASK | POLE_MASK))
	var pole_fraction := _pole_wing_contact(space, prev, next, Vector3(prev_pitch, prev_heading, prev_bank))
	var solid_fraction := 1.0 if terrain.is_empty() else prev.distance_to(terrain.position) / prev.distance_to(next)
	if prev.y >= floor_y and next.y <= floor_y and next.y < prev.y:
		var fraction := (prev.y - floor_y) / (prev.y - next.y)
		var touchdown := prev.lerp(next, fraction)
		# A solid object reached before the landing plane takes priority.
		var meadow_first := fraction <= solid_fraction and (pole_fraction < 0.0 or fraction <= pole_fraction)
		if in_meadow(touchdown) and meadow_first:
			var contact := FLIGHT.classify_touchdown((prev.y - next.y) / delta,
				lerpf(prev_pitch, flight.pitch, fraction), lerpf(prev_bank, flight.bank, fraction))
			match contact:
				FLIGHT.Touchdown.HARD: _crash(touchdown, "Hard landing! Ease off the dive before touching down.")
				FLIGHT.Touchdown.TILTED: _crash(touchdown, "Wingtip down! Level the glider before touching down.")
				_: _land(touchdown)
			return
	if pole_fraction >= 0.0 and pole_fraction <= solid_fraction:
		_crash(prev.lerp(next, pole_fraction), "Windsock hit! Give the poles a little room.", (prev - next).normalized())
		return
	if not terrain.is_empty():
		var message := "Windsock hit! Give the poles a little room." if terrain.collider.collision_layer == POLE_MASK else "Bump! Keep clear of the cliffs and land in the meadow."
		_crash(terrain.position + (prev - next).normalized() * 0.35, message, terrain.normal)
		return
	if next.y < meadow.global_position.y - 1.5 or absf(next.x) > 105.0 or next.z < -195.0 or next.z > 65.0:
		_on_deck()
		prompt.text = "Back at the deck. Follow the windsocks for an easy flight."
		return
	_glider_pose()

func _pole_wing_contact(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, old_rotation: Vector3) -> float:
	# Check the narrow spar as well as the center ray, so a low wing can hit a pole.
	# Restrict this to poles so the ground and meadow still use the existing landing model.
	var old_basis := Basis.from_euler(old_rotation)
	_pole_query.transform = Transform3D(old_basis, from + old_basis * WING_OFFSET)
	var end_basis := Basis.from_euler(Vector3(flight.pitch, flight.heading, flight.bank))
	var end_transform := Transform3D(end_basis, to + end_basis * WING_OFFSET)
	_pole_query.motion = end_transform.origin - _pole_query.transform.origin
	var fractions := space.cast_motion(_pole_query)
	if fractions.size() == 2 and fractions[0] < 1.0:
		return fractions[0]
	# The sweep translates the old pose; the final overlap also accounts for banking into the post.
	_pole_query.motion = Vector3.ZERO
	_pole_query.transform = end_transform
	return 1.0 if not space.intersect_shape(_pole_query, 1).is_empty() else -1.0

func _process(delta: float) -> void:
	if _paused or _app_unfocused or _tab_hidden:
		return
	_elapsed += delta
	var ribbons := $Scenery/UpdraftRibbons
	ribbons.position = lift_zone.position
	for marker: Node3D in ribbons.get_children():
		var initial: float = float(marker.get_meta("base_y", marker.position.y))
		marker.set_meta("base_y", initial)
		marker.position.y = initial + sin(_elapsed * 2.2 + initial * 0.3) * 0.65
	$Scenery/Waterfall/Foam.position.y = -7.35 + sin(_elapsed * 3.0) * 0.06
	_camera_pose(1.0 - exp(-5.0 * delta))
	_update_route_guide()

# Anchor to the course marker, not to fixed screen pixels. Keep the guide clear
# of the instructions and controls even if the waterfall is outside the view.
func _update_route_guide() -> void:
	if _walking_deck():
		guide.hide()
		return
	var marker := lift_zone.global_position + Vector3.UP * 7.0
	var ahead := (marker - flight.position).dot(Vector3.FORWARD.rotated(Vector3.UP, flight.heading))
	var rising := state == State.FLYING and flight.lift > 0.10
	guide.visible = (state == State.DECK or state == State.FLYING) and (rising or (ahead > 1.0 and not camera.is_position_behind(marker)))
	if not guide.visible:
		return
	var screen := get_viewport().get_visible_rect().size
	var projected := camera.unproject_position(marker) if not rising else Vector2(screen.x * 0.5, 104.0)
	var outer := 14.0
	var width := guide.custom_minimum_size.x
	var caption := "Rising air!" if rising else "Waterfall lift"
	if not rising and projected.x + width * 0.5 > screen.x - outer:
		caption = "Waterfall lift >"
	elif not rising and projected.x - width * 0.5 < outer:
		caption = "< Waterfall lift"
	if guide_label.text != caption:
		guide_label.text = caption
	var guide_size := guide.get_combined_minimum_size()
	if guide.size != guide_size:
		guide.size = guide_size
	var x := clampf(projected.x - guide.size.x * 0.5, outer, maxf(outer, screen.x - guide.size.x - outer))
	var top := prompt.get_global_rect().end.y + 12.0
	var controls_top := minf(stick.position.y, action.position.y)
	if town_return.visible:
		controls_top = minf(controls_top, town_return.position.y)
	var bottom := maxf(top, controls_top - guide.size.y - 8.0)
	guide.position = Vector2(x, clampf(projected.y - guide.size.y * 0.5, top, bottom))

func _glider_pose() -> void:
	glider.global_position = flight.position
	glider.rotation = Vector3(flight.pitch, flight.heading, flight.bank)

func _camera_pose(weight: float) -> void:
	if _walking_deck():
		var point := walker.global_position
		camera.global_position = camera.global_position.lerp(point + Vector3(1.8, 3.7, 5.8), weight)
		camera.look_at(point + Vector3(0.0, 0.9, -1.8), Vector3.UP)
		return
	var offset := Vector3(0.0, 3.25, 6.8)
	var focus := Vector3(0.0, 0.8, -5.2)
	if state == State.DECK:
		offset = Vector3(7.8, 8.0, 11.8)
		focus = Vector3(0.0, 0.7, -3.5)
	elif state == State.CRASHED:
		focus = Vector3(0.0, 0.7, 0.0)
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
