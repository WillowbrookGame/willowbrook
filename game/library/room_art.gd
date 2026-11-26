extends "res://game/interiors/room_art.gd"

# The saved scene owns scenery, collision and the librarian's placement.
func build(_id: String, _profile: Dictionary) -> void:
	conversation_actor = $Librarian
	var animations := conversation_actor.find_children("*", "AnimationPlayer", true, false)
	if not animations.is_empty():
		var player := animations[0] as AnimationPlayer
		if player.has_animation("idle"):
			player.play("idle")
