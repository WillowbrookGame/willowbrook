extends "res://game/interiors/room_art.gd"

const LAYOUTS := {
	"starter": preload("res://game/home/layout_starter.tscn"),
	"cottage": preload("res://game/home/layout_cottage.tscn"),
	"family": preload("res://game/home/layout_family.tscn"),
}

func build(_id: String, profile: Dictionary) -> void:
	var variant := String(profile.get("home", {}).get("variant", "starter"))
	var layout: PackedScene = LAYOUTS.get(variant, LAYOUTS.starter)
	var shell := layout.instantiate() as Node3D
	shell.name = "Layout"
	add_child(shell)
	decor = Node3D.new()
	decor.name = "Furniture"
	add_child(decor)
	redraw_decor(profile)
