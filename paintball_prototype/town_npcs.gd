extends Node3D
## Physical outdoor neighbors. TownProgression owns conversations and job state.
const PROX = preload("res://paintball_prototype/npc_proximity.gd")
const TALK_RANGE := 3.65
# Stage platform top is 0.421m after fitted asset scale/offset.
# Raise only the visible actor; dialogue, approach and collision stay anchored.
const STAGE_HOST_ART_LIFT := .39
# The host stands at the left deck edge; nudge the skin inboard independent of yaw.
const STAGE_HOST_ART_INBOARD := .49
const ART := "res://paintball_prototype/town_assets/kenney-mini-npcs/"
const ROLES := [
	{"id":"nursery","label":"Nursery gardener","where":Vector3(-23,0,45),"talk":Vector3(-23,0,46.6),
		"avatar":"worker","yaw":0.0,"radius":1.7,"color":Color("#628d57")},
	{"id":"park","label":"Mayor","where":Vector3(25,0,-26),"talk":Vector3(24,0,-26),
		"avatar":"female-d","yaw":-PI/2.0,"radius":1.7,"color":Color("#638a67")},
	{"id":"singing","label":"Stage host","where":Vector3(49,0.05,-49),"talk":Vector3(49,0,-47.5),
		"avatar":"male-e","yaw":0.0,"radius":1.7,"color":Color("#a468b6")},
	{"id":"car_lot","label":"Car dealer","where":Vector3(19,0.05,-0.8),"talk":Vector3(19,0,3),
		"avatar":"male-b","yaw":0.0,"radius":2.0,"color":Color("#608e9a")},
]

var actors: Dictionary = {}
var animations: Dictionary = {}
var roles_by_id: Dictionary = {}
var greeted := ""
var idle_hint_distance := 8.5
var _player: Node3D

func _ready() -> void:
	for role in ROLES:
		roles_by_id[role.id] = role
		_build_actor(role)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		var map := get_parent().get_parent()
		_player = map.get_node_or_null("Player") as Node3D if map != null else null
	if is_instance_valid(_player):
		track_player(_player.global_position,delta)

func nearby(player_position: Vector3) -> String:
	var at := to_local(player_position)
	if absf(at.y) > 2.1:
		return ""
	var best := ""
	var closest := INF
	for role in ROLES:
		var actor: Node3D = actors[role.id]
		var target := actor.global_position
		var distance := Vector2(player_position.x-target.x,player_position.z-target.z).length()
		var own_body := actor.get_node("NeighborCollision") as CollisionObject3D
		if distance < closest and PROX.visible_from(self,player_position,target,(4.3 if role.id == "car_lot" else TALK_RANGE),target,[own_body.get_rid()]):
			closest = distance
			best = String(role.id)
	return best

func hire_in_reach(id: String, player_position: Vector3) -> bool:
	var role: Dictionary = roles_by_id.get(id,{})
	if role.is_empty():
		return false
	var local := to_local(player_position)
	var anchor: Vector3 = role.talk
	return absf(local.y) < 2.0 and Vector2(local.x-anchor.x,local.z-anchor.z).length() <= float(role.radius)

func prompt_for(id: String) -> String:
	var role: Dictionary = roles_by_id.get(id,{})
	return "Talk to " + String(role.label) if not role.is_empty() else ""

func track_player(player_position: Vector3,delta: float) -> void:
	var at := to_local(player_position)
	var near := nearby(player_position)
	if not near.is_empty() and near != greeted:
		_greet(near)
	greeted = near
	for id: String in actors:
		var actor: Node3D = actors[id]
		var role: Dictionary = roles_by_id[id]
		var delta_pos := at - actor.position
		delta_pos.y = 0.0
		var facing: float = role.yaw
		var close_enough := delta_pos.length_squared() < idle_hint_distance * idle_hint_distance
		if close_enough and delta_pos.length_squared() > 0.15:
			facing = atan2(delta_pos.x,delta_pos.z)
		actor.rotation.y = lerp_angle(actor.rotation.y,facing,1.0-exp(-maxf(0.0,delta)*8.0))
		if id == "singing":
			var art := actor.get_node_or_null("MiniCharacter") as Node3D
			if art != null:
				art.position = Vector3(STAGE_HOST_ART_INBOARD,STAGE_HOST_ART_LIFT,0).rotated(Vector3.UP,-actor.rotation.y)
		# Disabling idle evaluation for distant static actors saves tablet CPU.
		var animation: AnimationPlayer = animations.get(id)
		if animation != null:
			animation.active = close_enough

func _build_actor(role: Dictionary) -> void:
	var actor := Node3D.new()
	actor.name = "NPC_" + String(role.id)
	add_child(actor)
	actor.position = role.where
	actor.rotation.y = role.yaw
	actors[role.id] = actor
	# A slim body prevents walking through a neighbor without blocking the talk point.
	var body := StaticBody3D.new()
	body.name = "NeighborCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	actor.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .26
	shape.height = 1.32
	collider.shape = shape
	collider.position.y = .66
	body.add_child(collider)
	var path := ART + "character-" + String(role.avatar) + ".glb"
	var template := load(path) as PackedScene
	if template == null:
		_add_fallback(actor,role.color,STAGE_HOST_ART_LIFT if role.id == "singing" else 0.0)
		return
	var skin := template.instantiate() as Node3D
	actor.add_child(skin)
	skin.name = "MiniCharacter"
	if role.id == "singing":
		skin.position = Vector3(STAGE_HOST_ART_INBOARD,STAGE_HOST_ART_LIFT,0).rotated(Vector3.UP,-actor.rotation.y)
	skin.scale = Vector3.ONE * (2.7 if String(role.avatar).begins_with("female") else 3.05)
	var players := skin.find_children("*","AnimationPlayer",true,false)
	if players.is_empty():
		return
	var anim := players.front() as AnimationPlayer
	animations[role.id] = anim
	if anim.has_animation("idle"):
		# Source animation happens on a common resource; loop mode is identical per actor.
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
		anim.seek(0.15 + float(actors.size())*0.10,true)

func _greet(id: String) -> void:
	var anim: AnimationPlayer = animations.get(id)
	if anim == null or not anim.has_animation("interact-right"):
		return
	anim.active = true
	anim.play("interact-right",0.12)
	if anim.has_animation("idle"):
		anim.queue("idle")

func _add_fallback(actor: Node3D, color: Color, lift: float) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 1.1
	_add_mesh(actor,body,Vector3(0,0.66+lift,0),color)
	var head := SphereMesh.new()
	head.radius = 0.25
	head.height = 0.5
	_add_mesh(actor,head,Vector3(0,1.46+lift,0),Color("#c99551"))

func _add_mesh(actor: Node3D, mesh: PrimitiveMesh, at: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	actor.add_child(visual)
	visual.position = at
