extends Node3D

const PLAYER = preload("res://game/player.gd")
const ZONE_GEOMETRY = preload("res://game/zone_geometry.gd")
const TOWN := "res://game/town.tscn"
const BEACH := "res://game/beach.tscn"
const DIVE_DOOR := Vector3(-24.15,0,12.45)
const DIVE_ROOM_SCENE := "res://game/scuba/shop.tscn"
const HOME_ROOM_SCENE := "res://game/home/room.tscn"
const SALON_ROOM_SCENE := "res://game/salon/room.tscn"
const CAFE_ROOM_SCENE := "res://game/cafe/room.tscn"
const STORE_ROOM_SCENE := "res://game/store/room.tscn"
const LIBRARY_ROOM_SCENE := "res://game/library/room.tscn"
const BANK_ROOM_SCENE := "res://game/bank/room.tscn"
const VET_ROOM_SCENE := "res://game/vet/room.tscn"
const ROOM := "res://game/room.tscn"
const ROOM_NAMES := {"bank":"Willowbrook Bank","vet":"Willowbrook Vet","salon":"Salon","store":"General Store","cafe":"Sunny Cafe","library":"Willowbrook Library","arcade":"Willowbrook Arcade","home":"Home","dive_shop":"Dive Shop"}
const TOWN_ROUTES = preload("res://game/town_routes.gd")
const FERRY = preload("res://game/ferry_landing.gd")
const ENTRY := Vector3(0, 0, -7.7)
const INTERACT_RANGE := 2.25
const PLAYGROUND = preload("res://game/activities/playground.gd")
var playground: PLAYGROUND
var _shared_ride := false
var _ride_pending := 0
var _ride_notice := ""
var _ride_notice_deadline := 0
var _occupied_rides := {}

@export var arena := false
@export var beach := false
@export var indoor := false
var room_id := ""
var room_plot := -1
var guest_variant := ""
var guest_decor: Array = []
var _last_guest_scene := 0
var home_locked: Variant = null
var room: Node3D
var town_progress: Node3D
var _home_exterior_rows: Array = []
var home_lot: Node3D
const PET_ACTORS = preload("res://game/pets/actors.gd")
const PET_CATALOG = preload("res://game/pets/catalog.gd")
var outdoor_pets: PET_ACTORS
var _home_enter_target: Dictionary = {}
var _home_wait_until := 0
var _home_entry_message := ""
var vehicles: Node3D
var profile: RefCounted
var zone_modal := false
var room_seated := false
var jump_button: Button
var _last_enter_layout := Vector2.ZERO
var beach_scenery: Node3D
const TOWN_WEATHER = preload("res://game/town_weather.gd")
var _weather_badge: Label
var _activity_weather_y := 64.0
var beach_activities: RefCounted
var fishing_ui: Node3D
var player: PLAYER
var camera: Camera3D
var camera_probe := SphereShape3D.new()
var camera_arm := Vector3.ZERO
var camera_distance := 0.0
var camera_tight := false
var _camera_tight_enter := 1.58
var _camera_tight_leave := 2.10
var _camera_collision_mask := 1
var look_yaw := 0.0
const DEFAULT_LOOK_PITCH := -0.17
var look_pitch := DEFAULT_LOOK_PITCH
const FIRST_PERSON_META := &"willowbrook_first_person"
var first_person := false
var _third_person_pitch := DEFAULT_LOOK_PITCH
var look_shoulder := 1.0
const SCOOTER_RIDER = preload("res://game/vehicles/scooter_rider.gd")
const GAMEPAD = preload("res://game/gamepad_state.gd")
var _gamepad := GAMEPAD.new()
var _gamepad_blurred := false
var _gamepad_connected_grace_until := 0
const TOUCH_ROUTER = preload("res://game/touch_router.gd")
var _touches := TOUCH_ROUTER.new()
const HUD_FIT = preload("res://game/hud_fit.gd")
const MOVEMENT_STICK = preload("res://game/movement_thumbstick.gd")
var movement_thumbstick: MOVEMENT_STICK
var camera_thumbstick: MOVEMENT_STICK
var _touch_layout_scale := 1.0
const TOUCH_YAW_RATE := 2.15
const TOUCH_PITCH_RATE := 1.38
var _world_was_blocked := false
var _web_visibility_callback: JavaScriptObject
const AVATAR_CATALOG = preload("res://game/avatars/catalog.gd")
var arena_avatar: Node3D
var arena_animation: AnimationPlayer
var enter_button: Button
var door_position: Vector3
var changing := false
const FERRY_CROSSING = preload("res://game/ferry_crossing.gd")
var ferry_crossing := FERRY_CROSSING.new()

func _ready() -> void:
	get_window().focus_exited.connect(_on_window_blur)
	get_window().focus_entered.connect(_on_window_focus)
	Input.joy_connection_changed.connect(_on_controller_connection)
	_gamepad.follow_connected()
	if OS.has_feature("web"):
		_web_visibility_callback = JavaScriptBridge.create_callback(_web_visibility_changed)
		var document := JavaScriptBridge.get_interface("document")
		if document != null:
			document.addEventListener("visibilitychange",_web_visibility_callback)
	_load_profile()
	if indoor:
		room_id = str(get_tree().get_meta("room_destination","library"))
		room_plot = int(get_tree().get_meta("room_plot",-1))
		get_tree().remove_meta("room_destination")
		get_tree().remove_meta("room_plot")
		guest_variant=str(get_tree().get_meta("room_guest_variant",""))
		get_tree().remove_meta("room_guest_variant")
		_last_guest_scene=Time.get_ticks_msec()
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	sky.environment.background_mode = Environment.BG_COLOR
	sky.environment.background_color = Color("#bedef2")
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color = Color("#eaf5ff")
	sky.environment.ambient_light_energy = 0.35 if arena else (0.38 if indoor else 0.45)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -35, 0)
	sun.light_energy = 0.52 if arena else (0.40 if indoor else 0.62)
	if arena:
		sun.light_color = Color("#fff2db")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	if not beach and not indoor:
		add_child(sky)
		add_child(sun)
	if arena:
		_build_zone_geometry()
	elif beach:
		_build_beach()
	elif not indoor:
		playground = PLAYGROUND.new()
		_build_town()
	_build_player()
	if indoor:
		var path := _room_resource(room_id)
		if ResourceLoader.exists(path):
			var resource := load(path)
			room = resource.instantiate() if resource is PackedScene else resource.new()
			room.name = "IndoorRoom"
			add_child(room)
		else:
			ZONE_GEOMETRY.box(self, "RoomFallbackFloor",Vector3(0,-0.2,0),Vector3(18,0.4,14),Color("#c5a082"),true)
			door_position = Vector3(0,0,6.5)
	first_person = not arena and bool(get_tree().get_meta(FIRST_PERSON_META,false))
	if first_person:
		look_pitch = 0.0
	_build_ui()
	# Room setup instances its lighting rig. Do not stack town sunlight or a
	# second WorldEnvironment on top of rooms that provide their own lighting.
	if indoor and (room == null or room.find_children("*", "WorldEnvironment", true, false).is_empty()):
		add_child(sky)
		add_child(sun)
	elif indoor or beach:
		sky.free()
		sun.free()
	if indoor and room != null:
		player.position = room.spawn_position()
		if room.has_method("spawn_yaw"):
			look_yaw = room.spawn_yaw()
			player.rotation.y = look_yaw
		if room.has_method("camera_profile"):
			var tuning: Dictionary = room.camera_profile()
			_camera_tight_enter = float(tuning.get("tight_enter", _camera_tight_enter))
			_camera_tight_leave = float(tuning.get("tight_leave", _camera_tight_leave))
			_camera_collision_mask = int(tuning.get("collision_mask", _camera_collision_mask))
		if room.has_method("bounds"):
			player.world_bounds = room.bounds()
	var session := get_node_or_null("/root/WillowbrookBrowserSession" if OS.has_feature("web") else "/root/WillowbrookSession")
	if session != null:
		_bind_world_session(session)
	if not arena and not indoor:
		outdoor_pets = PET_ACTORS.new()
		outdoor_pets.name = "OutdoorPets"
		add_child(outdoor_pets)
		outdoor_pets.configure(player,0)
		_refresh_outdoor_pets()
		if profile!=null: profile.changed.connect(_refresh_outdoor_pets)
	if not arena and not beach and not indoor and OS.has_feature("web") and session != null:
		var weather := TOWN_WEATHER.new()
		add_child(weather)
		weather.setup(sky.environment,sun,player,_weather_badge,session)
	var account := _pets_account()
	if account!=null:
		account.pet_snapshot_changed.connect(_refresh_outdoor_pets)
		account.pet_result.connect(_house_entry_result)
		if account.has_signal("home_visit_notice"): account.home_visit_notice.connect(_home_visit_notice)
	_update_camera()
	_refresh_prompt()

func _sync_town_home_exteriors() -> void:
	pass


func _build_town() -> void:
	pass


func _build_town_features(_hud: CanvasLayer) -> void:
	pass


# Optional scene hooks keep the shared camera, controls and HUD independent of
# the objects that implement a particular zone's activities.
func _build_zone_geometry() -> void:
	pass

func _setup_zone_player() -> void:
	pass

func _setup_zone_avatar() -> void:
	pass

func _build_zone_overlay(_hud: CanvasLayer) -> void:
	pass

func _build_zone_buttons(_hud: CanvasLayer) -> void:
	pass

func _fit_zone_hud(_physical_width: float, _scale: float) -> void:
	pass

func _setup_zone(_hud: CanvasLayer) -> void:
	pass

func _bind_world_session(session: Node) -> void:
	session.bind_zone(current_zone_id(),self,player,get_node("WorldHUD"))

func _update_zone_controls(_blocked: bool) -> void:
	pass

func _tick_zone(_delta: float) -> void:
	pass

func _update_zone_cutaway() -> bool:
	return false

func _zone_jump_active() -> bool:
	return player.is_physics_processing()

func _zone_local_actions_paused() -> bool:
	return false

func _zone_owns_interaction() -> bool:
	return false

func _zone_blocks_world() -> bool:
	return false

func _zone_exit_prompt() -> String:
	return ""

func _try_zone_exit() -> bool:
	return false

func _reset_zone_inputs() -> void:
	pass

func _consume_zone_input(_event: InputEvent) -> bool:
	return false

func _world_primary_action() -> bool:
	if fishing_ui != null and not _beach_is_sliding():
		fishing_ui.click(camera)
		return true
	return false


func _build_player() -> void:
	player = PLAYER.new()
	player.name = "Player"
	player.jump_enabled = true
	add_child(player)
	player.position = _beach_spawn() if beach else TOWN_ROUTES.SPAWN
	if beach and get_tree().has_meta("scuba_beach_return"):
		get_tree().remove_meta("scuba_beach_return")
		player.position = DIVE_DOOR + Vector3(0,.06,.75)
		look_yaw = 0.0
		player.rotation.y = look_yaw
	if indoor:
		player.position = Vector3(0,0.04,5.5)
	elif not arena and not beach and get_tree().has_meta("town_room_return"):
		var back: Dictionary = get_tree().get_meta("town_room_return")
		get_tree().remove_meta("town_room_return")
		player.position = back.at
		look_yaw = float(back.yaw)
		player.rotation.y = look_yaw
	if not arena and not beach and not indoor and get_tree().has_meta("beach_town_return"):
		get_tree().remove_meta("beach_town_return")
		player.position = TOWN_ROUTES.BEACH_RETURN
		look_yaw = 0.0
		player.rotation.y = look_yaw
	if not arena:
		player.world_bounds = Vector2(56,54) if beach else (Vector2(10,8) if indoor else TOWN_ROUTES.WORLD_BOUNDS)
		if beach:
			player.collision_mask = 3
		player.process_physics_priority = -10
		player.floor_snap_length = 0.45
	_setup_zone_player()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.31
	capsule.height = 1.55
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	player.add_child(collider)
	collider.position.y = 0.79
	var account := get_node_or_null("/root/WillowbrookBrowserSession")
	_apply_player_avatar(account.player_avatar_id() if account != null and account.has_method("player_avatar_id") else AVATAR_CATALOG.DEFAULT)
	_setup_zone_avatar()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 62.0
	camera.near = 0.06
	camera_probe.radius = 0.22
	camera.size = 20.0
	add_child(camera)
	camera.make_current()

func _apply_player_avatar(character: Variant) -> void:
	var id := AVATAR_CATALOG.sanitize(character)
	if is_instance_valid(arena_avatar):
		if arena_avatar.get_meta("avatar_id","") == id:
			return
		player.remove_child(arena_avatar)
		arena_avatar.queue_free()
	arena_avatar = AVATAR_CATALOG.instantiate(id)
	arena_avatar.name = "ArenaAvatar"
	player.add_child(arena_avatar)
	arena_avatar.rotation.y = PI
	arena_avatar.scale = Vector3.ONE * (2.9 if arena or beach else 2.5)
	arena_animation = AVATAR_CATALOG.animator(arena_avatar)
	for clip in ["idle", "walk", "fall"]:
		if arena_animation.has_animation(clip):
			arena_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	arena_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	arena_animation.play("idle")
	if vehicles != null:
		vehicles.avatar = arena_avatar

func _build_town_capsule() -> void:
	var figure := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.31
	mesh.height = 1.55
	figure.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#e08350")
	figure.material_override = material
	player.add_child(figure)
	figure.position.y = 0.79

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "WorldHUD"
	add_child(hud)
	var title := Label.new()
	title.text = "Warehouse Yard" if arena else ("Willowbrook Island" if beach else (str(ROOM_NAMES.get(room_id,"Willowbrook")) if indoor else "Willowbrook"))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_constant_override("outline_size", 6)
	hud.add_child(title)
	title.position = Vector2(18,14)
	var help := Label.new()
	help.text = "WASD to move | Right-click or C: camera | Left-click: paint | Space: jump | Esc: cursor\nTouch: left stick to move, right stick to look" if arena else ("WASD to move | Right-click or C: camera | E: interact | V: switch view | Space: jump | Esc: cursor\n"+("Left-click to cast and reel | R to put away the fishing pole" if beach else ("E to use nearby doors and objects." if indoor else "Find the island ferry by the pond.")))
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.add_theme_constant_override("outline_size", 5)
	hud.add_child(help)
	help.position = Vector2(18,49)
	if not arena and not beach and not indoor:
		title.hide()
		help.hide()
	if not arena and not beach and not indoor:
		_weather_badge = Label.new()
		_weather_badge.name = "TownWeather"
		_weather_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weather_badge.add_theme_constant_override("outline_size",5)
		_weather_badge.hide()
		hud.add_child(_weather_badge)
	movement_thumbstick = MOVEMENT_STICK.new()
	movement_thumbstick.name = "MovementThumbstick"
	hud.add_child(movement_thumbstick)
	movement_thumbstick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	movement_thumbstick.offset_left = 18.0
	movement_thumbstick.offset_right = 138.0
	movement_thumbstick.offset_top = -138.0
	movement_thumbstick.offset_bottom = -18.0
	camera_thumbstick = MOVEMENT_STICK.new()
	camera_thumbstick.name = "CameraThumbstick"
	camera_thumbstick.camera_control = true
	camera_thumbstick.visible = HUD_FIT.touch_available()
	hud.add_child(camera_thumbstick)
	camera_thumbstick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_build_zone_overlay(hud)
	jump_button = Button.new()
	jump_button.name = "Jump"
	jump_button.text = "Jump"
	jump_button.focus_mode = Control.FOCUS_NONE
	jump_button.custom_minimum_size = Vector2(82,46)
	jump_button.button_down.connect(_request_world_jump)
	_touches.configure(hud,player,jump_button,_request_world_jump,movement_thumbstick,camera_thumbstick)
	hud.add_child(jump_button)
	_build_zone_buttons(hud)
	jump_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,Control.PRESET_MODE_MINSIZE,16)
	jump_button.position.y -= 184.0 if beach else 61.0
	enter_button = Button.new()
	enter_button.focus_mode = Control.FOCUS_NONE
	enter_button.custom_minimum_size = Vector2(185,48)
	enter_button.text = "E  •  Back to town" if arena else "E  •  Enter paintball"
	enter_button.pressed.connect(_interact)
	hud.add_child(enter_button)
	enter_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	var desktop_help := help.text
	var hud_fit = HUD_FIT
	var resize_hud := func() -> void:
		var view := get_viewport().get_visible_rect().size
		var s: float = hud_fit.touch_scale(get_viewport()) if camera_thumbstick.visible else hud_fit.physical_scale(get_viewport())
		_touch_layout_scale = s
		var physical_width := view.x/s
		var narrow := physical_width < 460.0
		var compact_help := physical_width < 690.0
		title.position = Vector2(12,12)*s
		title.add_theme_font_size_override("font_size",roundi(22.0*s))
		help.position = Vector2(12,44)*s
		help.text = (("Left stick: move  |  Right stick: look\nTap Fire to shoot." if arena else "Left stick: move  |  Right stick: look\nTap to interact.") if camera_thumbstick.visible else ("WASD: move | Right-click: look | E: interact" if compact_help else desktop_help))
		help.add_theme_font_size_override("font_size",roundi(14.0*s))
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help.size.x = view.x-24.0*s
		if _weather_badge != null:
			_weather_badge.position = Vector2(12,_activity_weather_y)*s
			_weather_badge.add_theme_font_size_override("font_size",roundi(13.0*s))
		var lift_css := clampf((view.y/s-250.0)*.2,0.0,24.0) if camera_thumbstick.visible else 0.0
		movement_thumbstick.fit_hud(view.x,s,lift_css)
		camera_thumbstick.fit_hud(view.x,s,lift_css)
		_fit_zone_hud(physical_width, s)
		enter_button.add_theme_font_size_override("font_size",roundi(15.0*s))
		jump_button.add_theme_font_size_override("font_size",roundi(15.0*s))
		var button_width := clampf(physical_width-175.0,96.0,185.0) if narrow else 185.0
		hud_fit.right_button(enter_button,Vector2(button_width,48),0,s,true)
		hud_fit.right_button(jump_button,Vector2(82,46),174.0 if beach else 58.0,s,true)
	get_viewport().size_changed.connect(resize_hud)
	resize_hud.call()
	if indoor and room != null:
		room.setup(room_id,self,player,hud)
	elif not arena and not beach and not indoor:
		_build_town_features(hud)
	if beach:
		_build_beach_fishing(hud)
	_setup_zone(hud)

func _process(_delta: float) -> void:
	if OS.has_feature("web"):
		_sync_town_home_exteriors()
	if not _home_enter_target.is_empty() and Time.get_ticks_msec()>_home_wait_until:
		_home_enter_target.clear()
		_home_entry_message="Could not confirm your house. Try again."
		_home_wait_until=Time.get_ticks_msec()+3500
	if not _home_entry_message.is_empty() and Time.get_ticks_msec()>_home_wait_until:
		_home_entry_message=""
	var blocked := _world_input_blocked()
	if blocked and not _world_was_blocked:
		_reset_input_context()
	_world_was_blocked = blocked
	_update_zone_controls(blocked)
	_refresh_prompt()
	if jump_button != null:
		jump_button.visible = not _hide_seeker_locked and not zone_modal and _zone_jump_active() and not _beach_is_sliding() and not _zone_local_actions_paused()

func _physics_process(delta: float) -> void:
	var controller_look := Vector2.ZERO
	if _gamepad_input_blocked():
		if _gamepad.device >= 0:
			_gamepad.suspend()
			player.gamepad_motion = Vector2.ZERO
	else:
		controller_look = _gamepad.look()
	var look_motion := (_touches.look_motion + controller_look).limit_length()
	if not _world_input_blocked() and not look_motion.is_zero_approx():
		_turn_arena_view(look_motion*Vector2(TOUCH_YAW_RATE,TOUCH_PITCH_RATE),delta)
	if not guest_variant.is_empty() and not changing and Time.get_ticks_msec()-_last_guest_scene>3500:
		visit_ejected()
	if room_seated and not _world_input_blocked() and room != null and room.has_method("leave_rest_for_motion"):
		var direction := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
		if direction.length_squared() > .1 or player.analog_motion().length_squared() > .1 or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D):
			room.leave_rest_for_motion()
	if town_progress != null and town_progress.has_method("tick"):
		town_progress.tick(delta)
	if home_lot != null:
		home_lot.tick(delta)
	if indoor and room != null:
		if room.has_method("tick"):
			room.tick(delta)
		var online := get_node_or_null("/root/WillowbrookBrowserSession")
		if profile != null and room.has_method("feedback") and not (OS.has_feature("web") and online != null and online.has_method("job_offer")):
			var outcome: Dictionary = profile.advance(room_id,player.global_position)
			if not str(outcome.get("text","")).is_empty():
				room.feedback(str(outcome.text))
	if _shared_ride and _town_ride_session()==null:
		_shared_ride=false
		_leave_playground()
	if playground != null and not playground.ride.is_empty():
		playground.tick(delta)
		player.position = playground.pose()
		playground.apply_avatar(arena_avatar)
		if playground.is_finished() and not _shared_ride:
			_leave_playground()
	if not arena:
		if vehicles != null:
			vehicles.tick_drive(delta)
		if ferry_crossing.landing != null:
			if ferry_crossing.tick(delta,arena_avatar,arena_animation,camera,get_node("WorldHUD"),"Town" if beach else "the Island"):
				_finish_ferry()
			return
		if beach_activities != null and beach_activities.recover(player,fishing_ui,delta,zone_modal):
			_reset_input_context()
		_update_camera(delta)
		if beach_activities != null:
			beach_activities.tick_slide(player,arena_avatar,fishing_ui,delta)
		var walking := player.active and player.get_real_velocity().length_squared() > 0.15 and player.is_physics_processing()
		var scooter: Node3D = vehicles.scooter_mount() if vehicles != null else null
		if scooter == null:
			SCOOTER_RIDER.clear(arena_avatar)
		var next_clip := "sit" if _beach_is_seated() else ("walk" if walking or _beach_is_sliding() else "idle")
		if room_seated:
			next_clip = "idle" if room != null and room.get("rest_pose") == "lie" else "sit"
		elif scooter != null:
			next_clip = "idle"
		elif vehicles != null and vehicles.shared_vehicle_sitting():
			next_clip = "sit"
		elif playground != null and not playground.ride.is_empty():
			next_clip = playground.animation_name()
		elif not _beach_is_sliding() and not player.is_on_floor():
			next_clip = "jump" if player.velocity.y > 0.0 else "fall"
		if arena_animation.current_animation != next_clip:
			arena_animation.play(next_clip,0.0 if _beach_is_sliding() or scooter != null else .12)
		if scooter == null:
			arena_animation.advance(delta)
		else:
			if not arena_avatar.has_meta(SCOOTER_RIDER.ACTIVE):
				arena_animation.advance(0.0)
			SCOOTER_RIDER.present(arena_avatar,scooter.to_global(SCOOTER_RIDER.STAND))
		if fishing_ui != null:
			fishing_ui.tick(delta,arena_avatar.visible)
		if vehicles != null and vehicles.hides_avatar():
			arena_avatar.hide()
	_tick_zone(delta)

func fit_town_activity_weather(y: float, scale: float) -> void:
	_activity_weather_y=y
	if _weather_badge!=null: _weather_badge.position=Vector2(12,y)*scale

func scooter_for_peer(id: String) -> Node3D:
	return vehicles.rendered_scooter(id) if vehicles != null else null

func _update_camera(delta := 0.0) -> void:
	var inside := _update_zone_cutaway()
	var desired_arm := Vector3(look_shoulder * 0.70, 0.30, 2.85 if inside else 3.85)
	var yaw_basis := Basis(Vector3.UP, look_yaw)
	var view_basis := yaw_basis * Basis(Vector3.RIGHT, look_pitch)
	var pivot := player.global_position + Vector3(0, 1.48, 0)
	# Leave vehicle/arena cameras as before. Their visuals or firing view must
	# not be moved by a walking-camera preference.
	if not arena and first_person and (vehicles == null or not vehicles.is_driving()):
		var seated := room_seated or _beach_is_seated() or (playground != null and not playground.ride.is_empty())
		var eye_offset := Vector3.UP * (-0.31 if seated else 0.11) - yaw_basis.z * 0.12
		var eye_distance := _camera_clear_distance(pivot,eye_offset)
		camera.global_transform = Transform3D(view_basis,pivot + eye_offset.normalized() * eye_distance)
		camera.near = 0.05
		camera_distance = 0.0
		arena_avatar.hide()
		return
	camera.near = 0.06
	# Looking sharply up/down shouldn't drive the boom into the floor or roof.
	var boom_basis := yaw_basis * Basis(Vector3.RIGHT, clampf(look_pitch, -0.48, 0.14))
	var blend := 1.0 - exp(-10.0 * delta)
	camera_arm = camera_arm.lerp(desired_arm, blend) if delta > 0.0 else desired_arm
	var world_arm := boom_basis * camera_arm
	var allowed := world_arm.length()
	if delta > 0.0:
		allowed = _camera_clear_distance(pivot, world_arm)
	# Switch viewpoint instead of leaving the lens behind the avatar when
	# the boom is too short. Require extra space before switching back.
	if delta > 0.0:
		if camera_tight:
			camera_tight = allowed < _camera_tight_leave
		else:
			camera_tight = allowed < _camera_tight_enter
	if camera_tight:
		var eye_offset := -yaw_basis.z * 0.19
		var eye_distance := _camera_clear_distance(pivot, eye_offset)
		camera_distance = 0.0
		camera.global_transform = Transform3D(view_basis, pivot + eye_offset.normalized() * eye_distance)
		arena_avatar.hide()
		return
	camera_distance = allowed if delta <= 0.0 or allowed < camera_distance else lerpf(camera_distance, allowed, blend)
	camera.global_transform = Transform3D(view_basis, pivot + world_arm.normalized() * camera_distance)
	arena_avatar.visible = camera_distance >= 1.58

func _camera_clear_distance(origin: Vector3, motion: Vector3) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_probe
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = motion
	query.collision_mask = _camera_collision_mask
	query.exclude = [player.get_rid()]
	var fraction := get_world_3d().direct_space_state.cast_motion(query)
	if fraction.size() == 2 and fraction[0] < 1.0:
		return maxf(0.0, motion.length() * fraction[0] - 0.08)
	return motion.length()



func _near_door() -> bool:
	var at := Vector2(player.position.x, player.position.z)
	return at.distance_to(Vector2(door_position.x, door_position.z)) <= INTERACT_RANGE

func _refresh_prompt() -> void:
	var prompt := _interaction_text()
	enter_button.visible = not changing and not prompt.is_empty() and not _zone_local_actions_paused()
	var viewport := get_viewport()
	var fit = preload("res://game/hud_fit.gd")
	var scale: float = _touch_layout_scale if camera_thumbstick.visible else fit.physical_scale(viewport)
	var width := viewport.get_visible_rect().size.x/scale
	var button_width := clampf(width-175.0,96.0,185.0) if width < 460.0 else 185.0
	if width >= 460.0 and OS.has_feature("web") and not arena:
		var account := get_node_or_null("/root/WillowbrookBrowserSession")
		if account != null and account.has_method("garden_approach") and (account.garden_approach() or prompt.begins_with("Collect ")):
			button_width = minf(276.0, maxf(150.0,width-260.0)) if camera_thumbstick.visible else 276.0
	var layout_key := Vector2(button_width,scale)
	if layout_key != _last_enter_layout:
		_last_enter_layout = layout_key
		fit.right_button(enter_button,Vector2(button_width,48),0.0,scale,true)
	enter_button.text = "E · " + prompt

func _near_at(point: Vector3, radius := INTERACT_RANGE) -> bool:
	return Vector2(player.position.x-point.x,player.position.z-point.z).length() <= radius

func _interaction_text() -> String:
	if _hide_seeker_locked: return ""
	var normal := _normal_interaction_text()
	if not normal.is_empty() or changing or zone_modal:
		return normal
	var hunt := get_node_or_null("/root/WillowbrookBrowserSession")
	if OS.has_feature("web") and hunt != null and hunt.has_method("hide_seek_can_tag") and hunt.hide_seek_can_tag(self):
		return "Tag"
	return ""


func _normal_interaction_text() -> String:
	if _zone_owns_interaction(): return ""
	if not _home_enter_target.is_empty(): return "Checking your home…"
	if not _home_entry_message.is_empty(): return _home_entry_message
	if zone_modal:
		return ""
	if vehicles != null and vehicles.is_driving():
		return vehicles.interaction_prompt()
	if not _beach_is_sliding() and (playground == null or playground.ride.is_empty()):
		var hunt := get_node_or_null("/root/WillowbrookBrowserSession")
		if OS.has_feature("web") and hunt != null and hunt.has_method("hunt_prompt"):
			var treasure: String = hunt.hunt_prompt()
			if not treasure.is_empty():
				return treasure
	if indoor:
		return room.interaction_prompt() if room != null else ("Back to town" if _near_door() else "")
	if playground != null:
		if Time.get_ticks_msec()<_ride_notice_deadline: return _ride_notice
		if Time.get_ticks_msec()<_ride_pending: return "Checking playground..."
		var nearest := playground.nearby(player.position)
		if playground.ride.is_empty() and _town_ride_session()!=null and _occupied_rides.has(nearest):
			return playground.LABELS[nearest].capitalize()+" occupied"
		var ride_hint := playground.prompt(player.position)
		if not ride_hint.is_empty() or not playground.ride.is_empty():
			return ride_hint
	if not arena and not beach:
		var account := get_node_or_null("/root/WillowbrookBrowserSession")
		if OS.has_feature("web") and account != null and account.has_method("garden_prompt"):
			var garden_hint: String = account.garden_prompt()
			if not garden_hint.is_empty():
				return garden_hint
		if town_progress != null:
			var work_prompt := str(town_progress.interaction_prompt())
			if not work_prompt.is_empty():
				return work_prompt
		if home_lot != null:
			var delivery_hint := str(home_lot.interaction_prompt())
			if not delivery_hint.is_empty():
				return delivery_hint
		var target := _town_room_at()
		if not target.is_empty():
			return "Visit home" if target.get("guest",false) else "Enter %s" % str(ROOM_NAMES.get(target.id,target.id))
		if vehicles != null:
			var vehicle_prompt := str(vehicles.interaction_prompt())
			if not vehicle_prompt.is_empty():
				return vehicle_prompt
	if fishing_ui != null:
		if fishing_ui.is_modal_open() or _beach_is_sliding():
			return ""
		if _near_ferry():
			return "Ferry to town"
		if _near_at(DIVE_DOOR,2.25) and player.position.z > 11.8:
			return "Enter Dive Shop"
		if _near_at(beach_scenery.SLIDE_ENTRY) and fishing_ui.game.line.is_empty():
			return "Ride the slide"
		return fishing_ui.interaction_prompt()
	var exit_prompt := _zone_exit_prompt()
	if not exit_prompt.is_empty():
		return exit_prompt
	if _near_ferry():
		return "Ferry to the island"
	if _near_door():
		return "Back to town" if arena else "Enter paintball"
	if town_progress != null and not arena and not beach:
		return town_progress.conversation_prompt()
	return ""

func _interact() -> void:
	if _zone_owns_interaction(): return
	if _hide_seeker_locked or changing or zone_modal or _beach_is_sliding() or _zone_local_actions_paused() or (fishing_ui != null and fishing_ui.is_modal_open()):
		return
	if _interaction_text() == "Tag":
		var hide_seek := get_node("/root/WillowbrookBrowserSession")
		hide_seek.hide_seek_tag(self)
		return
	if (vehicles == null or not vehicles.is_driving()) and (playground == null or playground.ride.is_empty()):
		var hunt := get_node_or_null("/root/WillowbrookBrowserSession")
		if OS.has_feature("web") and hunt != null and hunt.has_method("collect_hunt") and hunt.collect_hunt():
			return
	if indoor:
		if room != null:
			room.interact()
		elif _near_door():
			go_to_town()
		return
	if vehicles != null and vehicles.is_driving():
		vehicles.interact()
		if not vehicles.is_driving():
			_touches.reset_movement()
		return
	if playground != null:
		if Time.get_ticks_msec()<_ride_pending: return
		var shared := _town_ride_session()
		if not playground.ride.is_empty():
			if playground.ride != "slide":
				if _shared_ride and shared!=null:
					if shared.town_ride("exit"): _ride_pending=Time.get_ticks_msec()+2000
				else:
					_leave_playground()
			return
		var ride := playground.nearby(player.position)
		if not ride.is_empty():
			if shared!=null:
				if _occupied_rides.has(ride):
					town_ride_error("Someone is using this spot.")
				elif player.is_on_floor() and shared.town_ride("board",ride):
					_ride_pending=Time.get_ticks_msec()+2000
			else:
				_board_town_ride(ride)
			return
	if not arena and not beach:
		var account := get_node_or_null("/root/WillowbrookBrowserSession")
		if OS.has_feature("web") and account != null and account.has_method("garden_prompt") and account.garden_approach():
			account.tend_garden()
			return
		if town_progress != null and not str(town_progress.interaction_prompt()).is_empty():
			town_progress.interact()
			return
		if home_lot != null and not str(home_lot.interaction_prompt()).is_empty():
			home_lot.interact()
			return
		var target := _town_room_at()
		if not target.is_empty():
			_enter_room(target)
			return
		if vehicles != null and not str(vehicles.interaction_prompt()).is_empty():
			vehicles.interact()
			if vehicles.is_driving():
				_touches.reset_movement()
			return
	if _try_zone_exit():
		return
	if beach and _near_ferry():
		_take_ferry()
	elif beach and _near_at(DIVE_DOOR,2.25) and player.position.z > 11.8:
		# As with Town doors, use the ordinary shared E/touch/X action.
		if not fishing_ui.game.line.is_empty():
			fishing_ui.put_away()
		get_tree().set_meta("room_destination","dive_shop")
		_change_zone(ROOM)
		if not changing: get_tree().remove_meta("room_destination")
	elif beach and _near_at(beach_scenery.SLIDE_ENTRY) and fishing_ui.game.line.is_empty():
		beach_activities.begin_slide(player,arena_avatar,fishing_ui)
		look_yaw = PI
		player.rotation.y = look_yaw
	elif _near_ferry():
		_take_ferry()
	elif fishing_ui != null and fishing_ui.try_interact():
		if fishing_ui.is_modal_open() or _beach_is_sliding():
			_release_look()
	elif town_progress != null and not arena and not beach and not _near_door() and town_progress.talk():
		return
	else:
		_try_door()

func _near_ferry() -> bool:
	if arena or indoor or player.position.y > 1.15 or player.position.y < -0.20:
		return false
	return _near_at(door_position if beach else TOWN_ROUTES.BEACH_DOOR,2.7)

func _take_ferry() -> void:
	if changing or not _near_ferry():
		return
	var landing := get_node_or_null(("BeachLayout" if beach else "TownLayout")+"/FerryLanding") as FERRY
	if landing == null:
		return
	changing = true
	ferry_crossing.begin(landing,player,arena_avatar)
	_reset_input_context()
	player.velocity = Vector3.ZERO
	player.movement_locked = true
	if fishing_ui != null:
		fishing_ui.set_actions_suspended(true)
	arena_avatar.show()


func _finish_ferry() -> void:
	_change_zone(TOWN if beach else BEACH,"beach_town_return" if beach else "")
	if not changing:
		ferry_crossing.restore_pose(player,arena_avatar)
		if fishing_ui != null:
			fishing_ui.set_actions_suspended(false)
		ferry_crossing.dismiss_card()
		_reset_input_context()

func _change_zone(scene: String, flag := "") -> void:
	changing = true
	var tree := get_tree()
	var result := tree.change_scene_to_file(scene)
	if result == OK and not flag.is_empty():
		tree.set_meta(flag,true)
	elif result != OK:
		changing = false
		push_error("Could not change map: %s" % error_string(result))

func _turn_arena_view(relative: Vector2, sensitivity: float) -> void:
	look_yaw = wrapf(look_yaw - relative.x * sensitivity, -PI, PI)
	var pitch_limit := 1.10 if first_person and not arena and (vehicles == null or not vehicles.is_driving()) else 0.65
	look_pitch = clampf(look_pitch - relative.y * sensitivity, -1.05, pitch_limit)
	player.rotation.y = look_yaw

func _build_beach() -> void:
	pass


func _beach_spawn() -> Vector3:
	return Vector3.ZERO


func _build_beach_fishing(_hud: CanvasLayer) -> void:
	pass


func _beach_is_sliding() -> bool:
	return beach_activities != null and beach_activities.is_sliding()


func _beach_is_seated() -> bool:
	return beach_activities != null and beach_activities.is_seated()


func _on_beach_dialog_opened() -> void:
	set_zone_modal(true)

func _on_beach_dialog_closed() -> void:
	set_zone_modal(false)


func _release_look() -> void:
	_touches.release_look()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _reset_input_context() -> void:
	_gamepad.suspend()
	if is_instance_valid(player):
		player.gamepad_motion = Vector2.ZERO
	_reset_zone_inputs()
	_release_look()
	_touches.reset()
	if is_instance_valid(player):
		player.held.clear()
		player.jump_buffer = 0.0

func _web_visibility_changed(_args: Array) -> void:
	var document := JavaScriptBridge.get_interface("document")
	if document != null:
		if bool(document.hidden):
			_on_window_blur()
		elif bool(document.hasFocus()):
			_on_window_focus()

func _on_window_blur() -> void:
	_gamepad_blurred = true
	_reset_input_context()

func _on_window_focus() -> void:
	_gamepad_blurred = false

func _on_controller_connection(id: int, connected: bool) -> void:
	if connected:
		if _gamepad.device < 0:
			_gamepad.attach(id)
			_gamepad_connected_grace_until = Time.get_ticks_msec()+180
	elif _gamepad.device == id:
		_gamepad.detach_device(id)
		if is_instance_valid(player):
			player.gamepad_motion = Vector2.ZERO
		_gamepad.follow_connected()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_on_window_blur()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_on_window_focus()

func _exit_tree() -> void:
	if OS.has_feature("web") and _web_visibility_callback != null:
		var document := JavaScriptBridge.get_interface("document")
		if document != null:
			document.removeEventListener("visibilitychange",_web_visibility_callback)
	_reset_input_context()

func _request_world_jump() -> void:
	if _can_use_world_controls() and (vehicles == null or not vehicles.is_driving()) and not _zone_local_actions_paused():
		player.request_jump()


var _hide_seeker_locked := false

func hide_seek_lock(on: bool) -> void:
	if _hide_seeker_locked == on:
		return
	_hide_seeker_locked = on
	if is_instance_valid(player):
		player.hide_seek_locked = on
		_reset_input_context()

func _world_input_blocked() -> bool:
	return _hide_seeker_locked or changing or zone_modal or _zone_blocks_world() or (fishing_ui != null and fishing_ui.is_modal_open()) or _zone_local_actions_paused()


func _toggle_mouse_look() -> void:
	if _world_input_blocked():
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_release_look()
	else:
		_touches.release_look()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _gamepad_input_blocked() -> bool:
	if _gamepad_blurred or Time.get_ticks_msec()<_gamepad_connected_grace_until or _world_input_blocked() or _beach_is_sliding() or (playground != null and not playground.ride.is_empty()):
		return true
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

func _route_gamepad(event: InputEvent) -> void:
	var blocked := _gamepad_input_blocked()
	var action := _gamepad.update(event,blocked)
	player.gamepad_motion = Vector2.ZERO if blocked else _gamepad.move()
	match action:
		"jump": _request_world_jump()
		"interact": _interact()
		"primary":
			_world_primary_action()

func _input(event: InputEvent) -> void:
	if GAMEPAD.accepts(event):
		_route_gamepad(event)
		get_viewport().set_input_as_handled()
		return
	if _consume_zone_input(event):
		get_viewport().set_input_as_handled()
		return
	if not _home_enter_target.is_empty() and Time.get_ticks_msec()>_home_wait_until:
		_home_enter_target.clear()
		_home_entry_message="Could not confirm your house. Try again."
		_home_wait_until=Time.get_ticks_msec()+3500
	if not _home_entry_message.is_empty() and Time.get_ticks_msec()>_home_wait_until:
		_home_entry_message=""
	var blocked := _world_input_blocked()
	if _touches.route(event,blocked):
		get_viewport().set_input_as_handled()
		return
	if blocked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and event.device != -1 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Release from anywhere if the mouse is locked, even over a HUD control.
		_release_look()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != -1 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_turn_arena_view(event.screen_relative, 0.003)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _world_input_blocked():
		return
	if event is InputEventMouseButton and event.device != -1 and event.pressed:
		# The HUD gets first chance at mouse presses. Left-click never enters camera mode.
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_mouse_look()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _world_primary_action():
				get_viewport().set_input_as_handled()

func _toggle_walking_view() -> bool:
	if arena or _world_input_blocked() or (vehicles != null and vehicles.is_driving()):
		return false
	first_person = not first_person
	get_tree().set_meta(FIRST_PERSON_META,first_person)
	if first_person:
		_third_person_pitch = look_pitch
		look_pitch = 0.0
	else:
		look_pitch = _third_person_pitch
	# Drop stale movement/touch ownership, but don't acquire or release desktop pointer lock.
	_touches.reset()
	player.held.clear()
	player.jump_buffer = 0.0
	_update_camera()
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if _hide_seeker_locked: return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _zone_local_actions_paused():
		return
	match event.physical_keycode:
		KEY_SPACE:
			_request_world_jump()
		KEY_E:
			_interact()
		KEY_R:
			if not changing and fishing_ui != null and not _beach_is_sliding() and fishing_ui.put_away():
				get_viewport().set_input_as_handled()
			elif not _world_input_blocked() and indoor and room != null and room.has_method("toggle_rest") and room.toggle_rest():
				get_viewport().set_input_as_handled()
		KEY_V:
			if _toggle_walking_view():
				get_viewport().set_input_as_handled()
		KEY_C:
			if not _world_input_blocked():
				_toggle_mouse_look()
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if fishing_ui != null and fishing_ui.is_modal_open():
				fishing_ui.close_modal()
			elif indoor and zone_modal and room != null and room.has_method("is_modal_open") and room.is_modal_open():
				room.close_modal()
			elif zone_modal and vehicles != null and vehicles.is_modal_open():
				vehicles.close_modal()
			elif zone_modal and town_progress != null and town_progress.has_method("is_modal_open") and town_progress.is_modal_open():
				town_progress.close_modal()
			_release_look()
		KEY_Q:
			look_shoulder *= -1.0



func _try_door() -> void:
	pass


func _load_profile() -> void:
	var tree := get_tree()
	var account := get_node_or_null("/root/WillowbrookBrowserSession")
	if OS.has_feature("web") and account != null and account.has_method("tend_garden"):
		tree.set_meta("willowbrook_save_override","")
		tree.set_meta("willowbrook_separate_profile",true)
	var path := "res://game/progression/profile.gd"
	if not ResourceLoader.exists(path):
		return
	if not tree.has_meta("willowbrook_profile"):
		var save_path := str(tree.get_meta("willowbrook_save_override","user://willowbrook_profile.cfg"))
		if not tree.has_meta("willowbrook_save_override"):
			var pattern := RegEx.create_from_string("^[a-zA-Z0-9_-]{1,24}$")
			for arg: String in OS.get_cmdline_user_args():
				if arg.begins_with("--profile="):
					var label := arg.trim_prefix("--profile=")
					if pattern.search(label) != null:
						save_path = "user://willowbrook_profile_%s.cfg" % label
						tree.set_meta("willowbrook_separate_profile",true)
						break
		tree.set_meta("willowbrook_profile",load(path).new(save_path))
	profile = tree.get_meta("willowbrook_profile")


func _pets_account() -> Node:
	if not OS.has_feature("web"): return null
	var node := get_node_or_null("/root/WillowbrookBrowserSession")
	return node if node!=null and node.has_method("pets_available") else null

func _refresh_outdoor_pets() -> void:
	if not is_instance_valid(outdoor_pets): return
	var account := _pets_account()
	var current := PET_CATALOG.state(profile.snapshot()) if profile!=null else {}
	if account!=null:
		current = account.pet_state() if account.pets_available() else {}
	outdoor_pets.synchronize(current)

func profile_snapshot() -> Dictionary:
	if not guest_variant.is_empty():
		return {"home":{"plot":room_plot,"variant":guest_variant},"furniture":guest_decor}
	var snapshot: Dictionary = profile.snapshot() if profile != null else {}
	var account := _pets_account()
	if account!=null and account.pets_available():
		snapshot.home = account.saved_home()
	return snapshot


func profile_commit(next: Dictionary) -> bool:
	if not guest_variant.is_empty(): return false
	var saved: bool = profile != null and profile.commit(next)
	if saved and not OS.has_feature("web"):
		_sync_town_home_exteriors()
	return saved


func set_zone_modal(open: bool) -> void:
	zone_modal = open
	player.held.clear()
	player.jump_buffer = 0.0
	player.movement_locked = open
	if open:
		_reset_input_context()


func current_zone_id() -> String:
	if indoor:
		return "home:%d" % room_plot if room_id == "home" else room_id
	return "paintball" if arena else ("beach" if beach else "town")


func _town_room_at() -> Dictionary:
	var town := get_node_or_null("TownLayout")
	if town == null:
		return {}
	var layout_script := town.get_script() as Script
	var layout_constants := layout_script.get_script_constant_map()
	var doors: Dictionary = layout_constants.get("BUSINESS_DOORS",{"arcade":TOWN_ROUTES.ARCADE_DOOR})
	for id: String in doors:
		var at: Vector3 = doors[id]
		if _near_at(at,2.75):
			return {"id":id,"at":at,"side":-1.0 if id in ["store","cafe"] else 1.0}
	var home_doors: Array = layout_constants.get("HOME_DOORS",[])
	var ownership: Variant = profile_snapshot().get("home",{})
	var owned := int(ownership.get("plot",-1)) if ownership is Dictionary else (-1 if not ownership is int else int(ownership))
	if owned is int and owned >= 0 and owned < home_doors.size() and _near_at(home_doors[owned],2.75):
		return {"id":"home","plot":owned,"at":home_doors[owned],"side":1.0}
	var account := _pets_account()
	if account!=null and account.has_method("home_visits_available") and account.home_visits_available():
		for i in range(home_doors.size()):
			if i!=owned and _near_at(home_doors[i],2.75):
				return {"id":"home","plot":i,"at":home_doors[i],"side":1.0,"guest":true}
	return {}


func _enter_room(target: Dictionary) -> void:
	var account := _pets_account()
	if target.id=="home" and account!=null and account.pets_available():
		if not _home_enter_target.is_empty(): return
		_home_entry_message=""
		var accepted: bool = account.home_visit_command("enter",target.plot) if target.get("guest",false) else account.pet_command("housing","enter",int(target.get("plot",-1)))
		if not accepted:
			_home_entry_message="Could not contact the town server."
			_home_wait_until=Time.get_ticks_msec()+3500
			return
		_home_enter_target=target
		_home_wait_until=Time.get_ticks_msec()+8000
		return
	_enter_room_confirmed(target)

func _house_entry_result(action: String,operation: String,ok: bool,text: String) -> void:
	if action!="housing" or operation!="enter" or _home_enter_target.is_empty(): return
	var target := _home_enter_target
	_home_enter_target={}
	if ok and not changing and _near_at(target.at,3.3):
		_enter_room_confirmed(target)
	else:
		_home_entry_message=text if not ok and not text.is_empty() else "Stand near your front door and try again."
		_home_wait_until=Time.get_ticks_msec()+3500

func _home_visit_notice(message: Dictionary) -> void:
	if message.get("action")=="enter" and not _home_enter_target.is_empty() and _home_enter_target.get("guest",false):
		var target := _home_enter_target
		_home_enter_target={}
		if message.get("ok")==true and int(message.get("plot",-1))==target.plot and not changing and _near_at(target.at,3.3):
			target["guestVariant"]=message.variant
			_enter_room_confirmed(target)
		else:
			var account := _pets_account()
			if account!=null and message.get("ok")==true: account.home_visit_command("leave")
			_home_entry_message=str(message.get("error","Stand near the door to visit."))
			_home_wait_until=Time.get_ticks_msec()+3500
	elif message.get("action")=="lock" and indoor and room!=null and guest_variant.is_empty():
		if message.get("ok")==true:
			home_locked=message.locked
			room.refresh_home_lock()
		room.feedback(str(message.get("error","Door locked; visitors were returned outside." if message.get("locked",false) else "Door unlocked.")))

func apply_home_scene(scene: Dictionary) -> void:
	if room_id!="home" or room==null: return
	if not guest_variant.is_empty():
		if scene.owner or scene.variant!=guest_variant: return
		_last_guest_scene=Time.get_ticks_msec()
		if scene.decor!=guest_decor:
			guest_decor=scene.decor
			room.refresh_guest_decor()
	elif scene.owner and home_locked!=scene.locked:
		home_locked=scene.locked
		room.refresh_home_lock()

func visit_ejected() -> void:
	if not guest_variant.is_empty() and not changing:
		go_to_town()

func _room_resource(destination: String) -> String:
	match destination:
		"home": return HOME_ROOM_SCENE
		"salon": return SALON_ROOM_SCENE
		"cafe": return CAFE_ROOM_SCENE
		"store": return STORE_ROOM_SCENE
		"library": return LIBRARY_ROOM_SCENE
		"bank": return BANK_ROOM_SCENE
		"vet": return VET_ROOM_SCENE
		"dive_shop": return DIVE_ROOM_SCENE
		"arcade": return "res://game/arcade/room.tscn"
		_: return "res://game/interiors/room.gd"


func _enter_room_confirmed(target: Dictionary) -> void:
	var tree := get_tree()
	var path := _room_resource(target.id)
	if not ResourceLoader.exists(path):
		return
	var side := float(target.side)
	var at: Vector3 = target.at
	tree.set_meta("room_destination",str(target.id))
	tree.set_meta("room_plot",int(target.get("plot",-1)))
	if target.has("guestVariant"): tree.set_meta("room_guest_variant",target.guestVariant)
	tree.set_meta("town_room_return",{"at":at + Vector3(0,0.04,side * 2.0),"yaw":PI if side > 0.0 else 0.0})
	_change_zone(ROOM)
	if not changing:
		tree.remove_meta("room_destination")
		tree.remove_meta("room_plot")
		tree.remove_meta("room_guest_variant")
		tree.remove_meta("town_room_return")


func go_to_town() -> void:
	if indoor and room_id == "dive_shop" and not changing:
		_change_zone(BEACH,"scuba_beach_return")
		return
	if indoor and not changing:
		var account := _pets_account()
		if room_id=="home" and account!=null and account.pets_available():
			if account.has_method("home_visit_command") and account.home_visits_available(): account.home_visit_command("leave")
			if guest_variant.is_empty(): account.pet_command("housing","leave")
		_change_zone(TOWN)


func can_open_network_menu() -> bool:
	return _can_use_world_controls()


func _can_use_world_controls() -> bool:
	# Shared by local jump and the multiplayer menu; each retains its own extra guards.
	return not _hide_seeker_locked and not changing and not zone_modal and player.is_physics_processing() and not _beach_is_sliding() and (playground == null or playground.ride.is_empty())


func _town_ride_session() -> Node:
	if not OS.has_feature("web") or indoor or arena or beach: return null
	var node := get_node_or_null("/root/WillowbrookBrowserSession")
	return node if node!=null and node.has_method("town_rides_available") and node.town_rides_available() else null


func _board_town_ride(ride: String, age := 0.0) -> void:
	playground.begin(ride,player.position)
	playground.tick(age)
	player.held.clear()
	player.velocity = Vector3.ZERO
	player.jump_buffer = 0.0
	player.set_physics_process(false)
	player.position = playground.pose()
	playground.apply_avatar(arena_avatar)


func sync_town_rides(state: Dictionary) -> void:
	if playground==null or indoor or arena or beach: return
	var self_ride: String = state.self
	_occupied_rides.clear()
	for row: Dictionary in state.active:
		_occupied_rides[row.target]=float(row.ageMs)/1000.0
	if _shared_ride and (self_ride.is_empty() or self_ride!=playground.ride):
		_shared_ride=false
		_ride_pending=0
		_leave_playground()
	if not self_ride.is_empty() and not _shared_ride and _occupied_rides.has(self_ride):
		_shared_ride=true
		_ride_pending=0
		_board_town_ride(self_ride,_occupied_rides[self_ride])


func town_ride_error(message: String) -> void:
	_ride_pending=0
	_ride_notice=message
	_ride_notice_deadline=Time.get_ticks_msec()+2400


func _leave_playground() -> void:
	player.position = playground.exit_position()
	playground.end(arena_avatar)
	player.jump_buffer = 0.0
	player.velocity = Vector3.ZERO
	player.held.clear()
	player.set_physics_process(true)


func set_room_seated(value: bool) -> void:
	room_seated = value
	player.jump_buffer = 0.0
