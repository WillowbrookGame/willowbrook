extends Node3D

signal dialog_opened
signal dialog_closed

const FISHING = preload("res://game/fishing_game.gd")
const CAST_SOUND = preload("res://game/beach_audio/cast_whoosh.wav")
const LAND_SOUND = preload("res://game/beach_audio/splash_12.ogg")
const WAVE_PATH := "res://game/beach_audio/gentle_waves_stereo.wav"
const NIBBLE_SOUND = preload("res://game/beach_audio/fish_nibble.wav")
const BITE_SOUND = preload("res://game/beach_audio/bite_reel.wav")
const CATCH_SOUND = preload("res://game/beach_audio/catch_splash.wav")
const INTERACTION := 3.0
const WATER_Y := -0.17
const MAX_CAST := 17.0
const PREVIEW_PATH := "res://game/fish_art/"
const HUD_FIT = preload("res://game/hud_fit.gd")
const PHOTO_BOOK = preload("res://game/photo_book_ui.gd")
const THUMB_PATH := "res://game/fish_thumbs/"
var game: FISHING
const PROX = preload("res://game/npc_proximity.gd")
var _account: Node
var _fishing_pending: Dictionary = {}
var _sale_quote_id := ""
var _online_cast_id := ""
var _client_pop_at := -1.0
var _client_inventory_at := -1.0
var _remote_rods: Dictionary = {}
var _cast_cancelled := ""
var player: CharacterBody3D
var layout: Node3D
var avatar: Node3D
var _turning_actor: Node3D
var _resting_yaw := 0.0
var held_rod: Node3D
var skeleton: Skeleton3D
var arm_index := -1
var arm_pose: Quaternion
var player_animation: AnimationPlayer
var shadow_nodes: Dictionary = {}
var bobber: MeshInstance3D
var aim_ring: MeshInstance3D
var bite_cue: Label3D
var actions_suspended := false
var session_only := false
var _aim_timer := 0.0
var fishing_line: MeshInstance3D
var cast_origin := Vector3.ZERO
var cast_tip := Vector3.ZERO
var ripples: Array[MeshInstance3D] = []
var droplets: Array[MeshInstance3D] = []
var water_time := 0.0
var cast_audio: AudioStreamPlayer
var plop_audio: AudioStreamPlayer
var wave_audio: AudioStreamPlayer
var nibble_audio: AudioStreamPlayer
var last_sounded_nibble := -1
var bite_audio: AudioStreamPlayer
var catch_audio: AudioStreamPlayer
var splash_pending := false
var overlay: CenterContainer
var dialog_panel: PanelContainer
var dialog_padding: MarginContainer
var dialog_column: VBoxContainer
var heading: Label
var sale_cards: VBoxContainer
var sale_total: Label
var secondary: Button
var dialog: Label
var primary: Button
var status: Label
var cast_button: Button
var put_away_button: Button
var book_button: Button
var photo_book: Control
var stats: Label
var sale_mode := false
var note_time := 0.0

func setup(body: CharacterBody3D, scenery: Node3D, canvas: CanvasLayer, character: Node3D, animation: AnimationPlayer, town_profile: RefCounted = null) -> void:
	session_only = OS.has_feature("web") and get_tree().has_meta("willowbrook_separate_profile")
	var fishing_path := "" if get_tree().has_meta("willowbrook_separate_profile") else "user://fishing_profile.cfg"
	game = FISHING.new(String(get_tree().get_meta("fishing_save_override",fishing_path)))
	if not get_tree().has_meta("fishing_save_override"):
		game.attach_town_profile(town_profile)
	player = body
	layout = scenery
	avatar = character
	player_animation = animation
	skeleton = character.find_children("*","Skeleton3D",true,false).front() as Skeleton3D
	arm_index = skeleton.find_bone("arm-right")
	animation.play("holding-right")
	animation.advance(0)
	arm_pose = skeleton.get_bone_pose_rotation(arm_index)
	animation.play("idle")
	animation.advance(0)
	held_rod = layout.make_rod(1.65)
	add_child(held_rod)
	held_rod.hide()
	bobber = _shape(Color("#ff7245"),Vector3(0.14,0.14,0.14))
	bobber.hide()
	add_child(bobber)
	aim_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .23
	ring.outer_radius = .29
	ring.rings = 16
	ring.ring_segments = 6
	aim_ring.mesh = ring
	var aim_mat := _paint(Color("#cafbff80"))
	aim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_ring.material_override = aim_mat
	aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_ring.scale.y = .18
	add_child(aim_ring)
	aim_ring.hide()
	bite_cue = Label3D.new()
	bite_cue.text = "!"
	bite_cue.font_size = 40
	bite_cue.outline_size = 8
	bite_cue.modulate = Color("#ffd875")
	bite_cue.pixel_size = .012
	bite_cue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(bite_cue)
	bite_cue.hide()
	fishing_line = MeshInstance3D.new()
	fishing_line.mesh = ImmediateMesh.new()
	fishing_line.material_override = _paint(Color("#f6ead9"))
	add_child(fishing_line)
	if OS.has_feature("web"):
		var account := get_node_or_null("/root/WillowbrookBrowserSession")
		if account != null and account.has_method("send_fishing"):
			use_fishing_account(account)
	if _account == null:
		game.start_population([], layout.is_water)
	_build_water_effects()
	_build_beach_audio()
	_build_hud(canvas)
	_update_stats()

func use_fishing_account(account: Node) -> void:
	_account = account
	game.population.clear()
	_account.fishing_reply.connect(_on_fishing_reply)

func _ask_fishing(operation: String, fields: Dictionary = {}) -> bool:
	if not _fishing_pending.is_empty():
		return false
	if not _account.admitted:
		_note("Reconnect to fish and keep your catch saved.")
		return false
	var id := Crypto.new().generate_random_bytes(12).hex_encode()
	if not _account.send_fishing(operation,id,fields):
		_note("Connection lost. Reconnect to manage your saved fish.")
		return false
	_fishing_pending = {"id":id,"operation":operation,"at":Time.get_ticks_msec()}
	if book_button != null:
		book_button.disabled = true
	return true

func _on_fishing_reply(message: Dictionary) -> void:
	if _fishing_pending.get("id") != message.get("requestId"):
		return
	_fishing_pending.clear()
	if book_button != null:
		book_button.disabled = false
	var op: String = message.operation
	var success: bool = message.ok
	var info: String = String(message.get("error",message.get("text","")))
	_sync_online_fishing(0.0)
	_note(info)
	match op:
		"cast":
			if success and not game.line.is_empty():
				cast_audio.play()
				splash_pending = true
				last_sounded_nibble = -1
		"reel":
			nibble_audio.stop()
			bite_audio.stop()
			if success and message.get("caught") is Dictionary:
				var caught := _species(String(message.caught.get("type","")))
				if not caught.is_empty():
					catch_audio.play()
					_show_catch(caught,bool(message.get("newDiscovery",false)))
			else:
				plop_audio.stop()
				plop_audio.play()
		"quote":
			if success and message.get("quote") is Dictionary:
				var quote: Dictionary = message.quote
				var entries: Array[Dictionary] = []
				for item: Dictionary in quote.items:
					var fish := _species(String(item.get("type","")))
					if not fish.is_empty():
						entries.append(fish)
				_sale_quote_id = quote.quoteId
				_show_sale_quote({"items":entries,"total":int(quote.total)})
			else:
				_show_dialog("Marina",info,false)
		"sell":
			_sale_quote_id = ""
			_show_dialog("Sale Complete" if success else "Sale Not Completed",info,false)
			primary.text = "Back to the Beach" if success else "Close"

func _species(id: String) -> Dictionary:
	for fish: Dictionary in FISHING.CATALOG:
		if fish.id == id:
			return fish
	return {}

func _sync_online_fishing(delta: float) -> void:
	if not _account.admitted:
		game.equipped = false
		game.line.clear()
		game.population.clear()
		game.inventory.clear()
		game.discovered.clear()
		game.stars = 0
		_client_inventory_at = -1.0
		_client_pop_at = -1.0
		_sync_remote_casts({})
		var had_book := photo_book != null and photo_book.visible
		if photo_book != null:
			photo_book.configure_tabs(_fishing_book_tabs())
			photo_book.hide()
		if book_button != null:
			book_button.disabled = false
		if not _fishing_pending.is_empty() or sale_mode:
			_fishing_pending.clear()
			_sale_quote_id = ""
			_show_dialog("Fishing paused","Connection lost. Sign in again to check your saved fish and stars.",false)
		elif had_book:
			dialog_closed.emit()
		_update_stats()
		return
	var view: Dictionary = _account.fishing_snapshot()
	var world: Dictionary = _account.fishing_world()
	var live: Dictionary = world.get("fishingVisual",{}) if float(world.get("serverTime",-1)) > float(view.get("_received_at",-1)) else {}
	var cast: Variant = view.get("cast") if live.is_empty() else live.get("cast")
	game.equipped = bool(view.get("equipped",false) if live.is_empty() else live.get("equipped",false))
	game.stars = _account.saved_stars()
	var receipt := float(view.get("_received_at",-1))
	if _client_inventory_at != receipt:
		_client_inventory_at = receipt
		game.inventory.clear()
		for item: Dictionary in view.get("inventory",[]):
			game.inventory.append(String(item.get("type","")))
		game.discovered = game._dedupe_species(view.get("discovered",[]))
		if photo_book != null and photo_book.visible:
			photo_book.configure_tabs(_fishing_book_tabs())
	var now := float(_account.fishing_now())
	if cast is Dictionary and String(cast.id) != _cast_cancelled and not actions_suspended and now <= float(cast.expiresAt):
		_online_cast_id = String(cast.id)
		var start := float(cast.startedAt)
		var nibbles: Array[float] = []
		for n: float in cast.nibbles:
			nibbles.append((n-start)/1000.0)
		game.line = {"position":Vector3(float(cast.x),0,float(cast.z)),"age":maxf(0.,(now-start)/1000.),"empty":cast.get("biteAt")==null,"bite_at":(float(cast.get("biteAt",start))-start)/1000. if cast.get("biteAt")!=null else INF,"nibbles":nibbles,"expires_at":(float(cast.expiresAt)-start)/1000.}
	else:
		_online_cast_id = ""
		game.line.clear()
	var world_tick := float(world.get("serverTime",-1))
	if _client_pop_at != world_tick:
		_client_pop_at = world_tick
		var previous := {}
		for entry: Dictionary in game.population:
			previous[entry.id] = entry.position
		game.population.clear()
		for fish: Dictionary in world.get("fishPopulation",[]):
			var heading := Vector3(float(fish.get("headingX",0)),0,float(fish.get("headingZ",-1)))
			var id := String(fish.id).hash()
			var target := Vector3(float(fish.x),0,float(fish.z))
			game.population.append({"id":id,"position":previous.get(id,target),"target":target,"heading":heading,"size":float(fish.size)})
	for entry: Dictionary in game.population:
		entry.position = (entry.position as Vector3).lerp(entry.target,1.0-exp(-14.0*maxf(0.0,delta)))
	if not _fishing_pending.is_empty() and Time.get_ticks_msec()-int(_fishing_pending.at) > 5500:
		var selling: bool = _fishing_pending.operation == "sell"
		_fishing_pending.clear()
		if selling:
			_show_dialog("Sale status unknown","Check your saved bag and stars before asking Marina for a new offer.",false)
		else:
			_note("The fishing server didn't answer. Please try again.")
	_sync_remote_casts(world)
	_update_stats()

func _sync_remote_casts(world: Dictionary) -> void:
	var seen := {}
	for row: Dictionary in world.get("players",[]):
		var id := int(row.id)
		if not bool(row.get("fishingEquipped",false)):
			continue
		var ghost: Node3D = _account.fishing_peer(id)
		if not is_instance_valid(ghost):
			continue
		seen[id] = true
		if not _remote_rods.has(id) or not is_instance_valid(_remote_rods[id].rod):
			if _remote_rods.has(id):
				_remote_rods[id].float.queue_free()
			var rod: Node3D = layout.make_rod(1.65)
			ghost.add_child(rod)
			rod.position = Vector3(-.31,1.1,.25)
			rod.rotation.x = -.89
			var remote_float := _shape(Color("#ef8153"),Vector3(.14,.14,.14))
			add_child(remote_float)
			_remote_rods[id] = {"rod":rod,"float":remote_float}
		var remote_cast: Variant = row.get("fishingCast")
		var other_float: Node3D = _remote_rods[id].float
		other_float.visible = remote_cast is Dictionary and _account.fishing_now() >= float(remote_cast.landAt) and _account.fishing_now() <= float(remote_cast.expiresAt)
		if other_float.visible:
			other_float.position = Vector3(float(remote_cast.x),WATER_Y+.11,float(remote_cast.z))
	for id: int in _remote_rods.keys():
		if seen.has(id):
			continue
		var nodes: Dictionary = _remote_rods[id]
		if is_instance_valid(nodes.rod):
			nodes.rod.queue_free()
		nodes.float.queue_free()
		_remote_rods.erase(id)

func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _shape(color: Color, size: Vector3) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 5
	result.mesh = sphere
	result.scale = size
	result.material_override = _paint(color)
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

func is_modal_open() -> bool:
	return overlay.visible or (photo_book != null and photo_book.visible)

func _near(at: Vector3) -> bool:
	return Vector2(player.position.x-at.x,player.position.z-at.z).length() < INTERACTION

func interaction_prompt() -> String:
	if actions_suspended or is_modal_open() or not game.line.is_empty():
		return ""
	if not game.equipped and _near(layout.POLE):
		return "Pick up fishing pole"
	var at := player.global_position
	var finn: Vector3 = layout.to_global(layout.FISHER_NPC)
	var marina: Vector3 = layout.to_global(layout.MARINA_POSITION)
	if PROX.visible_from(layout,at,finn,3.3,finn,[player.get_rid()]):
		return "Talk to Finn"
	# The kiosk has one coarse solid shell. Talk through the open serving frontage,
	# stopping the sight line at that frontage, never through the sides or rear.
	var front := layout.to_global(Vector3(layout.MARINA_POSITION.x,0,30.12))
	if at.z < front.z and absf(at.x-front.x) <= 3.5 and PROX.visible_from(layout,at,marina,7.0,front,[player.get_rid()]):
		return "Talk to Marina"
	return ""

func try_interact() -> bool:
	match interaction_prompt():
		"Pick up fishing pole":
			if _account != null:
				_ask_fishing("equip")
			else:
				_note(game.equip_pole().get("text","Fishing pole equipped."))
		"Talk to Finn":
			_face_customer("Finn")
			_show_dialog("Finn", "Pick up a pole by the pier, then left-click to cast into the water. Look for fish shadows near either pier or along the beach. Wait for a real bite before reeling in. Marina at the snack shop buys your catch. Press R or tap Put Away to stow the pole.",false)
		"Talk to Marina":
			_face_customer("Marina")
			_show_sale()
		_:
			return false
	return true

func _face_customer(actor_name: String) -> void:
	var actor := layout.find_child(actor_name,true,false) as Node3D
	if actor != null:
		var direction := player.global_position - actor.global_position
		if Vector2(direction.x,direction.z).length_squared() > 0.01:
			_turning_actor = actor
			_resting_yaw = actor.rotation.y
			actor.rotation.y = atan2(direction.x,direction.z)

func click(camera: Camera3D) -> void:
	if actions_suspended or is_modal_open() or not game.equipped:
		return
	if not game.line.is_empty():
		if game.phase() == "casting":
			return
		if _account != null:
			if not _online_cast_id.is_empty():
				_ask_fishing("reel",{"castId":_online_cast_id})
			return
		nibble_audio.stop()
		bite_audio.stop()
		var result: Dictionary = game.reel()
		if not result.has("caught"):
			plop_audio.stop()
			plop_audio.play()
		_note(result.get("text","Reeled in."))
		_update_stats()
		if result.get("ok",false) and result.has("caught"):
			catch_audio.play()
			_show_catch(result.caught,bool(result.get("new_discovery",false)))
		return
	var target := _aim_target(camera)
	if not target.is_finite():
		_note("Face open water with no buildings or boats in the way.")
		return
	cast_origin = player.global_position
	cast_tip = to_local(_rod_tip())
	if _account != null:
		_ask_fishing("cast",{"x":target.x,"z":target.z})
		return
	var cast_result: Dictionary = game.cast_at(target)
	if cast_result.get("ok",false):
		cast_audio.play()
		splash_pending = true
		last_sounded_nibble = -1
		aim_ring.hide()
	_note(cast_result.get("text","Line cast."))


func _rod_tip() -> Vector3:
	var feet := player.global_position
	# The held art is updated in physics; avoid the origin if the player
	# equips and casts before the first rod pose has been evaluated.
	var tip := held_rod.to_global(Vector3.UP*1.65)
	return tip if tip.distance_to(feet)<3.8 else feet+Vector3.UP*1.4


func _aim_target(camera: Camera3D) -> Vector3:
	if not is_instance_valid(camera):
		return Vector3.INF
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var feet := player.global_position
	var horizontal := Vector3(direction.x,0,direction.z).normalized()
	var water_at_feet := Vector3(feet.x,WATER_Y,feet.z)
	var target := water_at_feet + horizontal*10.0
	if direction.y < -.045:
		var projected := origin + direction*((WATER_Y-origin.y)/direction.y)
		target = water_at_feet+(projected-water_at_feet).limit_length(MAX_CAST)
	if layout.is_boat_water(target):
		return Vector3.INF
	if not layout.is_water(target) or target.distance_to(water_at_feet)<1.25:
		# Lead an aim on pier planks to the nearest clear water, never through a hull.
		target = Vector3.INF
		for distance: float in [5.0,8.0,11.0,14.0,17.0]:
			var ahead := water_at_feet+horizontal*distance
			if layout.is_boat_water(ahead):
				return Vector3.INF
			if layout.is_water(ahead):
				target = ahead
				break
	if not target.is_finite() or not _cast_path_clear(_rod_tip(),target):
		return Vector3.INF
	return target


func _cast_path_clear(from: Vector3, target: Vector3) -> bool:
	if not layout.is_water(target):
		return false
	var end := Vector3(target.x,WATER_Y+.14,target.z)
	var h := _cast_arc_height(from,end)
	var last := from
	var space := get_world_3d().direct_space_state
	for i in range(1,13):
		var t := float(i)/12.0
		var point := from.lerp(end,t)+Vector3.UP*sin(t*PI)*h
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(last,point,1,[player.get_rid()])).is_empty():
			return false
		# A straight water-plane projection must not cross either moored hull.
		for fraction: float in [.33,.67,1.0]:
			if layout.is_boat_water(last.lerp(point,fraction)):
				return false
		last = point
	return true


func _cast_arc_height(from: Vector3, to: Vector3) -> float:
	return clampf(from.distance_to(to)*.24,1.15,3.0)


func set_actions_suspended(value: bool) -> void:
	actions_suspended = value
	if value:
		_cancel_active_cast()
		splash_pending = false
		cast_audio.stop()
		nibble_audio.stop()
		bite_audio.stop()
		held_rod.hide()
		cast_button.hide()
		put_away_button.hide()
		if book_button != null:
			book_button.hide()
		aim_ring.hide()
		_draw_line()


func try_touch_put_away(viewport_point: Vector2) -> bool:
	return put_away_button.visible and put_away_button.get_global_rect().has_point(viewport_point) and put_away()


func put_away() -> bool:
	if actions_suspended or not game.equipped or is_modal_open():
		return false
	if _account != null:
		if not _ask_fishing("putAway"):
			return false
	else:
		game.put_away()
	splash_pending = false
	cast_audio.stop()
	nibble_audio.stop()
	bite_audio.stop()
	held_rod.hide()
	cast_button.hide()
	put_away_button.hide()
	_draw_line()
	_note("Fishing pole put away.")
	return true


func _cancel_active_cast() -> void:
	if _account != null and not _online_cast_id.is_empty():
		_cast_cancelled = _online_cast_id
		_ask_fishing("cancel",{"castId":_online_cast_id})
	game.cancel_cast()

func recover_from_water() -> void:
	_cancel_active_cast()
	splash_pending = false
	last_sounded_nibble = -1
	cast_audio.stop()
	plop_audio.stop()
	nibble_audio.stop()
	bite_audio.stop()
	_draw_line()
	_note("Back on solid ground.")


func tick(delta: float, show_avatar: bool) -> void:
	water_time += delta
	var was_biting: bool = game.phase() == "bite"
	var result: Dictionary = {}
	if _account == null:
		result = game.advance(delta)
	else:
		_sync_online_fishing(delta)
	if result.has("text") and not String(result.text).is_empty():
		_note(result.text)
	if not game.line.is_empty() and player.position.distance_to(cast_origin) > 3.1:
		_cancel_active_cast()
		_note("You reeled in as you walked away.")
	if splash_pending:
		if game.line.is_empty():
			splash_pending = false
		elif game.phase() != "casting":
			plop_audio.play()
			splash_pending = false
	var phase: String = game.phase()
	if phase == "nibble":
		var age: float = game.line.age
		for i: int in game.line.nibbles.size():
			var nibble_at: float = game.line.nibbles[i]
			if i > last_sounded_nibble and age >= nibble_at and age < nibble_at + 0.22:
				last_sounded_nibble = i
				nibble_audio.play()
	elif phase == "idle" and nibble_audio.playing:
		nibble_audio.stop()
	var biting := phase == "bite"
	if biting and not was_biting:
		bite_audio.play()
	elif not biting and bite_audio.playing:
		bite_audio.stop()
	var wave_gain := _wave_volume(player.global_position.z)
	wave_audio.volume_db = lerpf(wave_audio.volume_db,wave_gain,1.0 - exp(-4.0 * delta))
	_note_timer(delta)
	held_rod.visible = game.equipped and show_avatar and not actions_suspended
	cast_button.visible = game.equipped and not is_modal_open() and not actions_suspended
	put_away_button.visible = cast_button.visible
	if book_button != null:
		book_button.visible = not is_modal_open() and not actions_suspended
		book_button.disabled = not _fishing_pending.is_empty()
	cast_button.text = "Cast" if game.line.is_empty() else ("Casting..." if game.phase() == "casting" else "Reel in")
	if game.equipped and not actions_suspended:
		skeleton.set_bone_pose_rotation(arm_index,arm_pose)
		var arm := skeleton.get_bone_global_pose(arm_index)
		held_rod.global_position = skeleton.to_global(arm*Vector3(-0.14,-0.005,0))
		held_rod.global_basis = player.global_basis * Basis(Vector3.RIGHT,-0.89)
	_aim_timer -= delta
	if not cast_button.visible or not game.line.is_empty():
		aim_ring.hide()
	elif _aim_timer<=0.0:
		_aim_timer = .10
		var target := _aim_target(get_viewport().get_camera_3d())
		aim_ring.visible = target.is_finite()
		if aim_ring.visible:
			aim_ring.position = Vector3(target.x,WATER_Y+.018,target.z)
	_sync_shadows()
	_draw_line()

func _build_beach_audio() -> void:
	cast_audio = _audio_player("CastWhoosh",CAST_SOUND,-7.0)
	plop_audio = _audio_player("BobberPlop",LAND_SOUND,-9.0)
	nibble_audio = _audio_player("FishNibble",NIBBLE_SOUND,-8.0)
	bite_audio = _audio_player("FishBite",BITE_SOUND,-4.0)
	catch_audio = _audio_player("CatchSplash",CATCH_SOUND,-6.0)
	# Import owns the loop points. Load on the beach instead of preloading in every map.
	var waves := load(WAVE_PATH) as AudioStreamWAV
	wave_audio = _audio_player("BeachWaves",waves,_wave_volume(player.global_position.z))
	wave_audio.play()


func _audio_player(node_name: String, stream: AudioStream, volume: float) -> AudioStreamPlayer:
	# A stereo bed and close-up fishing sounds, all owned by this beach scene.
	var audio := AudioStreamPlayer.new()
	audio.name = node_name
	audio.stream = stream
	audio.volume_db = volume
	add_child(audio)
	return audio


func _wave_volume(player_z: float) -> float:
	var inland_distance := maxf(0.0,player_z - 1.0)
	return lerpf(-20.0,-39.0,smoothstep(0.0,30.0,inland_distance))


func _sync_shadows() -> void:
	var visible_ids := {}
	for fish in game.population:
		var id: int = fish.id
		visible_ids[id] = true
		if not shadow_nodes.has(id):
			var shape := Node3D.new()
			add_child(shape)
			var shade := Color("#23616b")
			shape.add_child(_shape(shade,Vector3(0.55,0.035,1.1)))
			var tail := _shape(shade,Vector3(0.22,0.025,0.44))
			shape.add_child(tail)
			tail.position.z = 0.43
			shadow_nodes[id] = {"body": shape, "tail": tail}
		var shadow: Dictionary = shadow_nodes[id]
		var pos: Vector3 = fish.position
		var direction: Vector3 = fish.heading
		var body: Node3D = shadow.body
		body.position = Vector3(pos.x,WATER_Y+0.025,pos.z)
		body.rotation.y = atan2(-direction.x,-direction.z)
		body.scale = Vector3.ONE * float(fish.size)
		shadow.tail.rotation.y = sin(water_time * 9.0 + id) * 0.24
	for id in shadow_nodes.keys():
		if not visible_ids.has(id):
			shadow_nodes[id].body.queue_free()
			shadow_nodes.erase(id)


func _build_water_effects() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.93
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	for i in 3:
		var ripple := MeshInstance3D.new()
		ripple.mesh = ring
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := _paint(Color("#c9f8ff"))
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ripple.material_override = material
		add_child(ripple)
		ripple.hide()
		ripples.append(ripple)
	for i in 5:
		var drop := _shape(Color("#d7faff"),Vector3(0.085,0.085,0.085))
		add_child(drop)
		drop.hide()
		droplets.append(drop)


func _draw_line() -> void:
	var mesh := fishing_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	bobber.visible = not game.line.is_empty()
	bite_cue.hide()
	for ripple: MeshInstance3D in ripples:
		ripple.hide()
	for drop: MeshInstance3D in droplets:
		drop.hide()
	if not bobber.visible:
		return
	var target: Vector3 = game.line.position
	target.y = WATER_Y + 0.14
	var phase: String = game.phase()
	var age: float = game.line.age
	var float_age := age - FISHING.CAST_FLIGHT
	var sag := 0.12
	if phase == "casting":
		var t := clampf(age / FISHING.CAST_FLIGHT,0.0,1.0)
		bobber.position = cast_tip.lerp(target,t)
		bobber.position.y += sin(t * PI) * _cast_arc_height(cast_tip,target)
		sag = 0.30 * sin(t * PI)
	else:
		bobber.position = target + Vector3(0.028 * sin(float_age * 5.0), 0.025 * sin(float_age * 7.0), 0.025 * cos(float_age * 4.0))
		var splash_age := float_age
		if not game.line.empty:
			for nibble: float in game.line.nibbles:
				if age >= nibble:
					splash_age = age - nibble
			if phase == "bite":
				splash_age = age - float(game.line.bite_at)
		var power := 1.0
		if phase == "nibble":
			bobber.position.y -= 0.09
			power = 0.48
		elif phase == "bite":
			bobber.position.y = WATER_Y - 0.16
			bite_cue.position = Vector3(target.x,WATER_Y+.38,target.z)
			bite_cue.show()
			power = 1.25
		_draw_water_effect(target,splash_age,power)
		if not ripples[0].visible and phase == "waiting":
			# A tiny persistent wake helps the player track the float on calm water.
			_draw_water_effect(target,fmod(float_age,1.7),0.30)

	var tip := to_local(held_rod.to_global(Vector3.UP*1.65))
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var t := float(i) / 12.0
		var point := tip.lerp(bobber.position,t)
		point.y -= sin(PI * t) * sag
		mesh.surface_add_vertex(point)
	mesh.surface_end()


func _draw_water_effect(target: Vector3, since: float, power: float) -> void:
	for i in ripples.size():
		var life := (since - i * 0.12) / 0.72
		if life < 0.0 or life >= 1.0:
			continue
		var ripple := ripples[i]
		var width := (0.11 + life * 1.35) * power
		ripple.position = Vector3(target.x,WATER_Y+0.025+i*0.006,target.z)
		ripple.scale = Vector3(width,0.10,width)
		var fade := (1.0 - life) * minf(0.8,power * 0.8)
		var material := ripple.material_override as StandardMaterial3D
		material.albedo_color = Color(0.78,0.97,1.0,fade)
		ripple.show()
	if power < 0.4 or since < 0.0 or since > 0.29:
		return
	var progress := since / 0.29
	for i in droplets.size():
		var angle := TAU * float(i) / droplets.size() + 0.3
		var drop := droplets[i]
		drop.position = Vector3(target.x,WATER_Y+0.06,target.z) + Vector3(
			cos(angle) * progress * 0.55, sin(PI * progress) * 0.43, sin(angle) * progress * 0.55) * power
		drop.show()


func _label(value: String, font: int) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font)
	label.add_theme_constant_override("outline_size",4)
	return label

func _build_hud(canvas: CanvasLayer) -> void:
	stats = _label("",17)
	canvas.add_child(stats)
	stats.position = Vector2(18,93)
	status = _label("",18)
	canvas.add_child(status)
	status.position = Vector2(18,121)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cast_button = Button.new()
	cast_button.text = "Cast"
	cast_button.focus_mode = Control.FOCUS_NONE
	cast_button.custom_minimum_size = Vector2(96,46)
	cast_button.pressed.connect(func(): click(get_viewport().get_camera_3d()))
	canvas.add_child(cast_button)
	cast_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,Control.PRESET_MODE_MINSIZE,16)
	cast_button.position.y -= 61
	put_away_button = Button.new()
	put_away_button.text = "Put Away"
	put_away_button.focus_mode = Control.FOCUS_NONE
	put_away_button.custom_minimum_size = Vector2(96,46)
	put_away_button.pressed.connect(put_away)
	canvas.add_child(put_away_button)
	put_away_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,Control.PRESET_MODE_MINSIZE,16)
	put_away_button.position.y -= 113
	put_away_button.hide()
	book_button = Button.new()
	book_button.name = "FishBookButton"
	book_button.text = "Fish Book"
	book_button.focus_mode = Control.FOCUS_NONE
	book_button.custom_minimum_size = Vector2(96,46)
	book_button.pressed.connect(open_photo_book)
	canvas.add_child(book_button)
	overlay = CenterContainer.new()
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_panel = PanelContainer.new()
	overlay.add_child(dialog_panel)

	dialog_padding = MarginContainer.new()
	for edge in ["left","right","top","bottom"]:
		dialog_padding.add_theme_constant_override("margin_"+edge,20)
	dialog_panel.add_child(dialog_padding)
	dialog_column = VBoxContainer.new()
	dialog_column.add_theme_constant_override("separation",10)
	dialog_padding.add_child(dialog_column)
	heading = _label("",25)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_column.add_child(heading)
	dialog = _label("",17)
	dialog.custom_minimum_size.x = 0
	dialog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_column.add_child(dialog)
	sale_cards = VBoxContainer.new()
	dialog_column.add_child(sale_cards)
	sale_total = _label("",21)
	dialog_column.add_child(sale_total)
	primary = Button.new()
	primary.custom_minimum_size.y = 46
	primary.pressed.connect(_confirm_or_close)
	dialog_column.add_child(primary)
	secondary = Button.new()
	secondary.text = "Not now"
	secondary.custom_minimum_size.y = 44
	secondary.pressed.connect(close_modal)
	dialog_column.add_child(secondary)
	photo_book = PHOTO_BOOK.new()
	canvas.add_child(photo_book)
	photo_book.closed.connect(close_modal)
	get_viewport().size_changed.connect(_resize_fishing_hud)
	_resize_fishing_hud()
	overlay.hide()

func _resize_fishing_hud() -> void:
	var view_size := get_viewport().get_visible_rect().size
	var camera := cast_button.get_parent().get_node_or_null("CameraThumbstick") as Control
	var s := HUD_FIT.touch_scale(get_viewport()) if camera != null and camera.visible else HUD_FIT.physical_scale(get_viewport())
	var narrow := view_size.x/s < 460.0
	var short := view_size.y/s < 455.0
	stats.position = Vector2(12,94)*s
	status.position = stats.position + Vector2(0,23)*s
	status.size.x = view_size.x-24.0*s
	stats.add_theme_font_size_override("font_size",roundi(17.0*s))
	status.add_theme_font_size_override("font_size",roundi(17.0*s))
	for cue: Button in [cast_button,put_away_button,book_button,primary,secondary]:
		cue.add_theme_font_size_override("font_size",roundi(16.0*s))
	HUD_FIT.right_button(cast_button,Vector2(96,46),58,s,true)
	HUD_FIT.right_button(put_away_button,Vector2(96,46),112,s,true)
	HUD_FIT.right_button(book_button,Vector2(96,46),166,s,true)
	if photo_book != null:
		photo_book.resize_book()
	dialog_panel.custom_minimum_size.x = clampf(view_size.x-20.0*s,180.0*s,(440.0 if short else 355.0)*s)
	for edge in ["left","right","top","bottom"]:
		dialog_padding.add_theme_constant_override("margin_"+edge,roundi((8.0 if short else (12.0 if narrow else 20.0))*s))
	dialog_column.add_theme_constant_override("separation",roundi((6.0 if short else 10.0)*s))
	heading.add_theme_font_size_override("font_size",roundi((22.0 if narrow else 25.0)*s))
	dialog.add_theme_font_size_override("font_size",roundi((16.0 if narrow or short else 17.0)*s))
	sale_total.add_theme_font_size_override("font_size",roundi(20.0*s))
	primary.custom_minimum_size.y = 46*s
	secondary.custom_minimum_size.y = 44*s
	var list := sale_cards.get_node_or_null("FishList") as ScrollContainer
	if list != null:
		list.custom_minimum_size.y = _sale_list_height()


func _sale_list_height() -> float:
	var s := HUD_FIT.physical_scale(get_viewport())
	var height := get_viewport().get_visible_rect().size.y/s
	return clampf(minf(height*.30,height-260.0),60.0,232.0)*s


func _show_dialog(title: String, body: String, sale: bool) -> void:
	for child in sale_cards.get_children():
		sale_cards.remove_child(child)
		child.queue_free()
	sale_mode = sale
	heading.text = title
	dialog.text = body
	primary.text = "Confirm Sale" if sale else "Done"
	primary.disabled = false
	secondary.disabled = false
	secondary.visible = sale
	sale_total.hide()
	overlay.show()
	primary.grab_focus()
	dialog_opened.emit()

func _fishing_book_tabs() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for fish: Dictionary in FISHING.CATALOG:
		var id := String(fish.id)
		entries.append({
			"id": id,
			"name": String(fish.name),
			"thumb": THUMB_PATH + id + ".png",
			"discovered": game.is_discovered(id),
		})
	return [{
		"id": "fishing",
		"label": "Fishing",
		"title": "Fishing Photo Book",
		"entries": entries,
	}]


func open_photo_book() -> void:
	if actions_suspended or is_modal_open() or photo_book == null or not _fishing_pending.is_empty():
		return
	if _account != null and not _account.admitted:
		_note("Sign in to view your saved Fish Book.")
		return
	photo_book.configure_tabs(_fishing_book_tabs())
	photo_book.open("fishing")
	dialog_opened.emit()


func close_modal() -> void:
	if is_instance_valid(_turning_actor):
		_turning_actor.rotation.y = _resting_yaw
	_turning_actor = null
	game.cancel_sale()
	overlay.hide()
	if photo_book != null:
		photo_book.hide()
	dialog_closed.emit()
	sale_mode = false

func _asset_preview(item: Dictionary, parent: Control, is_catch: bool = false) -> void:
	var s := HUD_FIT.physical_scale(get_viewport())
	var card: BoxContainer
	if is_catch:
		card = VBoxContainer.new()
	else:
		card = HBoxContainer.new()
	card.name = "FishCard"
	card.add_theme_constant_override("separation",10)
	parent.add_child(card)
	if not is_catch:
		var thumbnail := TextureRect.new()
		thumbnail.name = "SpeciesThumbnail"
		thumbnail.custom_minimum_size = Vector2(82,55)*s
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var thumb_path := THUMB_PATH + String(item.id) + ".png"
		if ResourceLoader.exists(thumb_path):
			thumbnail.texture = load(thumb_path) as Texture2D
		card.add_child(thumbnail)
	var preview_size := Vector2i(210,140)
	if get_viewport().get_visible_rect().size.y/s < 380.0:
		preview_size = Vector2i(144,75)
	var model_path := PREVIEW_PATH + String(item.get("model","")).get_file()
	if is_catch and ResourceLoader.exists(model_path):
		var container := SubViewportContainer.new()
		container.custom_minimum_size = Vector2(preview_size)*s
		container.stretch = true
		container.stretch_shrink = maxi(1,roundi(s))
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = preview_size
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		container.add_child(viewport)
		var model := (load(model_path) as PackedScene).instantiate() as Node3D
		viewport.add_child(model)
		var bounds := AABB()
		var found_bounds := false
		for node in model.find_children("*","MeshInstance3D",true,false):
			var piece := node as MeshInstance3D
			var piece_bounds := piece.global_transform * piece.get_aabb()
			bounds = bounds.merge(piece_bounds) if found_bounds else piece_bounds
			found_bounds = true
		if bounds.size.length() > 0.001:
			var scale_factor := 1.65 / maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
			model.scale *= scale_factor
			model.position = -bounds.get_center() * scale_factor
		var cam := Camera3D.new()
		viewport.add_child(cam)
		cam.position = Vector3(1.65,0.65,1.65)
		cam.look_at(Vector3.ZERO)
		cam.make_current()
		var light := DirectionalLight3D.new()
		viewport.add_child(light)
		light.rotation_degrees = Vector3(-35,35,0)
		var fill := DirectionalLight3D.new()
		viewport.add_child(fill)
		fill.light_energy = .45
		fill.rotation_degrees = Vector3(-25,-120,0)
	var details := VBoxContainer.new()
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(details)
	var count: int = item.get("count",1)
	var caption: String = item.name if count == 1 else "%s Ã— %d" % [item.name,count]
	var names := _label(caption,roundi((21.0 if is_catch else 17.0)*s))
	names.name = "FishName"
	names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(names)
	var value_text := _stars_text(item.value)
	if count > 1:
		value_text += " each"
	var value := _label(value_text,roundi((18.0 if is_catch else 16.0)*s))
	value.name = "FishValue"
	value.modulate = Color("#fff1aa")
	details.add_child(value)
	if is_catch:
		names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _stars_text(value: int) -> String:
	return "%d %s" % [value,"star" if value == 1 else "stars"]


func _show_catch(item: Dictionary, new_discovery: bool = false) -> void:
	var note := "New species added to your Fish Book! Saved in your fish bag." if new_discovery else "Saved in your fish bag. You can sell it to Marina at the snack shop."
	_show_dialog("You caught a fish!",note,false)
	primary.text = "Keep Fishing"
	_asset_preview(item,sale_cards,true)


func _show_sale() -> void:
	if _account != null:
		_ask_fishing("quote")
		return
	var quote: Dictionary = game.sale_preview()
	if not quote.get("ok",false):
		_show_dialog("Marina",quote.get("text","Come back when you have fish to sell."),false)
		return
	_show_sale_quote(quote)

func _show_sale_quote(quote: Dictionary) -> void:
	_show_dialog("Marina's Snack Shop","Review your catch. You keep your fish until you confirm the sale." if not session_only or _account != null else "Fishing rewards last for this session only. You keep your fish until you confirm.",true)
	var scroll := ScrollContainer.new()
	scroll.name = "FishList"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.custom_minimum_size.y = _sale_list_height()
	sale_cards.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Items"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",9)
	scroll.add_child(list)
	var grouped: Dictionary = {}
	# Show duplicates as a quantity so the 500-fish bag needs at most 35 previews.
	for item: Dictionary in quote.items:
		var id: String = item.id
		if grouped.has(id):
			grouped[id].count += 1
		else:
			grouped[id] = item.duplicate()
			grouped[id].count = 1
	for item: Dictionary in grouped.values():
		_asset_preview(item,list)
	sale_total.text = "Total: %s" % _stars_text(quote.total)
	sale_total.show()
	# Start on the list, not the sale button, so an incidental Enter doesn't sell.
	scroll.grab_focus()


func _confirm_or_close() -> void:
	if sale_mode:
		if _account != null:
			if not _sale_quote_id.is_empty() and _ask_fishing("sell",{"quoteId":_sale_quote_id}):
				primary.disabled = true
				secondary.disabled = true
				dialog.text = "Saving your sale..."
			return
		var result: Dictionary = game.confirm_sale()
		var sold: bool = result.get("ok",false)
		_update_stats()
		_show_dialog("Sale Complete" if sold else "Sale Not Completed",
			result.get("text","Please ask Marina for a fresh offer."),false)
		primary.text = "Back to the Beach" if sold else "Close"
		return
	close_modal()

func _update_stats() -> void:
	var template := "Fish: %d    Saved Stars: %d" if _account != null else ("Fish: %d    Temporary Stars: %d" if session_only else "Fish: %d    Stars: %d")
	stats.text = template % [game.inventory.size(),game.stars]

func _note(text: String) -> void:
	status.text = text
	note_time = 4.5

func _note_timer(delta: float) -> void:
	if note_time <= 0.0:
		return
	note_time -= delta
	if note_time <= 0.0:
		status.text = ""
