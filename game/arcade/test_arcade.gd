extends SceneTree

const ROOM = preload("res://game/arcade/room.tscn")

class Host extends Node3D:
	var dialog := false
	var exited := false
	func set_zone_modal(open: bool) -> void:
		dialog = open
	func go_to_town() -> void:
		exited = true

class FakeSession extends Node:
	signal hockey_changed(state: Dictionary)
	var admitted := true
	var joins := 0
	var leaves := 0
	var rematches := 0
	var aim := Vector2.ZERO
	func hockey_join() -> void:
		joins += 1
		hockey_changed.emit({"side":0, "phase":"waiting"})
	func hockey_leave() -> void:
		leaves += 1
	func hockey_input(target: Vector2) -> void:
		aim = target
	func hockey_rematch() -> void:
		rematches += 1

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Host.new()
	var player := CharacterBody3D.new()
	var room = ROOM.instantiate()
	var canvas := CanvasLayer.new()
	root.add_child(host)
	host.add_child(player)
	host.add_child(room)
	host.add_child(canvas)
	room.setup("arcade",host,player,canvas)
	player.position = room.spawn_position()
	await process_frame
	_check(room.interaction_prompt() == "Back to Town", "exit prompt at spawn")
	_check(room.interact() and host.exited,"exit invokes host")
	await physics_frame
	await physics_frame
	_check_layout(room)
	for cabinet: Dictionary in room.targets:
		player.position = cabinet.at
		_check(room.interaction_prompt() == "Play " + cabinet.label,"target for " + cabinet.id)
		_check(room.interact() and host.dialog,"cabinet opens and locks player")
		_check(not room.menu.running,"help shown before play")
		room.menu.play()
		room.menu.display.step(.03)
		_check(room.menu.running,"cabinet starts")
		var screen: Control = room.menu.display
		if cabinet.id == "memory":
			for face: int in 6:
				for idx: int in 12:
					if screen.state.cards[idx] == face:
						screen._flip(idx)
			_check(screen.state.done and screen.state.score == 6,"memory six pairs")
			_check(screen.art.size() == 6 and screen.art[0] != null,"memory original art")
		elif cabinet.id == "basketball":
			screen.play_input("action",true)
			screen.step(.4)
			screen.play_input("action",false)
			_check(screen.state.shots.size() == 1,"basketball hold-and-release launches shot")
			screen.state.shots = [{"pos":Vector2(396,126),"v":Vector2(0,120),"scored":false}]
			screen.step(.04)
			_check(screen.state.score == 2,"descending ball awards basket")
			for value in [
				{"pos":Vector2(390,90),"v":Vector2(1000,0),"scored":false},
				{"pos":Vector2(460,90),"v":Vector2(-1000,0),"scored":false},
				{"pos":Vector2(420,29),"v":Vector2(0,1000),"scored":false}
			]:
				screen.state.shots = [value]
				screen._step_basketball(.04)
				var local_ball: Dictionary = screen.state.shots[0]
				_check(not screen.BACKBOARD.grow(screen.BALL_RADIUS).has_point(local_ball.pos),"ball swept clear of drawn basketball backboard")
			screen.state.shots=[{"pos":Vector2(390,96),"v":Vector2(1000,0),"scored":false}]
			screen._step_basketball(.04)
			_check(screen.state.shots[0].v.x<0,"visible backboard front rebounds")
		elif cabinet.id == "claw":
			screen.play_input("right",true)
			screen.step(.43)
			screen.play_input("right",false)
			screen.play_input("up",true)
			screen.step(.51)
			screen.play_input("up",false)
			screen.step(.51)
			_check(screen.state.phase == "collect","claw horizontal and depth timing leads to chute")
			screen.play_input("action",true)
			_check(screen.state.collected == 1,"claw collect")
		elif cabinet.id == "air-hockey":
			screen.hockey_target = Vector2(-.18,.8)
			screen.pointer_id = 7
			screen._hockey_update({"side":0,"phase":"waiting","round":1})
			screen._hockey_update({"side":0,"phase":"playing","round":2,"paddles":[Vector2(.24,-.63),Vector2(.1,.51)]})
			_check(screen.hockey_target==Vector2(-.63,.24) and screen.pointer_id==-2,"fresh LAN state uses authority and clears stale dragged target")
			for round_index: int in 2:
				for goal: int in 5:
					screen._goal(0)
				_check(screen.state.wins[0] == round_index+1,"air hockey accumulates round win")
				if round_index == 0:
					screen.state.target = Vector2(210,36)
					screen.state.player = Vector2(210,36)
					screen.state.enemy = Vector2(277,280)
					screen.pointer_id=7
					screen.play_input("action",true)
					screen.play_input("action",false)
					_check(screen.state.target==screen.LEFT_PADDLE and screen.state.player==screen.LEFT_PADDLE and screen.state.enemy==screen.RIGHT_PADDLE and screen.pointer_id==-2,"next round resets local paddles and drag")
			_check(screen.state.done and screen.state.round==2 and screen.state.wins==[2,0],"air hockey 2–0 ends the match")
		elif cabinet.id == "survivors":
			_check(not room.menu.controls_by_action["action"].visible,"survivors Action hidden during normal play")
			screen.action_game.s.upgrade=true
			var prior:int=screen.action_game.s.power
			room.menu._process(.016)
			_check(room.menu.controls_by_action["action"].visible,"touch Action appears during a Survivors upgrade")
			room.menu.controls_by_action["action"].button_down.emit()
			room.menu.controls_by_action["action"].button_up.emit()
			_check(not screen.action_game.s.upgrade and screen.action_game.s.power>prior,"touch Action confirms selected upgrade")
		else:
			_check(screen.action_game != null,"native action game initialized")
			screen.play_input("right",true)
			screen.play_input("up",true)
			screen.play_input("action",true)
			for i: int in 120:
				screen.step(.016)
			screen.play_input("action",false)
		await process_frame
		room.menu.dismiss()
		_check(not host.dialog and not room.menu.visible,"dismiss returns control")
	if root.get_node_or_null("WillowbrookSession") == null:
		var session := FakeSession.new()
		session.name = "WillowbrookSession"
		root.add_child(session)
		room.menu.open_cabinet("air-hockey","Air Hockey")
		_check(room.menu.online.visible, "online play offered only for a joined LAN session")
		room.menu.online.pressed.emit()
		_check(session.joins == 1 and room.menu.running and room.menu.display.message().begins_with("Waiting"),"friend button requests authoritative seat")
		var snapshot := {"side":0,"phase":"playing","round":2,"scores":[2,1],"paddles":[Vector2(0,-.65),Vector2(0,.65)],"puck":Vector2.ZERO}
		room.menu.display.hockey_target=Vector2(-.18,.8)
		room.menu.display.pointer_id=5
		session.hockey_changed.emit(snapshot)
		_check(room.menu.display.hockey_target==Vector2(-.65,0) and room.menu.display.pointer_id==-2,"first fresh LAN frame replaces stale paddle target")
		room.menu.display.play_input("right",true)
		room.menu.display.step(.05)
		_check(session.aim.y > -.6 and session.aim.y < 0 and room.menu.display.message().contains("Round 2"),"authoritative state and correctly rotated aim")
		await process_frame
		room.menu.dismiss()
		_check(session.leaves == 1 and not host.dialog and not snapshot.is_empty(),"leaves seat and doesn't mutate authoritative state")
		session.queue_free()
	host.queue_free()
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	var town: Node3D = current_scene
	var door := Vector3(0,0,-47)
	town.player.position = door + Vector3(0,.04,1.3)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	town._unhandled_key_input(event)
	_check(town.changing,"Town door accepts Arcade entry")
	if not town.changing:
		quit(1)
		return
	await scene_changed
	var map: Node3D = current_scene
	_check(map.room_id == "arcade" and map.room.scene_file_path == ROOM.resource_path,"Town loads Arcade PackedScene with the same zone ID")
	_check(map.player.position.is_equal_approx(map.room.spawn_position()),"Arcade entry spawn unchanged")
	map._refresh_prompt()
	map.enter_button.pressed.emit()
	_check(map.changing,"Arcade exit button returns to Town")
	if not map.changing:
		quit(1)
		return
	await scene_changed
	_check(current_scene.player.position.is_equal_approx(door + Vector3(0,.04,2)),"Arcade exit returns to the same Town doorstep")
	print("ARCADE: all 8 cabinets, help/play/close, original models/art, representative mechanics tested")
	quit(1 if failed else 0)

func _check_layout(room: Node3D) -> void:
	var layout: Node3D = room.layout
	var cabinets: Node3D = layout.get_node("Cabinets")
	_check(layout.scene_file_path == "res://game/arcade/room_layout.tscn","the game uses the same editable layout")
	_check(room.targets.size() == 8 and cabinets.get_child_count() == 8,"original eight cabinets")
	var ids := ["basketball","memory","road-hop","maze-chase","claw","air-hockey","brick-breaker","survivors"]
	var models := ["basketball-game","arcade-machine","arcade-machine","arcade-machine","claw-machine","air-hockey","arcade-machine","arcade-machine"]
	var spots := [Vector3(-6,.03,-3.45),Vector3(-2,.03,-4),Vector3(2,.03,-4),Vector3(6,.03,-4),Vector3(-6,.03,0),Vector3(0,.03,2.3),Vector3(6,.03,1),Vector3(-6,.03,3.6)]
	var moved := "--relocated" in OS.get_cmdline_user_args()
	var space := layout.get_world_3d().direct_space_state
	for i in range(cabinets.get_child_count()):
		var cabinet := cabinets.get_child(i) as Node3D
		var spot: Dictionary = room.targets[i]
		var model := cabinet.get_node("Model") as Node3D
		var marker := cabinet.get_node("InteractHere") as Marker3D
		_check(spot.id == ids[i] and model.scene_file_path.ends_with("/"+models[i]+".glb"),"cabinet ID and original model: "+str(i))
		_check(spot.at.is_equal_approx(marker.global_position),"prompt marker moves with cabinet: "+str(spot.id))
		if not moved or spot.id != "memory":
			_check(spot.at.is_equal_approx(spots[i]),"default prompt position: "+str(spot.id))
		else:
			_check(cabinet.position.is_equal_approx(Vector3(-2,.03,-3.75)) and absf(angle_difference(cabinet.rotation.y,PI/2.0)) < .001,"saved cabinet move and rotation reached runtime")
			_check(spot.at.is_equal_approx(Vector3(-.2,.03,-3.75)),"moved and rotated cabinet prompt")
		var p := cabinet.global_position
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*3,p+Vector3.UP*.1,1)
		_check(space.intersect_ray(ray).get("collider") == cabinet.get_node("SolidBody"),"collision attached to "+str(spot.id))
	if moved:
		var old := PhysicsRayQueryParameters3D.create(Vector3(-2,3,-5.8),Vector3(-2,.1,-5.8),1)
		_check(space.intersect_ray(old).is_empty(),"no collider left at Memory's old placement")

func _check(condition: bool, detail: String) -> void:
	if not condition:
		push_error("ARCADE: " + detail)
		failed = true
