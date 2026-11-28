extends SceneTree

const SCENE := preload("res://game/skyhill/skyhill.tscn")
const GOALS := preload("res://game/skyhill/flight_goals.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var level := SCENE.instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	await physics_frame
	var goals: GOALS = level.goals
	check(GOALS.segment_hit(Vector3(0,12,0),Vector3(0,-4,0)) == .75,"Swept crossing should hit even when neither endpoint is near the ring")
	check(GOALS.segment_hit(Vector3(1.1,2,0),Vector3(1.1,-2,0)) < 0,"Missing the opening does not count")
	check(GOALS.segment_hit(Vector3(-1,0,0),Vector3(1,0,0)) < 0,"Parallel movement in the plane is not a pass")
	check(GOALS.segment_hit(Vector3(0,1,0),Vector3.ZERO) == 1.0 and GOALS.segment_hit(Vector3.ZERO,Vector3(0,-1,0)) < 0,"Consecutive frames count a shared endpoint only once")
	var late: Node3D = goals.routes[0][2]
	check(not goals.step_segment(late.global_position+Vector3.BACK, late.global_position+Vector3.FORWARD),"Skipping a ring does not skip the sequence")
	check(goals.find_children("*","CollisionObject3D",true,false).is_empty() and level.landing_target.find_children("*","CollisionObject3D",true,false).is_empty(),"Goals must not participate in collision")
	check(goals.routes[0][0].visible and goals.routes[0][1].visible and not goals.routes[0][2].visible,"Only the next rings should be drawn")
	level._launch()
	for _i in 1200:
		if level.state == level.State.MEADOW:
			break
		level.step_flight(DT,0.0)
	check(level.state == level.State.MEADOW and goals.next[0] == goals.routes[0].size() and goals.next[1] == 0, "Original hands-off meadow flight should finish only the teal trail; " + goals.progress_line())
	check(level.goal_status.text.contains("Meadow rings: complete!"),"Completed trail result remains visible at landing")
	check(goals.routes[0].all(func(ring): return not ring.visible),"Completed hoops clear the view")
	level._on_deck()
	check(goals.next == [0,0] and not level.goal_status.visible and goals.landing_text.is_empty(),"Return clears all goal state")
	var center: Vector3 = level.landing_target.global_position
	for case in [[4.0,"Bullseye landing!"],[4.1,"Great landing!"],[9.0,"Great landing!"],[9.1,"Nice landing!"]]:
		goals.score_touchdown(center+Vector3.RIGHT*float(case[0])+Vector3.UP*.85,center)
		check(goals.landing_text==case[1],"Incorrect touchdown grade at %s meters" % case[0])
	level._launch()
	level.flight.heading = -PI*.5
	level._land(center+Vector3.RIGHT*3.8)
	for _i in 120:
		level.step_flight(DT,0)
	check(level.flight.position.x > center.x+9.0 and level.prompt.text.begins_with("Bullseye landing!"),"Grade must remain based on first contact, not the endpoint of the coast")
	level._launch()
	level._crash(center,"Crash test")
	check(goals.landing_text.is_empty() and not level.goal_status.visible,"A crash cannot be graded as a landing")
	level._launch()
	for route in goals.routes:
		var first: Node3D = route[0]
		level._track_goals(first.to_global(Vector3(0,1,0)), first.to_global(Vector3(0,-1,0)))
	check(goals.next == [1,1], "Either trail can be started independently")
	for size in [Vector2i(360,640),Vector2i(640,360)]:
		root.size = size
		await process_frame
		await process_frame
		level._update_route_guide()
		var status_rect: Rect2 = level.goal_status.get_global_rect()
		check(root.get_visible_rect().encloses(status_rect) and not status_rect.intersects(level.prompt.get_global_rect()) and not status_rect.intersects(level.guide.get_global_rect()), "Two-route progress fits above the guide at %s" % size)
	level._on_deck()
	# Two simultaneous game scenes use the same assets but cannot complete one another's goals.
	var second := SCENE.instantiate()
	root.add_child(second)
	second.set_physics_process(false)
	var ring: Node3D = goals.routes[0][0]
	goals.step_segment(ring.to_global(Vector3(0,1,0)),ring.to_global(Vector3(0,-1,0)))
	check(goals.next[0]==1 and second.goals.next==[0,0],"Progress belongs to the local flight")
	second.free()
	level.free()
	if failures==0:
		print("PASS Skyhill goals: swept ordered passes, personal progress, original meadow route, touchdown not runout, reset and crash isolation")
	quit(0 if failures==0 else 1)
