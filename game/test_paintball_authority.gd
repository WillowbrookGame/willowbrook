extends SceneTree
const AUTHORITY = preload("res://game/network/paintball/match_authority.gd")

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, msg: String) -> bool:
	if not ok:
		push_error(msg)
		quit(1)
	return ok

func _run() -> void:
	var auth: Node3D = AUTHORITY.new()
	root.add_child(auth)
	await physics_frame
	var t := 1000
	if not _require(auth.open([{"slot":"h1","alias":"Alice","avatar":"female-b"},{"slot":"h2","alias":"Bob","avatar":"male-b"}], "h1", t), "Authority failed to open 2-human + 2-bot match"):
		return
	var avatars := {}
	for sid: String in auth.slots:
		avatars[auth.slots[sid].avatar] = true
	if not _require(auth.slots.size() == 4 and avatars.size() == 4, "Authority bots did not get distinct avatars: %s" % [avatars.keys()]):
		return
	auth.ready_slot("h1", t + 100)
	auth.ready_slot("h2", t + 200)
	var snap: Dictionary = auth.snapshot("h1", t + 200)
	if not _require(snap.phase == "playing" and int(snap.countdownMs) > 0, "Authority did not enter 3-2-1 countdown"):
		return
	# Advance past countdown.
	t += 200 + auth.COUNTDOWN_MS + 50
	auth.step(0.05, t)
	snap = auth.snapshot("h1", t)
	if not _require(int(snap.countdownMs) == 0 and int(snap.remainingMs) <= auth.ROUND_MS, "Authority countdown did not finish"):
		return
	# Verify 2.2s tag immunity and early 12-tag round finish.
	(auth.arena.find_child("YardCollision", true, false) as StaticBody3D).collision_layer = 0
	auth.slots["h1"].body.position = Vector3(0, 0.05, 8)
	auth.slots["h2"].body.position = Vector3(0, 0.05, 4)
	await physics_frame
	auth._tag_ray(auth.slots["h1"], Vector3.FORWARD, t)
	if not _require(auth.rules.points["h1"] == 1 and int(auth.slots["h2"].immune_until) == t + auth.TAG_IMMUNITY_MS, "First authority tag did not score and set immunity"):
		return
	auth._tag_ray(auth.slots["h1"], Vector3.FORWARD, t + 500)
	if not _require(auth.rules.points["h1"] == 1, "Repeat tag during immunity should not score"):
		return
	t += auth.TAG_IMMUNITY_MS + 50
	auth._tag_ray(auth.slots["h1"], Vector3.FORWARD, t)
	if not _require(auth.rules.points["h1"] == 2, "Tag after immunity expired did not score"):
		return
	for i in range(auth.TARGET_POINTS - 2):
		t += auth.TAG_IMMUNITY_MS + 50
		auth._tag_ray(auth.slots["h1"], Vector3.FORWARD, t)
	if not _require(auth.phase == "between" and auth.rules.points["h1"] == auth.TARGET_POINTS, "Reaching 12 tags did not end authority round early"):
		return
	print("PASS: online match_authority countdown, distinct avatars, 2.2s tag immunity, and 12-tag early finish")
	quit()
