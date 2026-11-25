extends RefCounted
## Island-only recovery and slide behavior. The shared map owns input and camera order.

const PLAYER = preload("res://game/player.gd")
const BEACH_LAYOUT = preload("res://game/beach_layout.gd")
const BEACH_RECOVERY = preload("res://game/beach_recovery.gd")
const PLAYGROUND = preload("res://game/activities/playground.gd")

var recovery := BEACH_RECOVERY.new()
var slide_time := -1.0
var _slide_avatar := Transform3D.IDENTITY


func recover(player: PLAYER, fishing_ui: Node3D, delta: float, zone_modal: bool) -> bool:
	if not recovery.tick(player,delta,not is_sliding() and not zone_modal):
		return false
	if fishing_ui != null:
		fishing_ui.recover_from_water()
	return true


func is_sliding() -> bool:
	return slide_time >= 0.0


func is_seated() -> bool:
	return BEACH_LAYOUT.slide_is_seated(slide_time)


func begin_slide(player: PLAYER, arena_avatar: Node3D, fishing_ui: Node3D) -> void:
	slide_time = 0.0
	_slide_avatar = arena_avatar.transform
	player.jump_buffer = 0.0
	fishing_ui.set_actions_suspended(true)
	player.position = BEACH_LAYOUT.slide_pose(0.0)
	player.set_physics_process(false)
	player.held.clear()
	player.velocity = Vector3.ZERO


func tick_slide(player: PLAYER, arena_avatar: Node3D, fishing_ui: Node3D, delta: float) -> void:
	if slide_time >= 0.0:
		slide_time += delta
		player.position = BEACH_LAYOUT.slide_pose(slide_time)
		if BEACH_LAYOUT.slide_is_seated(slide_time):
			PLAYGROUND.apply_seat_avatar(arena_avatar,_slide_avatar.origin,wrapf(-player.global_rotation.y,-PI,PI),BEACH_LAYOUT.slide_pitch(slide_time))
		else:
			arena_avatar.transform = _slide_avatar
		if slide_time >= BEACH_LAYOUT.SLIDE_SECONDS:
			slide_time = -1.0
			player.velocity = Vector3.ZERO
			player.jump_buffer = 0.0
			player.held.clear()
			if fishing_ui != null:
				fishing_ui.set_actions_suspended(false)
			player.set_physics_process(true)
