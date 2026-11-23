extends SceneTree

const FISH = preload("res://game/fishing_game.gd")
const PROFILE = preload("res://game/progression/profile.gd")
var failure := false

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failure = true

func _initialize() -> void:
	var test_path := "user://wallet-port-%d" % OS.get_process_id()
	var town_path := test_path + "-town.cfg"
	var fish_path := test_path + "-fish.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("profile","stars",18)
	cfg.set_value("profile","fish",["goldfish"])
	check(cfg.save(fish_path)==OK,"Couldn't create disposable legacy fishing save")
	var profile := PROFILE.new(town_path,26)
	check(profile.change_stars(3),"Could not add town stars")
	var beach := FISH.new(fish_path,39)
	beach.attach_town_profile(profile)
	check(profile.get_stars()==21 and beach.stars==21 and beach.inventory.size()==1,"Legacy fish and stars weren't merged")
	var again := FISH.new(fish_path,39)
	again.attach_town_profile(profile)
	check(profile.get_stars()==21 and again.inventory.size()==1,"Legacy stars or fish were imported twice")
	check(again.sale_preview().ok and again.confirm_sale().ok,"Can't sell a migrated fish")
	var reloaded := PROFILE.new(town_path,26)
	check(reloaded.get_stars()==22 and reloaded.snapshot().fish.is_empty(),"Fishing sale didn't reach unified wallet")
	check(FileAccess.file_exists(fish_path),"Original save must be retained")
	for suffix in [fish_path,town_path,town_path+".bak",town_path+".tmp"]:
		if FileAccess.file_exists(suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(suffix))
	if not failure:
		print("PASS: preserved local fishing save, one-time migration, unified atomic sale")
	quit(1 if failure else 0)
