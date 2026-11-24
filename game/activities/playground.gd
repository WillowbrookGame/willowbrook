extends RefCounted
## Original Willowbrook glide path and timing, anchored to the actual imported
## Tiny Treats meshes instead of independently estimated world transforms.
const ENTRIES := {
	"swing-0":Vector3(51,0,49.8),
	"slide":Vector3(43.15,0,45.1),
	"seesaw-0":Vector3(42.5,0,53.55),
	"seesaw-1":Vector3(42.5,0,56.45)
}
const LABELS := {"swing-0":"swing","slide":"slide","seesaw-0":"seesaw","seesaw-1":"seesaw"}
const SLIDE_SECONDS := 4.6
const SLIDE_CLIMB := 0.425
const SWING_BACK_ENTRY := Vector3(51,0,44.2)
# Height samples measured on the imported Tiny Treats chute.
# Each point is time fraction, local deck height, local z.
const SLIDE_PATH := [
	Vector3(0,0,-1.2),Vector3(.30,2.30,-.85),Vector3(.425,2.30,.88),
	Vector3(.46,2.00,1.35),Vector3(.535,1.79,1.90),Vector3(.610,1.33,2.45),
	Vector3(.686,.84,3.0),Vector3(.720,.68,3.25),Vector3(.847,.54,3.70),
	Vector3(.932,.27,4.00),Vector3(1,.1,4.24)
]
const SLIDE_SURFACE_X := 0.0
const SWING_SEAT := Vector3(0,-2.97,0) # actual top face of board
const SEESAW_SEAT_HEIGHT := .15
const SEESAW_SEAT_LENGTH := 1.7
# Kenney sit shifts root down .15; neutral hip pivot is .17625 high
# and .02875 back. Apply the contact correction in the tilted seat frame.
const SIT_CONTACT := Vector3(0,.02625,-.02875)
const PELVIS_CLEARANCE := .075

var ride := ""
var age := 0.0
var swing_pin: Node3D
var seesaw_pin: Node3D
var slide_asset: Node3D
var swing_rest_pitch := 0.0
var seesaw_rest_pitch := 0.0
var _avatar_defaults: Dictionary = {}
var _exit_approach := Vector3.ZERO


func bind_layout(town: Node3D) -> void:
	swing_pin = town.find_child("swing_A_small_seat",true,false) as Node3D
	seesaw_pin = town.find_child("seesaw_small_seat",true,false) as Node3D
	slide_asset = town.find_child("slide_A",true,false) as Node3D
	if is_instance_valid(swing_pin):
		swing_rest_pitch = swing_pin.rotation.x
	if is_instance_valid(seesaw_pin):
		seesaw_rest_pitch = seesaw_pin.rotation.x


func nearby(at: Vector3) -> String:
	var best := 1.95
	var target := ""
	if absf(at.y) > 0.8:
		return target
	for id: String in ENTRIES:
		var anchor: Vector3 = ENTRIES[id]
		var distance := Vector2(at.x-anchor.x,at.z-anchor.z).length()
		if id == "swing-0":
			distance = minf(distance,Vector2(at.x-SWING_BACK_ENTRY.x,at.z-SWING_BACK_ENTRY.z).length())
		if distance < best:
			target = id
			best = distance
	return target


func prompt(at: Vector3) -> String:
	if ride == "slide":
		return ""
	if not ride.is_empty():
		return "Get off the "+LABELS[ride]
	var id := nearby(at)
	return "Ride the "+LABELS[id] if not id.is_empty() else ""


func begin(id: String, from := Vector3.INF) -> void:
	ride = "swing-0" if id == "swing" else (id if ENTRIES.has(id) else "")
	age = 0.0
	_exit_approach = ENTRIES.get(ride,Vector3.ZERO)
	if ride == "swing-0" and from.is_finite() and from.z < (SWING_BACK_ENTRY.z+_exit_approach.z)*.5:
		_exit_approach = SWING_BACK_ENTRY
	_apply_equipment()


func tick(delta: float) -> void:
	if ride.is_empty() or not is_finite(delta) or delta <= 0.0:
		return
	age += delta
	_apply_equipment()


func motion_angle() -> float:
	match ride:
		"swing-0":
			return .4*sin(age*1.65)*minf(age/1.5,1.0)
		"seesaw-0","seesaw-1":
			return .2*sin(age*1.5)
	return 0.0


func _apply_equipment() -> void:
	if is_instance_valid(swing_pin):
		swing_pin.rotation.x = swing_rest_pitch + (motion_angle() if ride == "swing-0" else 0.0)
	if is_instance_valid(seesaw_pin):
		seesaw_pin.rotation.x = seesaw_rest_pitch + (motion_angle() if ride.begins_with("seesaw") else 0.0)


func pose() -> Vector3:
	match ride:
		"swing-0":
			if is_instance_valid(swing_pin):
				return swing_pin.to_global(SWING_SEAT)
		"seesaw-0","seesaw-1":
			if is_instance_valid(seesaw_pin):
				return seesaw_pin.to_global(Vector3(0,SEESAW_SEAT_HEIGHT,SEESAW_SEAT_LENGTH*_side()))
		"slide":
			var u := clampf(age/SLIDE_SECONDS,0.0,1.0)
			for i in range(1,SLIDE_PATH.size()):
				var a: Vector3 = SLIDE_PATH[i-1]
				var b: Vector3 = SLIDE_PATH[i]
				if u <= b.x:
					var point := a.lerp(b,inverse_lerp(a.x,b.x,u))
					var local := Vector3(SLIDE_SURFACE_X,point.y,point.z)
					if is_instance_valid(slide_asset):
						return slide_asset.to_global(local)
					var ratio := 5.0/5.910692930221558
					return Vector3(43.0,.12,48.5)+(local+Vector3(.1806211471557615,0,-1.3941117525100708))*ratio
	return exit_position()


func animation_name() -> String:
	return "walk" if ride == "slide" and age < SLIDE_SECONDS*SLIDE_CLIMB else "sit"


func is_finished() -> bool:
	return ride == "slide" and age >= SLIDE_SECONDS


func _side() -> float:
	return 1.0 if ride == "seesaw-1" else -1.0


func apply_avatar(avatar: Node3D) -> void:
	if ride.is_empty() or not is_instance_valid(avatar):
		return
	if _avatar_defaults.is_empty():
		_avatar_defaults = {"position":avatar.position,"rotation":avatar.rotation}
	var parent := avatar.get_parent() as Node3D
	var world_yaw := PI if ride == "seesaw-1" else 0.0
	var world_pitch := motion_angle()
	if ride == "seesaw-1":
		world_pitch *= -1.0
	if ride == "slide" and animation_name() == "sit":
		var u := clampf(age/SLIDE_SECONDS,SLIDE_CLIMB,1.0)
		var a := slide_point(maxf(SLIDE_CLIMB,u-.018))
		var b := slide_point(minf(1.0,u+.018))
		world_pitch = clampf(atan2(a.y-b.y,maxf(.001,b.z-a.z))*.77,0.0,.67)
	var yaw := wrapf(world_yaw-parent.global_rotation.y,-PI,PI)
	if animation_name() == "sit":
		apply_seat_avatar(avatar,_avatar_defaults.position,yaw,world_pitch)
	else:
		avatar.position = _avatar_defaults.position
		avatar.rotation = Vector3(0,yaw,0)


static func apply_seat_avatar(avatar: Node3D, neutral: Vector3, yaw: float, pitch: float) -> void:
	avatar.rotation = Vector3(pitch,yaw,0)
	avatar.position = neutral + Basis.from_euler(avatar.rotation)*(Vector3.UP*PELVIS_CLEARANCE-SIT_CONTACT*avatar.scale)


static func slide_point(u: float) -> Vector3:
	for i in range(1,SLIDE_PATH.size()):
		var a: Vector3 = SLIDE_PATH[i-1]
		var b: Vector3 = SLIDE_PATH[i]
		if u <= b.x:
			return a.lerp(b,inverse_lerp(a.x,b.x,u))
	return SLIDE_PATH.back()


func exit_position() -> Vector3:
	return Vector3(43,.05,52.1) if ride == "slide" else _exit_approach+Vector3.UP*.05


func end(avatar: Node3D = null) -> void:
	ride = ""
	age = 0.0
	_apply_equipment()
	if not _avatar_defaults.is_empty() and is_instance_valid(avatar):
		avatar.position = _avatar_defaults.position
		avatar.rotation = _avatar_defaults.rotation
	_avatar_defaults.clear()
