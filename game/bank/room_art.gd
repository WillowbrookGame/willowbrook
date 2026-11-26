extends "res://game/interiors/room_art.gd"

# The saved layout owns placement and collision. Keep live behavior here.
func build(_id: String, _profile: Dictionary) -> void:
	_register_public_seat($WaitingChairNear, 1.18)
	_register_public_seat($WaitingChairFar, 1.18)
	conversation_actor = $Teller
	var animations := conversation_actor.find_children("*", "AnimationPlayer", true, false)
	if not animations.is_empty():
		var player := animations[0] as AnimationPlayer
		if player.has_animation("idle"):
			player.play("idle")
