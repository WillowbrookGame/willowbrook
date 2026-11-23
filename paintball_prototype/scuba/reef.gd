extends Node3D
const TANK=preload("res://paintball_prototype/town_assets/scuba-starter/twin-scuba-tank-rig.glb")
const FIN_LEFT=preload("res://paintball_prototype/town_assets/scuba-starter/dive-fin-left.glb")
const FIN_RIGHT=preload("res://paintball_prototype/town_assets/scuba-starter/dive-fin-right.glb")
const BUBBLES=preload("res://paintball_prototype/scuba/audio/scuba-bubbles.mp3")
const SWIM=preload("res://paintball_prototype/scuba/animation/swim_animation.gd")
const DIVER=preload("res://paintball_prototype/scuba/diver.gd")
const REEF_ART=preload("res://paintball_prototype/scuba/reef_art.gd")
const STICK=preload("res://paintball_prototype/movement_thumbstick.gd")
const ROUTER=preload("res://paintball_prototype/touch_router.gd")
const GAMEPAD=preload("res://paintball_prototype/gamepad_state.gd")
const AVATARS=preload("res://paintball_prototype/avatars/catalog.gd")
const FIT=preload("res://paintball_prototype/hud_fit.gd")
const SPAWN:=Vector3(0,-3,12)
const EXTENT:=Vector2(29,26)
const TOP:=-1.65
const SPEED:=5.6
var diver: CharacterBody3D
var avatar: Node3D
var swim_player: AnimationPlayer
var _network_modal:=false
var _chat_host: Node
var camera: Camera3D
var hud: CanvasLayer
var move_stick: Control
var look_stick: Control
var rise: Button
var sink: Button
var back: Button
var depth: Label
var art: Node3D
var _touch=ROUTER.new()
var _pad=GAMEPAD.new()
var _yaw:=0.0
var _pitch:=0.22
var _right:=false
var _rise_held:=false
var _sink_held:=false
var _pad_rise:=false
var _pad_sink:=false
var _changing:=false
var _document: JavaScriptObject
var _visibility: JavaScriptObject
var _bubbles: AudioStreamPlayer
var _vertical_touches: Dictionary={}

func _ready() -> void:
	_build_lighting()
	art=REEF_ART.new()
	art.name="ReefArt"
	add_child(art)
	diver=DIVER.new()
	diver.name="Diver"
	diver.collision_layer=0
	diver.collision_mask=1
	add_child(diver)
	diver.position=SPAWN
	var collision:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.32
	capsule.height=1.12
	collision.shape=capsule
	diver.add_child(collision)
	var character: Variant=get_tree().get_meta("scuba_avatar","male-a")
	get_tree().remove_meta("scuba_avatar")
	avatar=AVATARS.instantiate(character)
	avatar.scale=Vector3.ONE*2.8
	avatar.position.y=-.5
	avatar.rotation.y=PI # Kenney avatar faces local +Z; the initial swim view looks -Z.
	diver.add_child(avatar)
	swim_player=SWIM.bind(avatar)
	var avatar_animation:=AVATARS.animator(avatar) if swim_player==null else null
	if avatar_animation!=null and avatar_animation.has_animation("idle"):
		avatar_animation.play("idle")
	_fit_dive_gear()
	_bubbles=AudioStreamPlayer.new()
	_bubbles.name="ScubaBubbles"
	var bubble_loop:=BUBBLES.duplicate() as AudioStreamMP3
	bubble_loop.loop=true
	_bubbles.stream=bubble_loop
	_bubbles.volume_db=-12.0
	add_child(_bubbles)
	_bubbles.play()
	camera=Camera3D.new()
	camera.fov=66.0
	camera.far=72.0
	add_child(camera)
	camera.make_current()
	_update_camera(0.0)
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	get_window().focus_exited.connect(_reset_input)
	Input.joy_connection_changed.connect(_controller_changed)
	_pad.follow_connected()
	if OS.has_feature("web"):
		_chat_host=get_node_or_null("/root/WillowbrookBrowserSession")
		if _chat_host!=null and _chat_host.has_method("bind_arena_chat"):
			_chat_host.bind_arena_chat(self)
		_document=JavaScriptBridge.get_interface("document")
		_visibility=JavaScriptBridge.create_callback(_visibility_changed)
		if _document!=null:_document.addEventListener("visibilitychange",_visibility)

func _fit_dive_gear() -> void:
	# Kenney faces +Z. The original rig shows its cylinders/valves from +Z;
	# turn that face out toward -Z and put the thin harness side against the back.
	var tank:=TANK.instantiate() as Node3D
	tank.name="DiveTanks"
	var tank_fit:=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*.34),Vector3(0,.118,-.201))
	SWIM.attach_wearable(avatar,tank,"torso",tank_fit)
	# Each original fin has a heel pocket at -Z and its long blade in +Z.
	# The Kenney rig names these leg bones, but they skin the shoes as well.
	var left:=FIN_LEFT.instantiate() as Node3D
	left.name="LeftDiveFin"
	SWIM.attach_wearable(avatar,left,"leg-left",Transform3D(Basis.IDENTITY.scaled(Vector3(.81,.85,.76)),Vector3(.107,-.02,.112)))
	var right:=FIN_RIGHT.instantiate() as Node3D
	right.name="RightDiveFin"
	SWIM.attach_wearable(avatar,right,"leg-right",Transform3D(Basis.IDENTITY.scaled(Vector3(.81,.85,.76)),Vector3(-.107,-.02,.112)))

func _build_lighting() -> void:
	var world:=WorldEnvironment.new()
	var tone:=Environment.new()
	tone.background_mode=Environment.BG_COLOR
	tone.background_color=Color("#126678")
	tone.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	tone.ambient_light_color=Color("#a6e7ed")
	tone.ambient_light_energy=.72
	tone.fog_enabled=true
	tone.fog_light_color=Color("#23798e")
	tone.fog_density=.038
	tone.fog_sky_affect=0.0
	world.environment=tone
	add_child(world)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-57,-27,0)
	light.light_color=Color("#b8ffed")
	light.light_energy=1.15
	add_child(light)

func _button(title: String) -> Button:
	var b:=Button.new()
	b.text=title
	b.focus_mode=Control.FOCUS_NONE
	hud.add_child(b)
	return b

func _build_hud() -> void:
	hud=CanvasLayer.new()
	add_child(hud)
	move_stick=STICK.new()
	look_stick=STICK.new()
	look_stick.camera_control=true
	hud.add_child(move_stick)
	hud.add_child(look_stick)
	move_stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	look_stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	rise=_button("Swim up")
	sink=_button("Swim down")
	back=_button("Return to dive shop")
	back.pressed.connect(return_to_shop)
	rise.button_down.connect(func():_rise_held=true)
	rise.button_up.connect(func():_rise_held=false)
	sink.button_down.connect(func():_sink_held=true)
	sink.button_up.connect(func():_sink_held=false)
	_touch.configure(hud,diver,null,func():pass,move_stick,look_stick)
	depth=Label.new()
	depth.position=Vector2(10,8)
	depth.add_theme_font_size_override("font_size",20)
	depth.add_theme_constant_override("outline_size",4)
	hud.add_child(depth)
	var hint:=Label.new()
	hint.name="SwimHint"
	hint.text="WASD to swim | Space / Ctrl to rise / dive\nRight-drag to look | E to return"
	hint.position=Vector2(10,42)
	hint.add_theme_constant_override("outline_size",4)
	hud.add_child(hint)
	_layout()

func _layout() -> void:
	var screen_size:=get_viewport().get_visible_rect().size
	var touch_ui:=FIT.touch_available()
	var wanted:=FIT.touch_scale(get_viewport()) if touch_ui else FIT.physical_scale(get_viewport())
	var scale:=minf(wanted,maxf(.7, minf(screen_size.x/345.0,screen_size.y/335.0)))
	move_stick.visible=touch_ui
	look_stick.visible=touch_ui
	move_stick.fit_hud(screen_size.x,scale)
	look_stick.fit_hud(screen_size.x,scale)
	FIT.right_button(rise,Vector2(120,48),183.0,scale)
	FIT.right_button(sink,Vector2(120,48),126.0,scale)
	FIT.right_button(back,Vector2(172,48),243.0,scale)
	hud.get_node("SwimHint").visible=not touch_ui or screen_size.x>640

func _controller_changed(id: int, connected: bool) -> void:
	if connected:_pad.follow_connected()
	else:
		_pad_rise=false
		_pad_sink=false
		_pad.detach_device(id)

func _visibility_changed(_args: Array) -> void:
	if _document==null:return
	var hidden:=bool(_document.hidden)
	if hidden:_reset_input()
	_bubbles.stream_paused=hidden

func can_open_network_menu() -> bool:
	return not _changing and not _network_modal

func set_zone_modal(open: bool) -> void:
	_network_modal=open
	_reset_input()
	if is_instance_valid(diver):diver.velocity=Vector3.ZERO

func _exit_tree() -> void:
	if is_instance_valid(_chat_host) and _chat_host.has_method("bind_arena_chat"):
		_chat_host.bind_arena_chat(null)
	if _document!=null and _visibility!=null:_document.removeEventListener("visibilitychange",_visibility)

func _reset_input() -> void:
	_touch.reset()
	_vertical_touches.clear()
	_rise_held=false
	_sink_held=false
	_pad_rise=false
	_pad_sink=false
	_right=false
	_pad.suspend()
	if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if _changing or _network_modal:
		if GAMEPAD.accepts(event):_pad.update(event,true)
		return
	if event is InputEventMouseButton and _right and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		_right=false
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if not event.pressed and _vertical_touches.has(event.index):
			_vertical_touches.erase(event.index)
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			if rise.get_global_rect().has_point(event.position):_vertical_touches[event.index]=1
			elif sink.get_global_rect().has_point(event.position):_vertical_touches[event.index]=-1
			if _vertical_touches.has(event.index):
				get_viewport().set_input_as_handled()
				return
	if event is InputEventScreenDrag and _vertical_touches.has(event.index):
		get_viewport().set_input_as_handled()
		return
	if _touch.route(event,false):
		get_viewport().set_input_as_handled()
		return
	if GAMEPAD.accepts(event):
		var action:String=_pad.update(event,false)
		if event is InputEventJoypadButton and event.device==_pad.device:
			if event.button_index==JOY_BUTTON_A:_pad_rise=event.pressed
		if event is InputEventJoypadMotion and event.device==_pad.device and event.axis==JOY_AXIS_TRIGGER_RIGHT:
			_pad_sink=event.axis_value>.42
		if action=="interact":return_to_shop()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _changing or _network_modal:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.device!=-1:
		_right=event.pressed
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if _right else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _right and event.device!=-1:
		_look(event.screen_relative,.003)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:_reset_input()
		elif event.keycode==KEY_E:return_to_shop()

func _look(at: Vector2, gain: float) -> void:
	_yaw=wrapf(_yaw-at.x*gain,-PI,PI)
	_pitch=clampf(_pitch+at.y*gain,-.88,.97)

func _physics_process(delta: float) -> void:
	if _changing or _network_modal:return
	var kb:=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	kb+=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var axis:Vector2=(kb+_pad.move()+diver.touch_motion).limit_length()
	var vertical:=float(Input.is_physical_key_pressed(KEY_SPACE) or _rise_held or _pad_rise or 1 in _vertical_touches.values())
	vertical-=float(Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_SHIFT) or _sink_held or _pad_sink or -1 in _vertical_touches.values())
	var aim:Vector2=(_pad.look()+_touch.look_motion).limit_length()
	_look(aim,delta*1.65)
	_swim(axis,vertical,delta)
	_update_camera(delta)
	depth.text="%s  %dm" % [art.landmark(diver.position),roundi(-diver.position.y)]

func _swim(axis: Vector2, vertical: float, dt: float) -> void:
	var local:=Vector3(axis.x,0,axis.y)
	var target:=((Basis(Vector3.UP,_yaw)*local)+Vector3.UP*vertical*.72).limit_length()*SPEED
	if swim_player!=null:
		var wanted:=SWIM.STROKE if target.length_squared()>.15 else SWIM.AQUATIC_IDLE
		if swim_player.current_animation!=wanted:swim_player.play(wanted,.18)
	diver.velocity=diver.velocity.move_toward(target,(18.0 if target.length_squared()>.03 else 26.0)*dt)
	diver.move_and_slide()
	var at:=diver.position
	var floor_y:float=art.floor_at(at)
	if (at.y>=TOP and diver.velocity.y>0.0) or (at.y<=floor_y+.9 and diver.velocity.y<0.0):
		diver.velocity.y=0.0
	diver.position=Vector3(clampf(at.x,-EXTENT.x,EXTENT.x),clampf(at.y,floor_y+.9,TOP),clampf(at.z,-EXTENT.y,EXTENT.y))
	if Vector2(target.x,target.z).length_squared()>.04:
		avatar.rotation.y=lerp_angle(avatar.rotation.y,atan2(target.x,target.z),minf(1.0,dt*11.0))
	avatar.rotation.x=lerpf(avatar.rotation.x,-clampf(diver.velocity.y*.12,-.32,.32),minf(1.0,dt*8.0))

func _update_camera(dt: float) -> void:
	var pivot:=diver.position+Vector3.UP*.22
	var arm:Vector3=(Basis(Vector3.UP,_yaw)*Basis(Vector3.RIGHT,-_pitch))*Vector3(0,.8,3.5)
	var query:=PhysicsRayQueryParameters3D.create(pivot,pivot+arm,1,[diver.get_rid()])
	var wall:=get_world_3d().direct_space_state.intersect_ray(query) if dt>0.0 else {}
	var at:Vector3=pivot+arm if wall.is_empty() else wall.position-arm.normalized()*.12
	camera.position=at if dt<=0.0 or not wall.is_empty() else camera.position.lerp(at,1.0-exp(-16.0*dt))
	if camera.position.distance_squared_to(pivot)>.02:camera.look_at(pivot,Vector3.UP)

func return_to_shop() -> void:
	if _changing:return
	_changing=true
	_reset_input()
	var tree:=get_tree()
	tree.set_meta("scuba_shop_return",true)
	tree.set_meta("room_destination","dive_shop")
	if tree.change_scene_to_file("res://paintball_prototype/room.tscn")!=OK:
		_changing=false
		tree.remove_meta("scuba_shop_return")
		tree.remove_meta("room_destination")
