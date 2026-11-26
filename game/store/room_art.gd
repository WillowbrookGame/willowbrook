extends "res://game/interiors/room_art.gd"

# The authored scene owns the fixed layout and collisions. Job state and
# highlights remain runtime behavior, as do the shopkeeper's animations.
func build(_id: String, _profile: Dictionary) -> void:
	conversation_actor = $Shopkeeper
	var animations := conversation_actor.find_children("*", "AnimationPlayer", true, false)
	if not animations.is_empty():
		var player := animations[0] as AnimationPlayer
		if player.has_animation("idle"):
			player.play("idle")
