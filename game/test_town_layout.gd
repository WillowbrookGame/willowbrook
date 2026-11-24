extends SceneTree

const TOWN := preload("res://game/town_layout.gd")

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var layout := TOWN.new()
	root.add_child(layout)
	await physics_frame
	await physics_frame
	var space := layout.get_world_3d().direct_space_state
	var failures: PackedStringArray = []
	for at: Vector3 in [TOWN.SPAWN,TOWN.BEACH_RETURN,TOWN.ARCADE_DOOR,
			TOWN.ARENA_DOOR + Vector3(0,0.04,1.6),Vector3(79,0,58)]:
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP*1.5,at - Vector3.UP*0.5)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or absf((hit.position as Vector3).y) > 0.02:
			failures.append("Missing floor or obstructed approach: %s" % at)
	for route: Array in [
			[TOWN.ARENA_DOOR+Vector3(0,0,6.1), TOWN.ARENA_DOOR+Vector3(0,0,0.08)],
			[TOWN.ARCADE_DOOR+Vector3(0,0,4.4), TOWN.ARCADE_DOOR+Vector3(0,0,0.08)],
			[TOWN.BEACH_RETURN, TOWN.BEACH_DOOR+Vector3(0,0,1.0)]]:
		var direct := PhysicsRayQueryParameters3D.create(route[0] + Vector3.UP*0.7, route[1] + Vector3.UP*0.7)
		if not space.intersect_ray(direct).is_empty():
			failures.append("Blocked walk-up: %s" % [route])
	for structure in ["PaintballWarehouseExterior","WillowLibrary","SunnyCafe","TownStore","WillowBank","PetVet","BeautySalon"]:
		var model := layout.get_node_or_null(structure) as Node3D
		if model == null:
			failures.append("Missing structure: %s" % structure)
			continue
		var size: Vector3 = model.get_meta("layout_size")
		var scale := model.basis.get_scale()
		if absf(scale.x-scale.y) > 0.001 or absf(scale.y-scale.z) > 0.001:
			failures.append("Non-uniform scale: %s (%s)" % [structure,scale])
		if size.y < 4.0 or size.y > 12.0:
			failures.append("Not to architectural scale: %s (%s m)" % [structure,size.y])
	for id: String in TOWN.BUSINESS_DOORS:
		var portal: Vector3 = TOWN.BUSINESS_DOORS[id]
		var arrival_offset: Vector3 = TOWN.BUSINESS_RETURN_OFFSETS[id]
		for distance in [0.0,1.0,2.1]:
			var at := portal + arrival_offset * float(distance) + Vector3.UP*0.75
			if not _capsule_clear(space,at):
				failures.append("Capsule blocked by %s exterior at %s" % [id,at])
	for at: Vector3 in TOWN.HOME_DOORS + TOWN.PLAYGROUND_ENTRIES.values():
		if not _capsule_clear(space,at + Vector3.UP*0.75):
			failures.append("Blocked home or ride entry at %s" % at)
	for at: Vector3 in [Vector3(-23,0,50),Vector3(18.5,0,47),Vector3(21.5,0,51),
			Vector3(12,0,-22),Vector3(20,0,-22),Vector3(20,0,-27),Vector3(52,0,-48),Vector3(56,0,-48)]:
		if not _capsule_clear(space,at + Vector3.UP*0.75):
			failures.append("Blocked original progression position at %s" % at)
	for landmark in ["VillageGreenFountain","WillowArcade","Playground","PlaygroundSlide",
			"PlaygroundSwing","PlaygroundSeesaw","SkateCorner","StarlightStage","LittleNursery",
			"CommunityGarden","HiringNoticeBoard","WillowWheels","ScooterRack","DistantBeachSnapshot","FerryLanding","TownBayWater"]:
		if layout.get_node_or_null(landmark) == null:
			failures.append("Missing exterior landmark %s" % landmark)
	for item in [["PlaygroundSwing","swing_A_small_seat"],["PlaygroundSeesaw","seesaw_small_seat"]]:
		var ride := layout.get_node_or_null(item[0]) as Node3D
		if ride == null or ride.find_child(item[1],true,false) == null:
			failures.append("Missing original animated playground mesh %s" % item[1])
	var roads := 0
	for child in layout.get_children():
		if child.name.begins_with("Road_"):
			roads += 1
	if roads != 67:
		failures.append("Expected 67 original road tiles; found %d" % roads)
	for cell in ["Road_-6_-3","Road_6_3","Road_0_1","Road_3_-1","Road_0_-3"]:
		if layout.get_node_or_null(cell) == null:
			failures.append("Missing original junction %s" % cell)
	if failures.is_empty():
		print("Town layout passed: original road grid, scale and portal walk-ups.")
	else:
		for problem in failures:
			push_error(problem)
	quit(0 if failures.is_empty() else 1)

func _capsule_clear(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var player := CapsuleShape3D.new()
	player.radius = 0.28
	player.height = 1.4
	var cast := PhysicsShapeQueryParameters3D.new()
	cast.shape = player
	cast.transform = Transform3D(Basis.IDENTITY,at)
	return space.intersect_shape(cast,1).is_empty()
