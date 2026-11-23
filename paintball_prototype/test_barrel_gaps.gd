extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://paintball_prototype/arena.tscn")
	await scene_changed
	var map := current_scene
	var player: CharacterBody3D = map.player
	for spot in [Vector2(-10.8,6.35), Vector2(10.8,-6.35), Vector2(-6.3,19.3)]:
		player.position = Vector3(spot.x,2.25,spot.y)
		player.velocity = Vector3.ZERO
		for i in range(28):
			await physics_frame
		if not player.is_on_floor() or absf(player.position.y-1.37) > 0.05:
			push_error("Dropped into a barrel pocket instead of landing clear: %s" % player.position)
			quit(1)
			return
		player.request_jump()
		for i in range(10):
			await physics_frame
		if player.position.y < 2.35:
			push_error("Could not jump back out near the drums: %s" % player.position)
			quit(1)
			return
	print("PASS: all three narrow barrel/barrier pockets support a falling player and allow jumping clear")
	quit()
