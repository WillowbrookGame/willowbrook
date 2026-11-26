extends SceneTree

const BEACH := "res://game/beach.tscn"
const REEF := "res://game/scuba/reef.tscn"
const DIVE_DOOR := Vector3(-24.15, 0, 12.45)
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)


func _button(parent: Node, text: String) -> Button:
	for control: Node in parent.find_children("*", "Button", true, false):
		if control.text == text:
			return control
	return null


func _run() -> void:
	set_meta("willowbrook_save_override", "")
	set_meta("fishing_save_override", "")
	if change_scene_to_file(BEACH) != OK:
		quit(1)
		return
	await scene_changed
	var island := current_scene
	island.player.position = DIVE_DOOR + Vector3(0, .06, .75)
	_check(island._interaction_text() == "Enter Dive Shop", "Island dock should show the Dive Shop entrance")
	island._interact()
	if not island.changing:
		quit(1)
		return
	await scene_changed
	var shop := current_scene
	_check(shop.current_zone_id() == "dive_shop" and shop.room.scene_file_path == "res://game/scuba/shop.tscn", "Existing Dive Shop zone should use its own scene")
	_check(shop._camera_collision_mask == 5 and is_equal_approx(shop._camera_tight_enter, 2.25) and is_equal_approx(shop._camera_tight_leave, 2.68), "Dive Shop camera tuning changed")
	_check(shop.player.position.distance_to(Vector3(2.11, .04, .54)) < .15, "Dive Shop spawn changed")
	_check(is_equal_approx(shop.look_yaw, .65), "Dive Shop arrival heading changed")
	await physics_frame
	await physics_frame
	_check_layout(shop.room)
	shop.player.position = Vector3(-1.5, .04, 0)
	shop._interact()
	if not shop.room.is_modal_open():
		quit(1)
		return
	var leave := _button(shop.room._panel, "Not now")
	if leave == null:
		quit(1)
		return
	leave.pressed.emit()
	_check(not shop.room.is_modal_open() and not shop.zone_modal, "Declining should restore movement")
	await process_frame
	shop._interact()
	var start := _button(shop.room._panel, "Go on a dive trip")
	if start == null:
		quit(1)
		return
	var boarded := Time.get_ticks_msec()
	start.pressed.emit()
	await process_frame
	_check(shop.room._trip != null and shop.room._trip.get_node("DepartureWaves").playing, "Departure did not start with waves")
	await scene_changed
	var reef := current_scene
	_check(reef.scene_file_path == REEF and reef.has_node("Diver"), "Destination should still be the Reef")
	_check(Time.get_ticks_msec() - boarded >= 4900, "Departure loaded too early")
	await _check_reef(reef)
	reef.back.pressed.emit()
	await scene_changed
	shop = current_scene
	_check(shop.current_zone_id() == "dive_shop", "Reef should return to the same Dive Shop zone")
	shop.player.position = Vector3(2.2, .04, 1.9)
	shop._interact()
	if not shop.changing:
		quit(1)
		return
	await scene_changed
	_check(current_scene.scene_file_path == BEACH and current_scene.player.position.distance_to(DIVE_DOOR + Vector3(0, .06, .75)) < .2, "Shop exit should preserve the Island spawn")
	if failures == 0:
		print("PASS: Island entry, Dive Master dialogue, departure audio and five-second floor, Reef and return")
	quit(1 if failures else 0)

func _check_layout(room: Node3D) -> void:
	var layout := room.get_node("DiveShopLayout") as Node3D
	_check(layout.scene_file_path == "res://game/scuba/shop_layout.tscn", "Dive Shop did not use editable layout")
	_check(room._actor == layout.get_node("DiveMaster"), "Dialogue not attached to the authored Dive Master")
	var shell := layout.get_node("RoomStructure/ShopModel/SurfShop")
	_check(shell.get_node("Shack").visible and not shell.get_node("Roof").visible and not shell.get_node("WetsuitRack").visible, "Shop shell did not retain the interior visibility rules")
	var display := layout.get_node("WetsuitDisplay/RackModel/SurfShop")
	_check(display.get_node("WetsuitRack").visible and display.get_node("Wetsuit_1").visible and display.get_node("Wetsuit_2").visible and not display.get_node("Shack").visible, "Wetsuit shop display did not retain the original pieces")
	var bench := layout.get_node("EquipmentBench") as Node3D
	_check(bench.has_node("DiveMask") and bench.has_node("LeftFin") and bench.has_node("RightFin") and bench.has_node("UnderwaterCamera"), "Dive gear does not move with the bench")
	var moved := "--relocated" in OS.get_cmdline_user_args()
	_check(is_equal_approx(bench.position.z, -2.93 if moved else -2.68), "The saved bench position did not reach gameplay")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(2.3,.7,-1.8),Vector3(2.3,.7,-3.4),1)
	var hit := bench.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(hit.get("collider") == bench.get_node("SolidBody"), "Dive bench collider missing")
	if hit.get("collider") == bench.get_node("SolidBody"):
		_check(absf(hit.position.z - (-2.365 if moved else -2.115)) < .008, "Dive bench collision did not move with its authored model")

func _check_reef(reef: Node3D) -> void:
	var layout := reef.art.get_node("ReefLayout") as Node3D
	_check(layout.scene_file_path == "res://game/scuba/reef_layout.tscn", "Reef did not load its editable layout")
	_check(layout.has_node("Seabed/Slope/Model") and layout.has_node("Wreck/Cockpit/SolidBody") and layout.has_node("Coral/FanWest/Model"), "Named Reef scenery is missing")
	var school: Array = reef.art._fish
	_check(school.size() == 24, "Fish school inventory changed")
	if school.size() != 24: return
	var fish: Node3D = school[0].node
	var start := fish.position
	var arch := layout.get_node("Gate/CoralArch") as Node3D
	var moved := "--reef-relocated" in OS.get_cmdline_user_args()
	_check(arch.position.is_equal_approx(Vector3(.8 if moved else 0.0,-11.0,-5.7)), "Reef did not load the saved arch placement")
	for frame in range(10):
		await physics_frame
	_check(fish.get_parent() == reef.art and fish.position.distance_to(start) > .01, "Fish movement was baked or stopped")
	var space := arch.get_world_3d().direct_space_state
	var p := arch.global_position+Vector3(0,3,0)
	var opening := PhysicsRayQueryParameters3D.create(p+Vector3.BACK*2,p+Vector3.FORWARD*2,1)
	_check(space.intersect_ray(opening).is_empty(), "Coral Gate passage is blocked")
	for part in ["LeftSupport","RightSupport","Lintel"]:
		var body := arch.get_node(part) as StaticBody3D
		var at := body.global_position
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.BACK*2,at+Vector3.FORWARD*2,1)
		_check(space.intersect_ray(ray).get("collider") == body, "Missing or detached Coral Gate collision: "+part)
	reef.diver.position = p+Vector3.BACK*1.85
	reef.diver.velocity = Vector3.ZERO
	Input.action_press("ui_up")
	for frame in range(64):
		await physics_frame
	Input.action_release("ui_up")
	_check(reef.diver.position.z < p.z - 1.0, "Player input could not swim through the Coral Gate")
	_check(reef.get_node("ScubaBubbles").playing, "Diving audio did not start")
