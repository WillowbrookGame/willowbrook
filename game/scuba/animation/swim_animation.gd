extends RefCounted
## Rotation-only retarget of the two original Quaternius non-RM swim clips.
const CATALOG=preload("res://game/avatars/catalog.gd")
const DATA=preload("res://game/scuba/animation/quaternius_swim.json")
const GROUP:=&"scuba"
const AQUATIC_IDLE:=&"scuba/Swim_Idle_Loop"
const STROKE:=&"scuba/Swim_Fwd_Loop"
const BONE_NAMES:=["torso","head","arm-left","arm-right","leg-left","leg-right"]

static func bind(model: Node3D) -> AnimationPlayer:
	var player:=CATALOG.animator(model)
	var skeletons:=model.find_children("*","Skeleton3D",true,false)
	if not is_instance_valid(player) or skeletons.size()!=1:return null
	var skeleton:=skeletons[0] as Skeleton3D
	var animation_root:=player.get_node_or_null(player.root_node)
	if animation_root==null:return null
	for bone: String in BONE_NAMES:
		if skeleton.find_bone(bone)<0:return null
	var source: Dictionary=DATA.data.get("animations",{})
	var library:=AnimationLibrary.new()
	for clip: String in ["Swim_Idle_Loop","Swim_Fwd_Loop"]:
		var baked:Dictionary=source.get(clip,{})
		var times:Array=baked.get("time",[])
		if times.size()<2:return null
		var animation:=Animation.new()
		animation.length=float(times.back())
		animation.loop_mode=Animation.LOOP_LINEAR
		for bone: String in BONE_NAMES:
			var keys:Array=baked.get("tracks",{}).get(bone,[])
			if keys.size()!=times.size():return null
			var track:=animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track,NodePath(str(animation_root.get_path_to(skeleton))+":"+bone))
			for i in times.size():
				var q:Array=keys[i]
				animation.rotation_track_insert_key(track,float(times[i]),Quaternion(q[0],q[1],q[2],q[3]).normalized())
		library.add_animation(clip,animation)
	player.add_animation_library(GROUP,library)
	player.play(AQUATIC_IDLE)
	return player

static func attach_wearable(model: Node3D, wearable: Node3D, bone_name: String, fit: Transform3D) -> void:
	var skeletons:=model.find_children("*","Skeleton3D",true,false)
	if skeletons.size()!=1:
		wearable.free()
		return
	var sk:=skeletons[0] as Skeleton3D
	var bone:=sk.find_bone(bone_name)
	if bone<0:
		wearable.free()
		return
	var rest:=model.global_transform.affine_inverse()*sk.global_transform*sk.get_bone_global_rest(bone)
	var socket:=BoneAttachment3D.new()
	socket.bone_name=bone_name
	sk.add_child(socket)
	wearable.transform=rest.affine_inverse()*fit
	socket.add_child(wearable)
