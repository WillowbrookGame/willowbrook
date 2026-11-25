extends "res://game/interiors/room.gd"

const CAFE_ART := preload("res://game/cafe/room_art.gd")
const CLERK_PROMPT := "Talk to the barista"

func _room_title(key: String) -> String:
	return "Sunny Cafe" if key == "cafe" else ""

func _new_room_art() -> ART:
	return CAFE_ART.new()

func _fallback_seats() -> Array:
	return [Vector3(-3.65,0,3.6),Vector3(3.65,0,3.6)]

func _publishes_sitting() -> bool:
	return true

func _desk() -> Vector3:
	return Vector3(4.5,0,-3.7)

func _clerk_prompt() -> String:
	return CLERK_PROMPT

func _interact_room_specific(prompt: String) -> bool:
	if prompt != CLERK_PROMPT: return false
	_work_menu()
	return true
