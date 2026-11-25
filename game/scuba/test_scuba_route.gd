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
	set_meta("willowbrook_save_override", "user://scuba-route-disposable.cfg")
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
	reef.return_to_shop()
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
