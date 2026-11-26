extends "res://game/interiors/room_art.gd"

const CHAIR_HEIGHT := 1.05

func build(_id: String, _profile: Dictionary) -> void:
	for chair_name in ["BackLeftOuterChair","BackLeftInnerChair","FrontLeftOuterChair","FrontLeftInnerChair","BackRightInnerChair","BackRightOuterChair","FrontRightInnerChair","FrontRightOuterChair"]:
		_register_public_seat(get_node(chair_name) as Node3D,CHAIR_HEIGHT)
	conversation_actor = $Barista
	var animations := conversation_actor.find_children("*","AnimationPlayer",true,false)
	if not animations.is_empty():
		var player := animations[0] as AnimationPlayer
		if player.has_animation("idle"):
			player.play("idle")
