extends SceneTree

const TOWN := preload("res://game/town_layout.gd")

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var town := TOWN.new()
	root.add_child(town)
	var actors = town.get_node_or_null("TownNpcs")
	var failures: PackedStringArray = []
	if actors == null:
		push_error("Town layout did not attach outdoor neighbors.")
		quit(1)
		return
	for role: Dictionary in actors.ROLES:
		var at: Vector3 = role.talk
		if actors.nearby(at) != role.id or actors.prompt_for(role.id) != "Talk to " + String(role.label):
			failures.append("Incorrect proximity/prompt for %s" % role.id)
		var actor := actors.get_node_or_null("NPC_" + String(role.id)) as Node3D
		if actor == null or actor.position != role.where or actor.get_node_or_null("MiniCharacter") == null:
			failures.append("Original placement/model missing: %s" % role.id)
		actors.track_player(at,0.20)
		var state: AnimationPlayer = actors.animations.get(role.id)
		if state == null or not state.active or state.current_animation != "interact-right":
			failures.append("Greeting arm animation missing for %s" % role.id)
		if role.id != "car_lot" and Vector2((TOWN.OUTDOOR_ROLES[role.id] as Vector3).x-at.x,
				(TOWN.OUTDOOR_ROLES[role.id] as Vector3).z-at.z).length() > 0.001:
			failures.append("Town job spot differs from NPC stop: %s" % role.id)
		actors.track_player(TOWN.SPAWN,0.05)
		if state != null and state.active:
			failures.append("Distant actor kept animating: %s" % role.id)
	if not actors.nearby(TOWN.SPAWN).is_empty():
		failures.append("Spawn incorrectly has a talk interaction.")
	for issue in failures:
		push_error(issue)
	if failures.is_empty():
		print("Town NPC smoke passed: four imported original neighbors, proximity, greeting and distance culling.")
	quit(0 if failures.is_empty() else 1)
