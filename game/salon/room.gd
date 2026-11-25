extends "res://game/interiors/room.gd"

const SALON_ART := preload("res://game/salon/room_art.gd")
const CLERK_PROMPT := "Talk to the stylist"

func _room_title(key: String) -> String:
	return "Beauty Salon" if key == "salon" else ""

func _new_room_art() -> ART:
	return SALON_ART.new()

func _fallback_seats() -> Array:
	return [Vector3(-5,0,3.3),Vector3(5,0,3.3)]

func _publishes_sitting() -> bool:
	return true

func _desk() -> Vector3:
	return Vector3(0,0,-3.5)

func _clerk_prompt() -> String:
	return CLERK_PROMPT

func _interact_room_specific(prompt: String) -> bool:
	if prompt != CLERK_PROMPT: return false
	_work_menu()
	return true

func _near_clerk() -> bool:
	var actor := art.conversation_actor
	if not is_instance_valid(actor):
		return false
	var at := player.global_position
	var npc_at := actor.global_position
	# Remain on the public side of the desk. Eye-level sight crosses low counters,
	# but not partitions, cabinets, or walls.
	if at.z <= npc_at.z + .45:
		return false
	# The tall Salon reception desk blocks a direct ray to the stylist.
	# The customer aisle can talk across it; keep the rest of the sight checks.
	if absf(at.x) <= 1.6 and at.z >= -4.24 and at.z <= -1.8:
		return PROX.visible_from(self,at,npc_at,4.3,Vector3(0,0,-4.24),[player.get_rid()])
	return PROX.visible_from(self,at,npc_at,4.3,npc_at,[player.get_rid()])
