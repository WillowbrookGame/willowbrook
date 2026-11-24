extends Control

signal cancelled

const REEF := "res://game/scuba/reef.tscn"
const BOAT := preload("res://game/beach_art/beach-boats/boat-speed-a.glb")
const OCEAN := preload("res://game/beach_layout.gd")
const WAVES := preload("res://game/beach_audio/gentle_waves_stereo.wav")
const MIN_VISIBLE := 5.0
const LOAD_ON_FRAME := .35

var _boat: Node3D
var _camera: Camera3D
var _notice: Label
var _progress: ProgressBar
var _back: Button
var _retry: Button
var _visible_seconds := 0.0
var _visible_since := 0
var _attempted := false
var _failed := false
var _done := false
var _ready_scene: PackedScene
var _viewport: SubViewport
var _pose_received := false
var _waves: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var world := SubViewportContainer.new()
	world.stretch=true
	world.stretch_shrink=2
	world.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport=SubViewport.new()
	_viewport.own_world_3d=true
	_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	world.add_child(_viewport)
	var scenery := OCEAN.new()
	scenery.departure_only=true
	_viewport.add_child(scenery)
	_boat=BOAT.instantiate() as Node3D
	_viewport.add_child(_boat)
	var longest := 0.0
	for child in _boat.find_children("*","MeshInstance3D",true,false):
		var extent: Vector3 = (child.global_transform*child.get_aabb()).size
		longest=maxf(longest,maxf(extent.x,extent.z))
	_boat.scale=Vector3.ONE*(6.0/maxf(.1,longest))
	_camera=Camera3D.new()
	_viewport.add_child(_camera)
	_camera.current=true
	_camera.fov=52.0
	_pose_boat(0.0)
	_waves=AudioStreamPlayer.new()
	_waves.name="DepartureWaves"
	_waves.stream=WAVES
	_waves.volume_db=-17.0
	add_child(_waves)
	_waves.play()
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top=-119.0
	center.offset_bottom=-12.0
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	card.add_child(box)
	_notice=Label.new()
	_notice.text="Heading out to the reef…"
	_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size",21)
	box.add_child(_notice)
	_progress=ProgressBar.new()
	_progress.show_percentage=false
	_progress.custom_minimum_size=Vector2(255,8)
	_progress.max_value=MIN_VISIBLE
	box.add_child(_progress)
	var choices := HBoxContainer.new()
	choices.alignment=BoxContainer.ALIGNMENT_CENTER
	box.add_child(choices)
	_back=Button.new()
	_back.text="Back to Dive Shop"
	_back.custom_minimum_size.y=44
	_back.pressed.connect(cancel)
	choices.add_child(_back)
	_retry=Button.new()
	_retry.text="Try again"
	_retry.custom_minimum_size.y=44
	_retry.hide()
	_retry.pressed.connect(_restart)
	choices.add_child(_retry)
	_back.grab_focus()
	_wait_for_draw()

func _wait_for_draw() -> void:
	if DisplayServer.get_name()=="headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	if not _done and is_inside_tree():
		_visible_since=Time.get_ticks_msec()
		_pose_received=true

func _restart() -> void:
	if _done: return
	_attempted=false
	_failed=false
	_pose_received=false
	_visible_since=0
	_visible_seconds=0.0
	_ready_scene=null
	_retry.hide()
	_notice.text="Heading out to the reef…"
	_progress.value=0
	_wait_for_draw()

func _process(delta: float) -> void:
	if _done or _failed or not _pose_received: return
	if OS.has_feature("web"):
		var doc := JavaScriptBridge.get_interface("document")
		if doc != null:
			var hidden := bool(doc.hidden)
			if _waves.stream_paused!=hidden:_waves.stream_paused=hidden
			if hidden:return
	# Don't count an import spike or a hidden-tab gap as visible animation.
	_visible_seconds+=minf(delta,.10)
	_pose_boat(_visible_seconds)
	_progress.value=minf(_visible_seconds,MIN_VISIBLE)
	if not _attempted and _visible_seconds>=LOAD_ON_FRAME:
		_attempted=true
		call_deferred("_prepare_reef")
	# Both the displayed clip and ready asset gates must independently pass.
	if _ready_scene != null and _visible_seconds>=MIN_VISIBLE and Time.get_ticks_msec()-_visible_since>=5000:
		_done=true
		var tree := get_tree()
		var account := tree.root.get_node_or_null("WillowbrookBrowserSession")
		if account != null and account.has_method("player_avatar_id"):
			tree.set_meta("scuba_avatar",account.player_avatar_id())
		var status := tree.change_scene_to_packed(_ready_scene)
		if status!=OK:
			tree.remove_meta("scuba_avatar")
			_done=false
			_fail()

func _prepare_reef() -> void:
	if _done or not is_inside_tree(): return
	# Single-thread Web builds do not depend on threaded loader completion.
	# This deferred read happens only after the first visible boat frames.
	_ready_scene=ResourceLoader.load(REEF,"PackedScene") as PackedScene if ResourceLoader.exists(REEF,"PackedScene") else null
	if _ready_scene == null:
		_fail()

func _fail() -> void:
	_failed=true
	_retry.show()
	_notice.text="Reef did not load."
	_retry.grab_focus()

func _pose_boat(t: float) -> void:
	var heading := Vector3(-.43,0,-1).normalized()
	var travel := heading * (t*5.8)
	_boat.position=Vector3(-8,.05,-4)+travel+Vector3.UP*sin(t*3.1)*.12
	_boat.rotation=Vector3(sin(t*2.4)*.032,atan2(-heading.x,-heading.z)+PI,sin(t*1.8)*.052)
	var follow := travel*.64
	_camera.position=Vector3(4,6.7,9)+follow
	_camera.look_at(Vector3(-8,1,-5)+travel*.93,Vector3.UP)

func cancel() -> void:
	if _done: return
	_done=true
	_waves.stop()
	_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	hide()
	cancelled.emit()
	queue_free()
