extends SceneTree
## Run headlessly: godot --headless --path . --script res://game/test_fishing_photo_book.gd
const Fishing = preload("res://game/fishing_game.gd")
const Profile = preload("res://game/progression/profile.gd")
const PhotoBook = preload("res://game/photo_book_ui.gd")
const THUMB_PATH := "res://game/fish_thumbs/"

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pid := OS.get_process_id()
	var legacy_path := "user://fishing-book-legacy-%d.cfg" % pid
	var town_path := "user://fishing-book-town-%d.cfg" % pid

	# 1. Old standalone save without fish_discovered loads cleanly and does NOT infer from bag.
	var old_cfg := ConfigFile.new()
	old_cfg.set_value("profile", "fish", ["goldfish", "clownfish"])
	old_cfg.set_value("profile", "stars", 12)
	old_cfg.save(legacy_path)
	var legacy_game := Fishing.new(legacy_path, 7)
	_check(legacy_game.inventory.size() == 2, "Old standalone save loads fish bag")
	_check(legacy_game.discovered.is_empty(), "Old standalone save does not infer discoveries from fish bag")

	# 2. Old shared town profile without fish_discovered loads cleanly and does NOT infer from bag.
	var town_cfg := ConfigFile.new()
	town_cfg.set_value("profile", "version", Profile.PROFILE_VERSION)
	town_cfg.set_value("profile", "data", {
		"stars": 5, "fish": ["tetra"], "fishing_migrated": true, "employed": "", "memberships": [],
		"classes": {}, "home": {}, "loan": {}, "pet": {}, "furniture": [], "furniture_stock": {},
		"deliveries": [], "portfolio": {}, "job": {"stage": "none", "deliveries": 0},
		"work": {}, "work_completed": {}, "starter": {"completed": {}, "rewarded": {}, "run": {}},
	})
	town_cfg.save(town_path)
	var town_profile := Profile.new(town_path, 11)
	var game := Fishing.new("", 57)
	game.attach_town_profile(town_profile)
	_check(game.inventory == ["tetra"], "Old shared town profile loads fish bag")
	_check(game.discovered.is_empty(), "Old shared town profile does not infer discoveries from fish bag")

	# 3. Catching reveals species once, persists with town profile, and stays revealed after selling.
	game.start_population()
	game.equip_pole()
	var shadow: Vector3 = game.population[0].position
	var expected_species: String = game.population[0].type
	_check(game.cast_at(shadow).ok, "Cast at fish shadow succeeds")
	var bite_at: float = game.line.bite_at
	game.advance(bite_at + 0.05)
	var catch_res: Dictionary = game.reel()
	_check(catch_res.ok and bool(catch_res.get("new_discovery", false)), "First catch marks species as new discovery")
	_check(game.is_discovered(expected_species) and game.discovered_count() == 1, "Discovered species recorded once")

	# Sell all fish and reload from disk.
	var quote: Dictionary = game.sale_preview()
	_check(quote.ok and game.confirm_sale().ok, "Sale succeeds")
	_check(game.inventory.is_empty(), "Fish bag cleared after sale")
	_check(game.is_discovered(expected_species), "Discovery remains after selling")

	var reloaded_profile := Profile.new(town_path, 11)
	var reloaded_game := Fishing.new("", 57)
	reloaded_game.attach_town_profile(reloaded_profile)
	_check(reloaded_game.inventory.is_empty(), "Reloaded bag remains empty after sale")
	_check(reloaded_game.is_discovered(expected_species) and reloaded_game.discovered_count() == 1, "Discovery persists across reload after sale")

	# 4. PhotoBook UI: single tab hides tab bar, shows discovered vs ???, and fits 360x640 & 640x360.
	var host := CanvasLayer.new()
	root.add_child(host)
	var book := PhotoBook.new()
	host.add_child(book)

	var entries: Array[Dictionary] = []
	for fish: Dictionary in Fishing.CATALOG:
		var id := String(fish.id)
		entries.append({
			"id": id,
			"name": String(fish.name),
			"thumb": THUMB_PATH + id + ".png",
			"discovered": reloaded_game.is_discovered(id),
		})
	book.configure_tabs([{
		"id": "fishing",
		"label": "Fishing",
		"title": "Fishing Photo Book",
		"entries": entries,
	}])
	book.open("fishing")
	await process_frame

	var tab_bar := book.find_child("BookTabs", true, false) as Control
	var progress := book.find_child("BookProgress", true, false) as Label
	var panel := book.find_child("BookPanel", true, false) as Control
	var grid := book.find_child("EntryGrid", true, false) as GridContainer
	_check(tab_bar != null and not tab_bar.visible, "Single-tab book hides tab bar (no empty Reef tab)")
	_check(progress != null and progress.text == "1 / 35 discovered", "Book progress reflects discovered count")
	var found_card := book.find_child("Entry_" + expected_species, true, false)
	var found_caption := found_card.find_child("Caption", true, false) as Label if found_card != null else null
	var hidden_species := "goblinshark" if expected_species != "goblinshark" else "goldfish"
	var hidden_card := book.find_child("Entry_" + hidden_species, true, false)
	var hidden_caption := hidden_card.find_child("Caption", true, false) as Label if hidden_card != null else null
	_check(found_caption != null and found_caption.text != "???", "Discovered species displays its real name")
	_check(hidden_caption != null and hidden_caption.text == "???", "Undiscovered species displays ???")

	# Narrow 360x640 viewport fit check.
	root.size = Vector2i(360, 640)
	await process_frame
	var view_rect := book.get_viewport().get_visible_rect()
	var panel_rect := panel.get_global_rect()
	_check(grid.columns == 2, "360px viewport uses 2-column grid")
	_check(panel_rect.position.x >= 0.0 and panel_rect.end.x <= view_rect.size.x + 1.0 and panel_rect.end.y <= view_rect.size.y + 1.0, "Book fits cleanly in 360x640 viewport: %s in %s" % [panel_rect, view_rect.size])

	# Short 640x360 landscape viewport fit check.
	root.size = Vector2i(640, 360)
	await process_frame
	view_rect = book.get_viewport().get_visible_rect()
	panel_rect = panel.get_global_rect()
	_check(panel_rect.position.x >= 0.0 and panel_rect.end.x <= view_rect.size.x + 1.0 and panel_rect.end.y <= view_rect.size.y + 1.0, "Book fits cleanly in 640x360 viewport: %s in %s" % [panel_rect, view_rect.size])

	# Multi-tab readiness check (for future Reef tab).
	book.configure_tabs([
		{"id": "fishing", "label": "Fishing", "title": "Fishing Photo Book", "entries": entries},
		{"id": "reef", "label": "Reef", "title": "Reef Photo Book", "entries": []},
	])
	book.open("reef")
	await process_frame
	_check(tab_bar.visible and book.active_tab_id() == "reef", "Multi-tab mode reveals tab bar and opens requested tab")

	host.queue_free()
	for p: String in [legacy_path, legacy_path + ".bak", town_path, town_path + ".bak"]:
		var abs_path := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)

	if failures == 0:
		print("PASS: Fishing Photo Book persistence, old-save safety, sale retention, and responsive UI")
	quit(failures)


func _check(result: bool, detail: String) -> void:
	if not result:
		failures += 1
		push_error(detail)
