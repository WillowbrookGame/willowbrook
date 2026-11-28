extends RefCounted
## Skyhill wire limits and collision-free remote presentation.
const ZONE := "skyhill"
# The lift tops out at y=35; leave room for momentum. The course recovers at y=-1.5.
const MIN_Y := -4.0
const MAX_Y := 42.0
const MAX_PITCH := 0.7
const MAX_BANK := 1.6
const AVATARS := preload("res://game/avatars/catalog.gd")
const GLIDER := "res://game/skyhill/glider_view.tscn"
const SIT_OFFSET := Vector3(0, -0.02625, 0.02875) * 2.5

static func valid_glide(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for index in 2:
		var part: Variant = value[index]
		if not (part is float or part is int) or not is_finite(float(part)) or absf(float(part)) > (MAX_PITCH if index == 0 else MAX_BANK):
			return false
	return true

static func allows_seat(at: Vector3) -> bool:
	return absf(at.x) <= 6.25 and at.y >= 23.0 and at.y <= 24.2 and at.z >= 10.5 and at.z <= 21.5

static func make_view(root: Node3D, character: String, label: Label3D) -> Dictionary:
	var walker := AVATARS.instantiate(character)
	root.add_child(walker)
	walker.scale = Vector3.ONE * 2.5
	var glider := (load(GLIDER) as PackedScene).instantiate() as Node3D
	root.add_child(glider)
	glider.get_node("RiderAnchor").add_child(AVATARS.instantiate(character))
	glider.hide()
	for mesh in root.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"walker":walker,"glider":glider,"label":label,"animation":AVATARS.animator(walker),"flying":false}

static func update_view(view: Dictionary, row: Dictionary, delta: float, snap: bool) -> void:
	var glide: Variant = row.get("glide")
	var flying := valid_glide(glide)
	view.flying = flying
	view.walker.visible = not flying
	view.glider.visible = flying
	view.label.position.y = 1.75 if flying else (1.55 if row.get("rest") == "sit" else 2.12)
	if flying:
		var rotation: Vector3 = view.glider.rotation
		var weight := 1.0 if snap else 1.0 - exp(-18.0 * delta)
		view.glider.rotation = Vector3(lerp_angle(rotation.x,float(glide[0]),weight),0.0,lerp_angle(rotation.z,float(glide[1]),weight))
		return
	var sitting: bool = row.get("rest") == "sit"
	view.walker.position = SIT_OFFSET if sitting else Vector3.ZERO
	var animation: AnimationPlayer = view.animation
	var clip := "sit" if sitting else ("walk" if row.moving else "idle")
	if animation.current_animation != clip and animation.has_animation(clip):
		if not sitting:
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		animation.play(clip, 0.0 if snap or sitting else .1)
