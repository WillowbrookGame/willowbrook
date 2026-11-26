extends "res://game/interiors/room_art.gd"

const WAITING_CHAIR_HEIGHT := 1.30

func build(_id: String, _profile: Dictionary) -> void:
	_register_public_seat($LeftWaitingChair,WAITING_CHAIR_HEIGHT)
	_register_public_seat($RightWaitingChair,WAITING_CHAIR_HEIGHT)
	conversation_actor = $Stylist
	_play_idle(conversation_actor)
	_play_idle($JobStations/StationBrushClient/Customer)

func _play_idle(actor: Node3D) -> void:
	var animations := actor.find_children("*","AnimationPlayer",true,false)
	if not animations.is_empty():
		var player := animations[0] as AnimationPlayer
		if player.has_animation("idle"):
			player.play("idle")
