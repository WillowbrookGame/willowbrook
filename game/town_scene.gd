extends "res://game/map.gd"
## Town owns its layout, home exteriors, progression and vehicle mounts.

const TOWN_LAYOUT = preload("res://game/town_layout.gd")


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
