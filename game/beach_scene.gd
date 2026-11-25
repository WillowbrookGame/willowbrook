extends "res://game/map.gd"
## Owns island-only scene resources while keeping shared player and route wiring.

const ISLAND_LAYOUT = preload("res://game/beach_layout.gd")
const ISLAND_ACTIVITIES = preload("res://game/beach_activities.gd")
const ISLAND_FISHING = preload("res://game/beach_fishing_ui.gd")


func _build_beach() -> void:
	beach_activities = ISLAND_ACTIVITIES.new()
	beach_scenery = ISLAND_LAYOUT.new()
	beach_scenery.name = "BeachLayout"
	add_child(beach_scenery)
	door_position = ISLAND_LAYOUT.TOWN_DOOR


func _beach_spawn() -> Vector3:
	return ISLAND_LAYOUT.SPAWN


func _build_beach_fishing(hud: CanvasLayer) -> void:
	fishing_ui = ISLAND_FISHING.new()
	fishing_ui.name = "BeachFishing"
	add_child(fishing_ui)
	fishing_ui.setup(player,beach_scenery,hud,arena_avatar,arena_animation,profile)
	fishing_ui.dialog_opened.connect(_on_beach_dialog_opened)
	fishing_ui.dialog_closed.connect(_on_beach_dialog_closed)
