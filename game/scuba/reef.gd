extends Node3D
const TANK=preload("res://game/town_assets/scuba-starter/twin-scuba-tank-rig.glb")
const FIN_LEFT=preload("res://game/town_assets/scuba-starter/dive-fin-left.glb")
const FIN_RIGHT=preload("res://game/town_assets/scuba-starter/dive-fin-right.glb")
const BUBBLES=preload("res://game/scuba/audio/scuba-bubbles.mp3")
const SWIM=preload("res://game/scuba/animation/swim_animation.gd")
const DIVER=preload("res://game/scuba/diver.gd")
const REEF_ART=preload("res://game/scuba/reef_art.gd")
const REEF_TREASURES=preload("res://game/scuba/reef_treasures.gd")
const REEF_RINGS=preload("res://game/scuba/reef_rings.gd")
const REEF_GEYSERS=preload("res://game/scuba/reef_geysers.gd")
const REEF_PHOTOS=preload("res://game/scuba/reef_photos.gd")
const PHOTO_BOOK=preload("res://game/photo_book_ui.gd")
const FISHING=preload("res://game/fishing_game.gd")
const STICK=preload("res://game/movement_thumbstick.gd")
const ROUTER=preload("res://game/touch_router.gd")
const GAMEPAD=preload("res://game/gamepad_state.gd")
const AVATARS=preload("res://game/avatars/catalog.gd")
const FIT=preload("res://game/hud_fit.gd")
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
var photo_button: Button
var book_button: Button
var photo_book: Control
var _flash: ColorRect
var _flash_time:=0.0
var _profile: RefCounted
var _reef_photos: Array[String]=[]
var depth: Label
var activity_counts: Label
var treasure_banner: Label
var art: Node3D
var treasures: Node3D
var rings: Node3D
var geysers: Node3D
var _banner_time:=0.0
var _touch=ROUTER.new()
var _pad=GAMEPAD.new()
var _yaw:=0.0
var _pitch:=0.22
var _mouse_look:=false
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
	art=REEF_ART.new()
	art.name="ReefArt"
	add_child(art)
	treasures=REEF_TREASURES.new()
	treasures.name="ReefTreasures"
	add_child(treasures)
	treasures.treasure_found.connect(_on_treasure_found)
	rings=REEF_RINGS.new()
	rings.name="ReefRings"
	add_child(rings)
	rings.ring_passed.connect(_on_ring_passed)
	geysers=REEF_GEYSERS.new()
	geysers.name="ReefGeysers"
	add_child(geysers)
	_profile=REEF_PHOTOS.resolve_profile(get_tree())
	_reef_photos=REEF_PHOTOS.load_discovered(_profile)
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
	photo_button=_button("Photo")
	photo_button.name="PhotoButton"
	photo_button.pressed.connect(take_photo)
	book_button=_button("Book")
	book_button.name="BookButton"
	book_button.pressed.connect(open_photo_book)
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
	activity_counts=Label.new()
	activity_counts.name="ActivityCounts"
	activity_counts.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	activity_counts.add_theme_font_size_override("font_size",17)
	activity_counts.add_theme_constant_override("outline_size",4)
	activity_counts.mouse_filter=Control.MOUSE_FILTER_IGNORE
	activity_counts.set_anchors_preset(Control.PRESET_TOP_WIDE)
	activity_counts.offset_left=10.0
	activity_counts.offset_right=-10.0
	activity_counts.offset_top=36.0
	activity_counts.hide()
	hud.add_child(activity_counts)
	treasure_banner=Label.new()
	treasure_banner.name="TreasureBanner"
	treasure_banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	treasure_banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	treasure_banner.add_theme_font_size_override("font_size",24)
	treasure_banner.add_theme_constant_override("outline_size",6)
	treasure_banner.add_theme_color_override("font_color",Color("#fff3b0"))
	treasure_banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	treasure_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	treasure_banner.offset_left=24.0
	treasure_banner.offset_right=-24.0
	treasure_banner.offset_top=64.0
	treasure_banner.hide()
	hud.add_child(treasure_banner)
	var hint:=Label.new()
	hint.name="SwimHint"
	hint.text="WASD: Swim | Space/Ctrl: Rise/Dive | F: Photo\nR-click/C: Look | B: Book | E: Return"
	hint.position=Vector2(10,42)
	hint.add_theme_constant_override("outline_size",4)
	hud.add_child(hint)
	_flash=ColorRect.new()
	_flash.name="ShutterFlash"
	_flash.color=Color(1.0,1.0,1.0,0.0)
	_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.hide()
	hud.add_child(_flash)
	photo_book=PHOTO_BOOK.new()
	hud.add_child(photo_book)
	photo_book.closed.connect(close_photo_book)
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
	var compact_top:=screen_size.x<460.0
	depth.add_theme_font_size_override("font_size",15 if compact_top else 20)
	if photo_button!=null and book_button!=null:
		var btn_w:=(64.0 if compact_top else 76.0)*scale
		var btn_h:=(32.0 if compact_top else 34.0)*scale
		var gap:=6.0*scale
		var top_y:=8.0*scale
		var right_m:=10.0*scale
		book_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		book_button.custom_minimum_size=Vector2(btn_w,btn_h)
		book_button.offset_right=-right_m
		book_button.offset_left=-(right_m+btn_w)
		book_button.offset_top=top_y
		book_button.offset_bottom=top_y+btn_h
		book_button.add_theme_font_size_override("font_size",roundi((14.0 if compact_top else 15.0)*scale))
		photo_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		photo_button.custom_minimum_size=Vector2(btn_w,btn_h)
		photo_button.offset_right=-(right_m+btn_w+gap)
		photo_button.offset_left=-(right_m+btn_w*2.0+gap)
		photo_button.offset_top=top_y
		photo_button.offset_bottom=top_y+btn_h
		photo_button.add_theme_font_size_override("font_size",roundi((14.0 if compact_top else 15.0)*scale))
	if photo_book!=null:
		photo_book.resize_book()
	var hint:=hud.get_node("SwimHint") as Label
	hint.visible=not touch_ui or screen_size.x>640
	var counts_bottom:=36.0
	if activity_counts!=null and activity_counts.visible:
		counts_bottom=activity_counts.offset_top+maxf(24.0,activity_counts.get_combined_minimum_size().y)+4.0
	hint.position=Vector2(10,maxf(42.0,counts_bottom))
	if treasure_banner!=null:
		var top_below:=hint.position.y+hint.get_combined_minimum_size().y+10.0 if hint.visible else maxf(54.0,counts_bottom+8.0)
		treasure_banner.offset_top=maxf(96.0,top_below) if hint.visible else top_below

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
	return not _changing and not _network_modal and not is_book_open()

func is_book_open() -> bool:
	return photo_book!=null and photo_book.visible

func open_photo_book() -> void:
	if _changing or _network_modal or photo_book==null or is_book_open():
		return
	_reset_input()
	if is_instance_valid(diver):diver.velocity=Vector3.ZERO
	_reef_photos=REEF_PHOTOS.load_discovered(_profile)
	var caught: Array=_profile.snapshot().get("fish_discovered",[]) if _profile!=null else []
	var tabs: Array[Dictionary]=[
		FISHING.book_tab(caught),
		REEF_PHOTOS.book_tab(_reef_photos),
	]
	photo_book.configure_tabs(tabs)
	photo_book.open("reef")
	if photo_button!=null:photo_button.hide()
	if book_button!=null:book_button.hide()

func close_photo_book() -> void:
	if photo_book!=null:
		photo_book.hide()
	if photo_button!=null:photo_button.show()
	if book_button!=null:book_button.show()

func take_photo() -> Dictionary:
	if _changing or _network_modal or is_book_open():
		return {"ok":false}
	REEF_PHOTOS.play_shutter(self)
	_flash_time=0.22
	if _flash!=null:
		_flash.color=Color(1.0,1.0,1.0,0.42)
		_flash.show()
	var match_entry: Dictionary=REEF_PHOTOS.capture_in_view(camera,art,_reef_photos)
	if match_entry.is_empty():
		if treasure_banner!=null:
			treasure_banner.text="No reef wildlife in frame — swim closer!"
			treasure_banner.add_theme_color_override("font_color",Color("#d8f3ff"))
			_banner_time=2.0
			treasure_banner.show()
		return {"ok":false,"text":"No reef wildlife in frame."}
	var res: Dictionary=REEF_PHOTOS.record_photo(String(match_entry.id),_profile)
	if not bool(res.get("ok",false)):
		return res
	_reef_photos=res.discovered
	var entry: Dictionary=res.entry
	if treasure_banner!=null:
		if bool(res.get("new_discovery",false)):
			treasure_banner.text="New Reef Photo: %s!  (%d / %d)" % [entry.name,res.count,res.total]
			treasure_banner.add_theme_color_override("font_color",Color("#8dffb0"))
			_banner_time=3.0
		else:
			treasure_banner.text="Photographed %s!  (%d / %d)" % [entry.name,res.count,res.total]
			treasure_banner.add_theme_color_override("font_color",Color("#7bf1ff"))
			_banner_time=2.2
		treasure_banner.show()
	return res

func set_zone_modal(open: bool) -> void:
	_network_modal=open
	_reset_input()
	if is_instance_valid(diver):diver.velocity=Vector3.ZERO

func _exit_tree() -> void:
	if is_instance_valid(_chat_host) and _chat_host.has_method("bind_arena_chat"):
		_chat_host.bind_arena_chat(null)
	if _document!=null and _visibility!=null:_document.removeEventListener("visibilitychange",_visibility)

func _is_mouse_looking() -> bool:
	if DisplayServer.get_name()=="headless":
		return _mouse_look
	if _mouse_look and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		_mouse_look=false
	return Input.mouse_mode==Input.MOUSE_MODE_CAPTURED

func _release_look() -> void:
	_mouse_look=false
	if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _toggle_mouse_look() -> void:
	if _changing or _network_modal:
		return
	if _is_mouse_looking():
		_release_look()
	else:
		_touch.release_look()
		_mouse_look=true
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _reset_input() -> void:
	_touch.reset()
	_vertical_touches.clear()
	_rise_held=false
	_sink_held=false
	_pad_rise=false
	_pad_sink=false
	_pad.suspend()
	_release_look()

func _input(event: InputEvent) -> void:
	if _changing or _network_modal:
		if GAMEPAD.accepts(event):_pad.update(event,true)
		return
	if is_book_open():
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or event.keycode==KEY_B):
			close_photo_book()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and event.device!=-1 and _is_mouse_looking():
		# Release from anywhere if the mouse is locked, even over a HUD control.
		_release_look()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and event.device!=-1 and _is_mouse_looking():
		_look(event.screen_relative,.003)
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
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and event.device!=-1:
		# The HUD gets first chance at mouse presses. Left-click never enters camera mode.
		_toggle_mouse_look()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var focused:=get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			if event.keycode==KEY_ESCAPE:_release_look()
			return
		if event.keycode==KEY_ESCAPE:_reset_input()
		elif event.physical_keycode==KEY_C or event.keycode==KEY_C:
			_toggle_mouse_look()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_F or event.keycode==KEY_F:
			take_photo()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_B or event.keycode==KEY_B:
			open_photo_book()
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_E:return_to_shop()

func _look(at: Vector2, gain: float) -> void:
	_yaw=wrapf(_yaw-at.x*gain,-PI,PI)
	_pitch=clampf(_pitch+at.y*gain,-.88,.97)

func _physics_process(delta: float) -> void:
	if _flash_time>0.0:
		_flash_time=maxf(0.0,_flash_time-delta)
		if _flash!=null:
			_flash.color.a=(_flash_time/0.22)*0.42
			if _flash_time<=0.0:_flash.hide()
	if _changing or _network_modal or is_book_open():return
	var kb:=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	kb+=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var axis:Vector2=(kb+_pad.move()+diver.touch_motion).limit_length()
	var vertical:=float(Input.is_physical_key_pressed(KEY_SPACE) or _rise_held or _pad_rise or 1 in _vertical_touches.values())
	vertical-=float(Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_SHIFT) or _sink_held or _pad_sink or -1 in _vertical_touches.values())
	var aim:Vector2=(_pad.look()+_touch.look_motion).limit_length()
	_look(aim,delta*1.65)
	var lift:float=float(geysers.updraft_at(diver.position,vertical<-0.1)) if geysers!=null else 0.0
	_swim(axis,vertical,delta,lift)
	art.update_depth_mood(diver.position.y)
	_update_camera(delta)
	if treasures!=null:
		treasures.check_diver(diver.position)
	if rings!=null:
		rings.check_diver(diver.position)
	if _banner_time>0.0:
		_banner_time=maxf(0.0,_banner_time-delta)
		if _banner_time<=0.0 and treasure_banner!=null:
			treasure_banner.hide()
	depth.text="%s  %dm" % [art.landmark(diver.position),roundi(-diver.position.y)]
	if activity_counts!=null:
		var parts:=PackedStringArray()
		if treasures!=null and treasures.found_count>0:
			parts.append("Treasures %d / %d" % [treasures.found_count,treasures.total_count()])
		if rings!=null and rings.passed_count>0:
			parts.append("Rings %d / %d" % [rings.passed_count,rings.total_count()])
		var next_text:="  ·  ".join(parts)
		var next_visible:=not parts.is_empty()
		var changed:=activity_counts.text!=next_text or activity_counts.visible!=next_visible
		activity_counts.text=next_text
		activity_counts.visible=next_visible
		if changed:
			_layout()


func _on_ring_passed(passed: int, total: int, completed: bool) -> void:
	if treasure_banner==null or not completed:
		return
	treasure_banner.text="Reef melody complete!  (%d / %d)" % [passed,total]
	treasure_banner.add_theme_color_override("font_color",Color("#7bf1ff"))
	_banner_time=3.2
	treasure_banner.show()


func _on_treasure_found(title: String, found: int, total: int) -> void:
	if treasure_banner==null:
		return
	if found>=total:
		treasure_banner.text="All %d sunken reef treasures found!" % total
		treasure_banner.add_theme_color_override("font_color",Color("#8dffb0"))
		_banner_time=3.6
	else:
		treasure_banner.text="Found %s!  (%d / %d)" % [title,found,total]
		treasure_banner.add_theme_color_override("font_color",Color("#fff3b0"))
		_banner_time=2.6
	treasure_banner.show()

func _swim(axis: Vector2, vertical: float, dt: float, lift: float=0.0) -> void:
	var local:=Vector3(axis.x,0,axis.y)
	var target:=((Basis(Vector3.UP,_yaw)*local)+Vector3.UP*vertical*.72).limit_length()*SPEED
	if swim_player!=null:
		var wanted:=SWIM.STROKE if target.length_squared()>.15 else SWIM.AQUATIC_IDLE
		if swim_player.current_animation!=wanted:swim_player.play(wanted,.18)
	target.y+=lift
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
	if tree.change_scene_to_file("res://game/room.tscn")!=OK:
		_changing=false
		tree.remove_meta("scuba_shop_return")
		tree.remove_meta("room_destination")
