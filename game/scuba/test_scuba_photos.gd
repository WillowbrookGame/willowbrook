extends SceneTree
## Run headlessly: godot --headless --path . --script res://game/scuba/test_scuba_photos.gd
const REEF := "res://game/scuba/reef.tscn"
const BEACH := "res://game/beach.tscn"
const SHOP := preload("res://game/scuba/shop.gd")
const REEF_PHOTOS := preload("res://game/scuba/reef_photos.gd")
const PROFILE := preload("res://game/progression/profile.gd")

var failures := 0


class MockBrowserSession extends Node:
	signal fishing_reply(message: Dictionary)
	signal reef_photos_reply(message: Dictionary)
	var admitted := true
	var fish_discovered: Array = []
	var reef_photos: Array = []
	var last_photo_species := ""
	var last_photo_req := ""

	func fishing_snapshot() -> Dictionary:
		return {"equipped": false, "inventory": [], "discovered": fish_discovered.duplicate(), "_received_at": 100.0}

	func fishing_world() -> Dictionary:
		return {}

	func saved_stars() -> int:
		return 0

	func fishing_now() -> float:
		return 100.0

	func fishing_peer(_id: int) -> Node3D:
		return null

	func reef_photos_snapshot() -> Array:
		return reef_photos.duplicate() if admitted else []

	func send_reef_photo(species_id: String, request_id: String) -> bool:
		if not admitted:
			return false
		last_photo_species = species_id
		last_photo_req = request_id
		return true


class MockShopHost extends Node3D:
	var modal_open := false
	func set_zone_modal(open: bool) -> void:
		modal_open = open


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://scuba-photos-test-%d.cfg" % OS.get_process_id()
	var profile := PROFILE.new(save_path, 42)
	# Seed Fishing with a caught Reef Shark — catching a Reef Shark must NOT unlock its Reef Photo.
	var snap: Dictionary = profile.snapshot()
	snap.fish_discovered = ["shark"]
	_check(profile.commit(snap), "Seeded fishing shark discovery in profile")
	_check(REEF_PHOTOS.load_discovered(profile).is_empty(), "Catching a Reef Shark in Fishing does not unlock its Reef Photo")

	set_meta("willowbrook_profile", profile)
	if change_scene_to_file(REEF) != OK:
		_check(false, "Failed to load reef scene")
		quit(1)
		return
	await scene_changed
	await process_frame
	var reef := current_scene

	# Aim away from all fish (straight up near surface) -> no wildlife in frame.
	reef.diver.position = Vector3(0.0, -2.0, 24.0)
	reef.camera.global_position = Vector3(0.0, -2.0, 24.0)
	reef.camera.look_at(Vector3(0.0, 10.0, 24.0), Vector3.FORWARD)
	var miss: Dictionary = reef.take_photo()
	_check(not bool(miss.get("ok", false)), "Photo with no wildlife in frame returns ok=false")

	# Aim directly at the Shark deep visitor -> unlocks Shark Reef Photo.
	var shark_node: Node3D = reef.art._visitors[0].node
	var shark_pos := shark_node.global_position
	reef.camera.global_position = shark_pos + Vector3(0.0, 0.0, 2.5)
	reef.camera.look_at(shark_pos, Vector3.UP)
	var shark_res: Dictionary = reef.take_photo()
	_check(bool(shark_res.get("ok", false)) and bool(shark_res.get("new_discovery", false)) and String(shark_res.entry.id) == "shark", "Photographing Reef Shark unlocks it as a new Reef Photo")

	# Photographing the same Shark again does not double-count.
	var shark_again: Dictionary = reef.take_photo()
	_check(bool(shark_again.get("ok", false)) and not bool(shark_again.get("new_discovery", true)) and int(shark_again.count) == 1, "Repeat Reef Shark photo does not double-count")

	# Photograph a Clownfish school member -> unlocks Clownfish Reef Photo WITHOUT adding it to Fishing discoveries.
	var clown_node: Node3D = reef.art._fish[0].node
	var clown_pos := clown_node.global_position
	reef.camera.global_position = clown_pos + Vector3(0.0, 0.0, 3.5)
	reef.camera.look_at(clown_pos, Vector3.UP)
	var clown_res: Dictionary = reef.take_photo()
	_check(bool(clown_res.get("ok", false)) and bool(clown_res.get("new_discovery", false)) and String(clown_res.entry.id) == "clownfish", "Photographing Clownfish unlocks it in Reef Photos")

	# Verify persistence across Profile reload and strict separation from Fishing discoveries.
	var reloaded := PROFILE.new(save_path, 42)
	var reloaded_reef := REEF_PHOTOS.load_discovered(reloaded)
	var reloaded_fish: Array = reloaded.snapshot().get("fish_discovered", [])
	_check(reloaded_reef.size() == 2 and reloaded_reef.has("shark") and reloaded_reef.has("clownfish"), "Reef Photos persist across Profile reload")
	_check(reloaded_fish == ["shark"], "Photographing Clownfish did not alter Fishing discoveries")

	# Open Photo Book from Reef -> opens to Reef tab with both tabs visible.
	reef.open_photo_book()
	await process_frame
	var book: Control = reef.photo_book
	var tab_bar := book.find_child("BookTabs", true, false) as Control
	var progress := book.find_child("BookProgress", true, false) as Label
	var sunfish_card := book.find_child("Entry_sunfish", true, false)
	var sunfish_caption := sunfish_card.find_child("Caption", true, false) as Label if sunfish_card != null else null
	_check(book.visible and book.active_tab_id() == "reef", "Reef opens Photo Book directly to Reef tab")
	_check(tab_bar != null and tab_bar.visible, "Photo Book shows both Fishing and Reef tabs")
	_check(progress != null and progress.text == "2 / 8 discovered", "Reef tab shows 2 / 8 discovered")
	_check(sunfish_caption != null and sunfish_caption.text == "???", "Unphotographed Sunfish shows ???")
	reef.close_photo_book()
	await process_frame
	_check(not book.visible and reef.photo_button.visible and reef.book_button.visible, "Closing Photo Book restores Reef HUD buttons")

	# Full Reef HUD overlap & clipping check in portrait (360x640) and landscape (640x360).
	reef.depth.text = "Bluewater Overhang  16m"
	for vp_size: Vector2i in [Vector2i(360, 640), Vector2i(640, 360)]:
		root.size = vp_size
		await process_frame
		await physics_frame
		await process_frame
		var vp_rect := reef.get_viewport().get_visible_rect()
		var p_rect: Rect2 = reef.photo_button.get_global_rect()
		var b_rect: Rect2 = reef.book_button.get_global_rect()
		var d_rect: Rect2 = reef.depth.get_global_rect()
		var back_rect: Rect2 = reef.back.get_global_rect()
		var hint := reef.hud.get_node("SwimHint") as Label
		_check(p_rect.position.x >= 0.0 and b_rect.end.x <= vp_rect.size.x + 1.0, "Photo/Book buttons inside %s viewport" % [vp_size])
		_check(not p_rect.intersects(b_rect), "Photo and Book buttons do not overlap at %s" % [vp_size])
		_check(not p_rect.intersects(d_rect) and not b_rect.intersects(d_rect), "Photo/Book do not overlap depth label at %s: depth=%s photo=%s" % [vp_size, d_rect, p_rect])
		_check(not p_rect.intersects(back_rect) and not b_rect.intersects(back_rect), "Photo/Book do not overlap Return button at %s: back=%s book=%s" % [vp_size, back_rect, b_rect])
		if hint != null and hint.visible:
			var h_rect := hint.get_global_rect()
			_check(h_rect.end.x <= vp_rect.size.x + 1.0, "SwimHint fits in %s viewport: %s" % [vp_size, h_rect])

	# 2. Signed-in browser account consistency across Reef, Dive Shop, and Beach:
	#    Local temp profile is EMPTY, while signed-in server account has 2 caught fish + 1 reef photo.
	var temp_profile := PROFILE.new("")
	set_meta("willowbrook_profile", temp_profile)
	var session := MockBrowserSession.new()
	session.fish_discovered = ["goldfish", "tuna"]
	session.reef_photos = ["shark"]
	reef.add_child(session)
	reef.use_photo_account(session)

	# Reef takes a photo -> sends to server account, does NOT write to temp_profile.
	reef.camera.global_position = clown_pos + Vector3(0.0, 0.0, 2.5)
	reef.camera.look_at(clown_pos, Vector3.UP)
	var online_shot: Dictionary = reef.take_photo()
	_check(bool(online_shot.get("ok", false)) and bool(online_shot.get("pending", false)) and session.last_photo_species == "clownfish", "Signed-in Reef photo sends request to server account")
	_check(REEF_PHOTOS.load_discovered(temp_profile).is_empty(), "Signed-in Reef photo does not write to temporary local profile")
	session.reef_photos.append("clownfish")
	session.reef_photos_reply.emit({"requestId": session.last_photo_req, "ok": true, "species": "clownfish", "newDiscovery": true, "count": 2, "total": 8})

	# Check Reef book tabs agree with signed-in account (2/35 Fishing, 2/8 Reef).
	reef.open_photo_book()
	await process_frame
	var reef_prog := (reef.photo_book.find_child("BookProgress", true, false) as Label).text
	reef.photo_book.open("fishing")
	await process_frame
	var reef_fish_prog := (reef.photo_book.find_child("BookProgress", true, false) as Label).text
	_check(reef_prog == "2 / 8 discovered" and reef_fish_prog == "2 / 35 discovered", "Reef Photo Book reads signed-in account for both tabs: reef=%s fish=%s" % [reef_prog, reef_fish_prog])
	reef.close_photo_book()

	# Check Dive Shop book tabs agree with the exact same signed-in account.
	var shop_host := MockShopHost.new()
	var shop_hud := CanvasLayer.new()
	root.add_child(shop_host)
	shop_host.add_child(shop_hud)
	var shop := SHOP.new()
	shop._host = shop_host
	shop._hud = shop_hud
	shop_host.add_child(shop)
	shop.open_photo_book(session)
	await process_frame
	var shop_reef_prog := (shop._book.find_child("BookProgress", true, false) as Label).text
	shop._book.open("fishing")
	await process_frame
	var shop_fish_prog := (shop._book.find_child("BookProgress", true, false) as Label).text
	_check(shop_reef_prog == "2 / 8 discovered" and shop_fish_prog == "2 / 35 discovered", "Dive Shop Photo Book matches signed-in account for both tabs: reef=%s fish=%s" % [shop_reef_prog, shop_fish_prog])
	shop_host.queue_free()

	# Check Beach book tabs agree with the exact same signed-in account.
	if change_scene_to_file(BEACH) == OK:
		await scene_changed
		var beach := current_scene
		var beach_session := MockBrowserSession.new()
		beach_session.fish_discovered = ["goldfish", "tuna"]
		beach_session.reef_photos = ["shark", "clownfish"]
		beach.add_child(beach_session)
		beach.fishing_ui.use_fishing_account(beach_session)
		await physics_frame
		await physics_frame
		beach.fishing_ui.open_photo_book()
		await process_frame
		var beach_fish_prog := (beach.fishing_ui.photo_book.find_child("BookProgress", true, false) as Label).text
		beach.fishing_ui.photo_book.open("reef")
		await process_frame
		var beach_reef_prog := (beach.fishing_ui.photo_book.find_child("BookProgress", true, false) as Label).text
		_check(beach_fish_prog == "2 / 35 discovered" and beach_reef_prog == "2 / 8 discovered", "Beach Photo Book matches signed-in account for both tabs: fish=%s reef=%s" % [beach_fish_prog, beach_reef_prog])
	else:
		_check(false, "Failed to load Beach scene for cross-entry Photo Book consistency check")

	remove_meta("willowbrook_profile")
	for p: String in [save_path, save_path + ".bak"]:
		var abs_path := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)

	if failures == 0:
		print("PASS: Scuba Reef Photos capture, separation from Fishing, persistence, Photo Book tabs, and 360px/640px HUD")
	quit(failures)


func _check(result: bool, detail: String) -> void:
	if not result:
		failures += 1
		push_error(detail)
