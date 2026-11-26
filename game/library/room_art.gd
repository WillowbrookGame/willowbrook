extends "res://game/interiors/room_art.gd"

const READING_CHAIR_HEIGHT := 1.30

# The saved scene owns scenery, collision and the librarian's placement.
func build(_id: String, _profile: Dictionary) -> void:
	_register_public_seat($LeftReadingChair, READING_CHAIR_HEIGHT)
	_register_public_seat($RightReadingChair, READING_CHAIR_HEIGHT)
	conversation_actor = $Librarian
	var animations := conversation_actor.find_children("*", "AnimationPlayer", true, false)
	if not animations.is_empty():
		var player := animations[0] as AnimationPlayer
		if player.has_animation("idle"):
			player.play("idle")
