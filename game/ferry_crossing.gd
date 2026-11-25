extends RefCounted
## Local ferry presentation shared by both landings; the world owns scene changes.

const PLAYER = preload("res://game/player.gd")
const FERRY = preload("res://game/ferry_landing.gd")

var card: ColorRect
var landing: FERRY
var points: Array[Vector3] = []
var segment := 0
var clock := 0.0
var foot := Vector3.ZERO
var previous_avatar := Transform3D.IDENTITY
var previous_motion_lock := false
const FERRY_WALK_MPS := 3.6
const FERRY_SAIL_SECONDS := 1.80

func begin(dock: FERRY, player: PLAYER, arena_avatar: Node3D) -> void:
	landing = dock
	previous_avatar = arena_avatar.transform
	previous_motion_lock = player.movement_locked
	points = landing.boarding_points()
	segment = 0
	clock = 0.0
	foot = player.global_position


func tick(delta: float, arena_avatar: Node3D, arena_animation: AnimationPlayer, camera: Camera3D, hud: Node, destination: String) -> bool:
	# Only the local visual moves. Keep the physical/network player at the
	# dock until the normal scene change, rather than broadcasting water poses.
	var body_yaw := PI
	var clip := "idle"
	if segment < points.size():
		var target := points[segment]
		var forward := target - foot
		if Vector2(forward.x,forward.z).length_squared() > .001:
			body_yaw = atan2(-forward.x,-forward.z)
		foot = foot.move_toward(target,FERRY_WALK_MPS * delta)
		if foot.is_equal_approx(target):
			segment += 1
		clip = "walk"
	else:
		clock += delta
		# A short beat fully aboard before motion makes the departure legible.
		landing.sail(clampf((clock-.28)/FERRY_SAIL_SECONDS,0.0,1.0))
		foot = landing.deck_position()
		if clock >= 1.52 and not is_instance_valid(card):
			card = FERRY.sailing_card(hud,destination)
		if clock >= .28+FERRY_SAIL_SECONDS+.24:
			return true
	var rotation := Basis(Vector3.UP,body_yaw) * previous_avatar.basis
	var pose := Transform3D(rotation,foot+previous_avatar.origin)
	arena_avatar.global_transform = arena_avatar.global_transform.interpolate_with(pose,minf(delta*18.0,1.0)) if clip == "walk" else pose
	if arena_animation.current_animation != clip:
		arena_animation.play(clip,.11)
	arena_animation.advance(delta)
	arena_avatar.show()
	var pivot := foot + Vector3(.65,1.50,1.04)
	var arm := Vector3(-4.45,4.40,-7.35)
	# The crossing camera follows an authored elevated route above the dock.
	# The player-only invisible shore rail must not shorten this boom.
	var shot := Transform3D(Basis.IDENTITY,pivot+arm).looking_at(pivot)
	camera.global_transform = camera.global_transform.interpolate_with(shot,1.0-exp(-6.2*delta))
	return false


func restore_pose(player: PLAYER, arena_avatar: Node3D) -> void:
	player.movement_locked = previous_motion_lock
	landing.sail(0.0)
	landing = null
	arena_avatar.transform = previous_avatar


func dismiss_card() -> void:
	if is_instance_valid(card):
		card.queue_free()
	card = null
