extends "res://game/interiors/room.gd"

const HOME_ART := preload("res://game/home/room_art.gd")

func _new_room_art() -> ART:
	return HOME_ART.new()

func spawn_position() -> Vector3:
	return Vector3(0,.04,3.5)

func bounds() -> Vector2:
	return Vector2(30,5.12)

func _near_exit() -> bool:
	return absf(player.position.x)<1.25 and player.position.z>=4.0
