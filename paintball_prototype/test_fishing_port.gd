extends SceneTree
## Run headlessly: godot --headless --path . --script test_fishing_port.gd
const Fishing = preload("res://paintball_prototype/fishing_game.gd")
var failures := 0


func _initialize() -> void:
	var save_path := "user://fishing-port-test-%d.cfg" % OS.get_process_id()
	var game := Fishing.new(save_path, 57)
	game.start_population()
	_check(game.population.size() >= 2 and game.population.size() <= 10, "Initial population 2–10")
	_check(Fishing.CATALOG.size() == 35, "All 35 original fish")
	var seen := {}
	var last_value := 0
	var last_weight := INF
	for fish: Dictionary in Fishing.CATALOG:
		_check(not seen.has(fish.id), "Unique fish IDs")
		_check(fish.value > last_value and fish.weight < last_weight, "Rarer fish earn more")
		seen[fish.id] = true
		last_value = fish.value
		last_weight = fish.weight
	_check(last_value == 50, "Top fish worth 50 stars")

	_check_rarity()

	var first_position: Vector3 = game.population[0].position
	game.advance(0.8)
	_check(first_position.distance_to(game.population[0].position) > 0.10, "Unhooked fish swim in the ocean")
	var shadow: Vector3 = game.population[0].position
	_check(not game.cast_at(shadow).ok, "Pole required")
	game.equip_pole()
	var fish_count: int = game.population.size()
	_check(game.cast_at(Vector3(0, 0, -50)).ok and game.line.empty, "Empty water still allows casting")
	_check(not game.reel().ok and fish_count == game.population.size(), "Empty cast cannot catch or spawn a fish")
	var near_shadow := shadow + Vector3(0.25, 0, 0)
	_check(game.cast_at(near_shadow).ok and not game.line.empty, "Existing nearby fish takes the bait")
	_check(game.line.position == near_shadow, "Bobber stays where it lands instead of jumping to the fish")
	_check(not game.reel().ok and game.inventory.is_empty(), "Early reel fails")

	shadow = game.population[0].position
	_check(game.cast_at(shadow).ok, "Second cast works")
	_check(game.phase() == "casting", "Cast starts with visible flight time")
	game.advance(Fishing.CAST_FLIGHT)
	_check(game.phase() == "waiting", "Bobber lands before the nibble window")
	var bite_at: float = game.line.bite_at
	game.advance(bite_at - Fishing.CAST_FLIGHT - 0.899)
	_check(game.phase() == "nibble", "Nibble is indicated before true bite")
	game.advance(0.91)
	_check(game.phase() == "bite" and game.reel().ok, "True bite catches the fish")
	var reloaded := Fishing.new(save_path, 2)
	_check(reloaded.inventory.size() == 1, "Catch persists across loads")
	_check(not game.confirm_sale().ok, "Cannot sell without a quote")
	var preview: Dictionary = game.sale_preview()
	_check(preview.ok and preview.items.size() == 1 and preview.total > 0, "Preview includes item and value")
	_check(game.stars == 0 and game.inventory.size() == 1, "Preview cannot pay")
	game.cancel_sale()
	_check(not game.confirm_sale().ok, "Closing preview cannot pay")
	game.sale_preview()
	game.advance(61)
	_check(not game.confirm_sale().ok, "Expired quote cannot pay")
	var confirmation: Dictionary = game.sale_preview()
	_check(game.confirm_sale().ok and game.stars == confirmation.total and game.inventory.is_empty(), "Confirm pays and clears catches")
	_check(not game.confirm_sale().ok, "Cannot pay twice")
	reloaded = Fishing.new(save_path, 2)
	_check(reloaded.stars == confirmation.total and reloaded.inventory.is_empty(), "Sale persists atomically")
	_check(not reloaded.equipped, "Pole equip state is not shared or persisted")
	var refresh_test := Fishing.new("", 214)
	refresh_test.start_population()
	refresh_test.equip_pole()
	refresh_test.advance(29)
	var empty_water := Vector3(0, 0, -50)
	_check(refresh_test.cast_at(empty_water).ok, "Valid empty-water cast starts")
	refresh_test.advance(15)
	_check(refresh_test.line.empty and refresh_test.phase() == "waiting", "A refresh cannot attach a fish to an existing empty cast")
	refresh_test.advance(6)
	_check(refresh_test.phase() == "idle" and refresh_test.inventory.is_empty(), "Empty cast expires harmlessly")
	var swimmers := Fishing.new("", 214)
	swimmers.start_population()
	swimmers.equip_pole()
	var selected: Dictionary = swimmers.population[0]
	var selected_id: int = selected.id
	var start: Vector3 = selected.position
	var target := start + Vector3(0, 0, -3.8)
	swimmers.cast_at(target)
	_check(swimmers.line.fish_id == selected_id, "Cast selects an existing nearby fish")
	swimmers.advance(Fishing.CAST_FLIGHT + 0.35)
	_check(Vector3(selected.position).distance_to(target) < start.distance_to(target), "Existing fish swims toward the float after splash")
	_check(swimmers.line.position == target, "Bobber does not teleport to approaching fish")
	var blocked := Fishing.new("", 214)
	var test_spots: Array[Vector3] = [Vector3(-2, 0, -5),Vector3(-2, 0, -15)]
	blocked.start_population(test_spots,func(at: Vector3) -> bool: return absf(at.x) > 0.5)
	blocked.equip_pole()
	var blocked_shadow: Vector3 = blocked.population[0].position
	blocked.cast_at(Vector3(2, 0, blocked_shadow.z))
	_check(blocked.line.empty, "Fish cannot approach the bobber through dry ground")
	var late_shadow: Vector3 = refresh_test.population[0].position
	refresh_test.cast_at(late_shadow)
	refresh_test.advance(11)
	_check(refresh_test.phase() == "idle" and refresh_test.inventory.is_empty(), "Late reel cannot catch")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if failures == 0:
		print("Fishing port tests passed.")
	quit(failures)


func _check_rarity() -> void:
	var sampler := Fishing.new("",4589)
	var first := 1
	for fish: Dictionary in Fishing.CATALOG:
		_check(fish.weight > 0 and sampler._fish_for_ticket(first).id == fish.id
			and sampler._fish_for_ticket(first+fish.weight-1).id == fish.id,
			"Every species must be selectable for exactly its assigned ticket interval")
		first += int(fish.weight)
	_check(first == 1000001,"Ticket range matches deployed picker")
	var band_10 := 0
	var band_20 := 0
	var band_40 := 0
	var earned := 0
	var samples := 200000
	for i in samples:
		var value: int = sampler._pick_fish().value
		earned += value
		band_10 += int(value >= 10)
		band_20 += int(value >= 20)
		band_40 += int(value >= 40)
	_check(band_10 >= 13600 and band_10 <= 15600,"Actual picker gives roughly 7.3% 10+")
	_check(band_20 >= 2600 and band_20 <= 3400,"Actual picker gives roughly 1.5% 20+")
	_check(band_40 >= 65 and band_40 <= 135,"Actual picker gives roughly 0.05% 40+")
	_check(float(earned)/samples > 3.2 and float(earned)/samples < 3.45,"Actual picker averages near 3.31 stars")


func _check(result: bool, detail: String) -> void:
	if not result:
		failures += 1
		push_error(detail)
