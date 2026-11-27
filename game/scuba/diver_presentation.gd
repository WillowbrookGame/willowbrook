extends RefCounted
## Shared reef diver presentation, used for the player and visual-only remote divers.
const TANK=preload("res://game/town_assets/scuba-starter/twin-scuba-tank-rig.glb")
const FIN_LEFT=preload("res://game/town_assets/scuba-starter/dive-fin-left.glb")
const FIN_RIGHT=preload("res://game/town_assets/scuba-starter/dive-fin-right.glb")
const SWIM=preload("res://game/scuba/animation/swim_animation.gd")


static func fit(avatar: Node3D) -> AnimationPlayer:
	avatar.scale=Vector3.ONE*2.8
	avatar.position.y=-.5
	var swim:=SWIM.bind(avatar)
	# Kenney faces +Z. The original rig shows its cylinders/valves from +Z;
	# turn that face out toward -Z and put the thin harness side against the back.
	var tank:=TANK.instantiate() as Node3D
	tank.name="DiveTanks"
	var tank_fit:=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*.34),Vector3(0,.118,-.201))
	SWIM.attach_wearable(avatar,tank,"torso",tank_fit)
	# Each original fin has a heel pocket at -Z and its long blade in +Z.
	# The Kenney rig names these leg bones, but they skin the shoes as well.
	var left:=FIN_LEFT.instantiate() as Node3D
	left.name="LeftDiveFin"
	SWIM.attach_wearable(avatar,left,"leg-left",Transform3D(Basis.IDENTITY.scaled(Vector3(.81,.85,.76)),Vector3(.107,-.02,.112)))
	var right:=FIN_RIGHT.instantiate() as Node3D
	right.name="RightDiveFin"
	SWIM.attach_wearable(avatar,right,"leg-right",Transform3D(Basis.IDENTITY.scaled(Vector3(.81,.85,.76)),Vector3(-.107,-.02,.112)))
	for mesh: Node in avatar.find_children("*","GeometryInstance3D",true,false):
		(mesh as GeometryInstance3D).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return swim


static func animate(swim: AnimationPlayer, moving: bool) -> void:
	if swim == null: return
	var clip:=SWIM.STROKE if moving else SWIM.AQUATIC_IDLE
	if swim.current_animation != clip: swim.play(clip,.12)
