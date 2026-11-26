extends "res://game/map.gd"
## Town owns its layout, home exteriors, progression and vehicle mounts.

const ARENA := "res://game/arena.tscn"
const TOWN_LAYOUT = preload("res://game/town_layout.gd")


var paintball_lobby_view: Node


func _sync_town_home_exteriors() -> void:
	var town_layout := get_node_or_null("TownLayout")
	if town_layout == null:
		return
	var rows: Array = []
	var account := _pets_account()
	if OS.has_feature("web") and account != null and account.pets_available():
		rows = account.town_home_exteriors()
	else:
		var own: Variant = profile_snapshot().get("home")
		if own is Dictionary and own.get("variant") in ["cottage","family"]:
			rows.append({"plot": own.get("plot",-1),"variant":own.variant})
	if rows != _home_exterior_rows:
		_home_exterior_rows = rows.duplicate(true)
		town_layout.set_home_exteriors(rows)

func _build_town() -> void:
	door_position = TOWN_LAYOUT.ARENA_DOOR
	var town := $TownLayout
	playground.bind_layout(town)
	_sync_town_home_exteriors()


func _build_town_features(hud: CanvasLayer) -> void:
	var progression_path := "res://game/progression/town_progression.gd"
	if ResourceLoader.exists(progression_path):
		town_progress = load(progression_path).new()
		town_progress.name = "TownProgression"
		add_child(town_progress)
		town_progress.setup(self,player,hud)
	var home_path := "res://game/progression/home_lot.gd"
	if ResourceLoader.exists(home_path):
		home_lot = load(home_path).new()
		home_lot.name = "HomeLot"
		add_child(home_lot)
		home_lot.setup(self,player,hud,TOWN_LAYOUT.HOME_DOORS)
	var vehicle_path := "res://game/vehicles/town_vehicles.gd"
	if ResourceLoader.exists(vehicle_path):
		vehicles = load(vehicle_path).new()
		vehicles.name = "TownVehicles"
		add_child(vehicles)
		vehicles.setup(self,player,arena_avatar,hud)
		vehicles.dialog_opened.connect(_on_beach_dialog_opened)
		vehicles.dialog_closed.connect(_on_beach_dialog_closed)


func _setup_zone_player() -> void:
	if get_tree().has_meta("paintball_town_return"):
		get_tree().remove_meta("paintball_town_return")
		player.position = TOWN_ROUTES.ARENA_DOOR + Vector3(0,0.04,1.6)
		look_yaw = PI
		player.rotation.y = look_yaw


func _try_door() -> void:
	if changing or not _near_door():
		return
	var account := get_node_or_null("/root/WillowbrookBrowserSession") if OS.has_feature("web") else null
	if account != null and account.has_method("can_show_paintball_lobby") and account.admitted and account.zone=="town":
		if paintball_lobby_view == null:
			var panel_script := load("res://game/network/paintball/online_paintball_view.gd") as Script
			paintball_lobby_view = panel_script.new()
			add_child(paintball_lobby_view)
			paintball_lobby_view.setup(self,get_node("WorldHUD"),account,false)
		paintball_lobby_view.open_lobby()
		return
	_enter_solo_paintball()

func _enter_solo_paintball() -> void:
	if changing or not _near_door(): return
	changing = true
	var tree := get_tree()
	var result := tree.change_scene_to_file(ARENA)
	if result == OK and not tree.has_meta("paintball_practice_test"):
		tree.set_meta("paintball_single_player",true)
	if result != OK:
		changing = false
		push_error("Couldn't load the destination map: %s" % error_string(result))
