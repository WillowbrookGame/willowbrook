extends RefCounted
## Shared visual-only stance for the Town kick scooter. The rider/collision
## capsule and the authoritative seat pose do not change.
const DECK_CENTER := Vector3(0,.22,.10)
const DECK_SIZE := Vector3(.47,.09,.86)
const BODY_WORLD_Y := .08
const HANDLE := Vector3(0,1.04,-.48)
const STAND := Vector3(0,DECK_CENTER.y+DECK_SIZE.y*.5,-.16)
const GRIP_HALF_WIDTH := .226
const RIG := &"scooter_rig"
const ACTIVE := &"scooter_standing"
const ARMS := ["arm-left","arm-right"]
const LEGS := ["leg-left","leg-right"]

static func _rig(model: Node3D) -> Skeleton3D:
	var cached: Variant = model.get_meta(RIG) if model.has_meta(RIG) else null
	if is_instance_valid(cached): return cached as Skeleton3D
	var found := model.find_children("*","Skeleton3D",true,false)
	if found.is_empty(): return null
	var skeleton := found.front() as Skeleton3D
	model.set_meta(RIG,skeleton)
	return skeleton

static func present(model: Node3D, rider_origin: Vector3) -> void:
	model.global_position = rider_origin
	# The grip and deck are rigid in scooter space. Solve the skeleton
	# once on mount; each following tick only attaches the model.
	if model.has_meta(ACTIVE): return
	model.set_meta(ACTIVE,true)
	var rig := _rig(model)
	if rig == null: return
	# Kenney Mini uses rigid one-bone limbs on all selectable presets.
	# Narrow the boot stance slightly and point each open hand toward the bar.
	for name: String in LEGS:
		var idx := rig.find_bone(name)
		if idx < 0: continue
		var at := rig.get_bone_rest(idx).origin
		at.x *= .74
		rig.set_bone_pose_position(idx,at)
		rig.set_bone_pose_rotation(idx,Quaternion.IDENTITY)
	for i: int in ARMS.size():
		var idx := rig.find_bone(ARMS[i])
		if idx < 0: continue
		var side := 1.0 if i==0 else -1.0
		var grip_local := Vector3(side*GRIP_HALF_WIDTH,HANDLE.y-STAND.y,STAND.z-HANDLE.z)
		var grip := rig.to_local(model.to_global(grip_local*model.scale.inverse()))
		var limb := rig.get_bone_global_pose(idx)
		var parent := rig.get_bone_parent(idx)
		var basis := rig.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var direction := (basis.inverse()*(grip-limb.origin)).normalized()
		if not direction.is_zero_approx():
			rig.set_bone_pose_rotation(idx,Quaternion(Vector3.RIGHT*side,direction))

static func clear(model: Node3D) -> void:
	if not model.has_meta(ACTIVE):return
	model.remove_meta(ACTIVE)
	model.position=Vector3.ZERO
	var rig := _rig(model)
	if rig == null: return
	for name: String in ARMS+LEGS:
		var idx := rig.find_bone(name)
		if idx>=0: rig.reset_bone_pose(idx)