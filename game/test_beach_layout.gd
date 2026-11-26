extends SceneTree
const BEACH := preload("res://game/beach_layout.gd")

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok

func run() -> void:
	var art := BEACH.new()
	root.add_child(art)
	var scenery := art.get_node("IslandScenery") as Node3D
	if not expect(scenery.scene_file_path == "res://game/beach_scenery.tscn","Beach did not use its editable scene"): return
	var base := scenery.get_node("BeachBase")
	if not expect(base.has_node("Sand/SandBody") and base.has_node("Water") and scenery.has_node("FerryPier/LandingDeckBody"),"The shoreline or landing was not authored"): return
	var kiosk := scenery.get_node("Shops/SnackKiosk") as Node3D
	var moved := "--relocated" in OS.get_cmdline_user_args()
	var expected := -19.65 if moved else -19.0
	if not expect(is_equal_approx(kiosk.position.x,expected),"Saved kiosk move did not enter the runtime layout"): return
	var boat := scenery.get_node("MooredBoats/Rowboat") as Node3D
	var initial_transform := boat.transform
	var scene_view := BEACH.new()
	scene_view.departure_only = true
	root.add_child(scene_view)
	if not expect(scene_view.get_child_count() == 1 and scene_view.get_child(0).scene_file_path == "res://game/beach_base.tscn","Dive departure stopped using the shared sand and water without Island fixtures"): return
	scene_view.free()
	await create_timer(.15).timeout
	if not expect(not boat.transform.is_equal_approx(initial_transform),"Moored boat animation stopped"): return
	var waterline := Vector3(expected,8,33.6)
	var ray := PhysicsRayQueryParameters3D.create(waterline,waterline-Vector3.UP*7,1)
	if not expect(art.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == kiosk.get_node("SolidBody"),"Kiosk collision did not follow its model"): return
	if not expect(is_equal_approx((kiosk.get_node("SolidBody") as StaticBody3D).global_position.x,expected),"Old collision location was left behind"): return
	if not expect(art.has_node("FerryLanding/WillowbrookShuttle") and not art.get_node("FerryLanding").has_node("PierBase") and scenery.has_node("FerryPier/PierBase"),"Ferry animated pieces or fixed pier missing"): return
	var finn := scenery.get_node("FishingPier/FinnDisplay")
	if not expect(finn.has_node("FishingLine") and finn.has_node("Bobber"),"Fishing display lost its line or bobber"): return
	var marina := scenery.get_node("Shops/Marina")
	var animation := marina.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	if not expect(animation.current_animation == "idle","Marina stopped animating"): return
	print("PASS Beach editable fixtures, moved collision, mooring animation, and shared dive backdrop.")
	quit(0)
