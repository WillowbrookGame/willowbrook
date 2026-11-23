extends RefCounted

# Quaternius Animated Cute Fish (CC0); retain the original species values.
# Integer tickets out of 1M. Bands: 1-5 = 84%, 6-10 = 10%, 11-19 = 4.5%,
# 20-38 = 1.45%, 40-50 = 0.05%. Each successive species has fewer tickets.
const CATALOG := [
	{"id": "goldfish", "name": "Goldfish", "value": 1, "weight": 480000, "model": "res://assets/beach-fish/Goldfish.glb"},
	{"id": "tetra", "name": "Tetra", "value": 2, "weight": 180000, "model": "res://assets/beach-fish/Tetra.glb"},
	{"id": "bluegoldfish", "name": "Blue Goldfish", "value": 3, "weight": 90000, "model": "res://assets/beach-fish/BlueGoldfish.glb"},
	{"id": "cardinalfish", "name": "Cardinalfish", "value": 4, "weight": 52000, "model": "res://assets/beach-fish/CardinalFish.glb"},
	{"id": "betta", "name": "Betta", "value": 5, "weight": 38000, "model": "res://assets/beach-fish/Betta.glb"},
	{"id": "clownfish", "name": "Clownfish", "value": 6, "weight": 29000, "model": "res://assets/beach-fish/Clownfish.glb"},
	{"id": "zebraclownfish", "name": "Zebra Clownfish", "value": 7, "weight": 23000, "model": "res://assets/beach-fish/ZebraClownFish.glb"},
	{"id": "flatfish", "name": "Flatfish", "value": 8, "weight": 19000, "model": "res://assets/beach-fish/Flatfish.glb"},
	{"id": "tang", "name": "Reef Tang", "value": 9, "weight": 16000, "model": "res://assets/beach-fish/Tang.glb"},
	{"id": "yellowtang", "name": "Yellow Tang", "value": 10, "weight": 13000, "model": "res://assets/beach-fish/YellowTang.glb"},
	{"id": "bluetang", "name": "Blue Tang", "value": 11, "weight": 9500, "model": "res://assets/beach-fish/BlueTang.glb"},
	{"id": "butterflyfish", "name": "Butterflyfish", "value": 12, "weight": 8000, "model": "res://assets/beach-fish/ButterflyFish.glb"},
	{"id": "royalgramma", "name": "Royal Gramma", "value": 13, "weight": 6800, "model": "res://assets/beach-fish/RoyalGramma.glb"},
	{"id": "piranha", "name": "Piranha", "value": 14, "weight": 5500, "model": "res://assets/beach-fish/Piranha.glb"},
	{"id": "redsnapper", "name": "Red Snapper", "value": 15, "weight": 4200, "model": "res://assets/beach-fish/RedSnapper.glb"},
	{"id": "turbot", "name": "Turbot", "value": 16, "weight": 3400, "model": "res://assets/beach-fish/Turbot.glb"},
	{"id": "koi", "name": "Koi", "value": 17, "weight": 3000, "model": "res://assets/beach-fish/Koi.glb"},
	{"id": "flowerhorn", "name": "Flowerhorn", "value": 18, "weight": 2500, "model": "res://assets/beach-fish/FlowerHorn.glb"},
	{"id": "armoredcatfish", "name": "Armored Catfish", "value": 19, "weight": 2100, "model": "res://assets/beach-fish/ArmoredCatfish.glb"},
	{"id": "puffer", "name": "Pufferfish", "value": 20, "weight": 2000, "model": "res://assets/beach-fish/Puffer.glb"},
	{"id": "cowfish", "name": "Cowfish", "value": 22, "weight": 1850, "model": "res://assets/beach-fish/Cowfish.glb"},
	{"id": "coralgrouper", "name": "Coral Grouper", "value": 24, "weight": 1700, "model": "res://assets/beach-fish/CoralGrouper.glb"},
	{"id": "parrotfish", "name": "Parrotfish", "value": 26, "weight": 1570, "model": "res://assets/beach-fish/ParrotFish.glb"},
	{"id": "moorishidol", "name": "Moorish Idol", "value": 28, "weight": 1450, "model": "res://assets/beach-fish/MoorishIdol.glb"},
	{"id": "mandarinfish", "name": "Mandarinfish", "value": 30, "weight": 1350, "model": "res://assets/beach-fish/MandarinFish.glb"},
	{"id": "lionfish", "name": "Lionfish", "value": 32, "weight": 1250, "model": "res://assets/beach-fish/Lionfish.glb"},
	{"id": "blacklionfish", "name": "Black Lionfish", "value": 34, "weight": 1170, "model": "res://assets/beach-fish/BlackLionFish.glb"},
	{"id": "humphead", "name": "Humphead Wrasse", "value": 36, "weight": 1110, "model": "res://assets/beach-fish/Humphead.glb"},
	{"id": "tuna", "name": "Tuna", "value": 38, "weight": 1050, "model": "res://assets/beach-fish/Tuna.glb"},
	{"id": "sunfish", "name": "Ocean Sunfish", "value": 40, "weight": 150, "model": "res://assets/beach-fish/Sunfish.glb"},
	{"id": "swordfish", "name": "Swordfish", "value": 42, "weight": 115, "model": "res://assets/beach-fish/Swordfish.glb"},
	{"id": "blobfish", "name": "Blobfish", "value": 44, "weight": 90, "model": "res://assets/beach-fish/Blobfish.glb"},
	{"id": "anglerfish", "name": "Anglerfish", "value": 46, "weight": 65, "model": "res://assets/beach-fish/Anglerfish.glb"},
	{"id": "shark", "name": "Reef Shark", "value": 48, "weight": 45, "model": "res://assets/beach-fish/Shark.glb"},
	{"id": "goblinshark", "name": "Goblin Shark", "value": 50, "weight": 35, "model": "res://assets/beach-fish/GoblinShark.glb"},
]

const MAX_FISH := 500
const BITE_REACH := 4.5
const CAST_FLIGHT := 0.58
const WAIT_EMPTY := 20.0
const REEL_WINDOW := 2.5
const SALE_LIFETIME := 60.0

var equipped := false
var line: Dictionary = {}
var population: Array[Dictionary] = []
var inventory: Array[String] = []
var stars := 0

var _spots: Array[Vector3] = []
var _water_validator := Callable()
var _rng := RandomNumberGenerator.new()
var _by_type: Dictionary = {}
var _weight_total := 0
var _time := 0.0
var _next_refresh := INF
var _next_id := 0
var _quote: Dictionary = {}
var _save_path: String
var _profile_valid := true


func _init(save_path: String = "user://fishing_profile.cfg", random_seed: int = -1) -> void:
	_save_path = save_path
	if random_seed < 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	for fish: Dictionary in CATALOG:
		_by_type[fish.id] = fish
		_weight_total += fish.weight
	_load_profile()


func start_population(spots: Array[Vector3] = [], water_validator: Callable = Callable()) -> void:
	_water_validator = water_validator
	_spots = spots.duplicate()
	if _spots.is_empty():
		for x: int in [-52, -44, -36, -28, -20, -12, 12, 20, 44, 52]:
			_spots.append(Vector3(x, 0.0, -3))
		for z: int in [-4, -12, -20, -28]:
			_spots.append(Vector3(-5, 0.0, z))
			_spots.append(Vector3(5, 0.0, z))
		for z: int in [-4]:
			_spots.append(Vector3(25, 0.0, z))
			_spots.append(Vector3(39, 0.0, z))
		_spots.append(Vector3(23.5, 0.0, -10))
		_spots.append(Vector3(40.5, 0.0, -10))
	population.clear()
	cancel_cast()
	for i: int in range(_rng.randi_range(2, 10)):
		_spawn_fish()
	_schedule_refresh()


func equip_pole() -> Dictionary:
	equipped = true
	return _reply(true, "Fishing pole ready!")


func put_away() -> Dictionary:
	equipped = false
	_quote.clear()
	return cancel_cast()


# The arena controller only calls this for targets on valid water.
func cast_at(target: Vector3) -> Dictionary:
	if not equipped:
		return _reply(false, "Pick up a fishing pole first.")
	if not target.is_finite() or not _is_water(target):
		return _reply(false, "Aim the line at the water.")
	if not line.is_empty():
		return _reply(false, "Reel in your current line first.")
	if inventory.size() >= MAX_FISH:
		return _reply(false, "Your fish bag is full. Sell your fish at the snack shop.")
	var nearest: Dictionary = {}
	var best_distance := BITE_REACH
	for fish: Dictionary in population:
		var distance := _water_distance(fish.position, target)
		if distance <= best_distance and _clear_water_path(fish.position, target):
			best_distance = distance
			nearest = fish
	if nearest.is_empty():
		line = {
			"position": target, "fish_id": -1, "empty": true,
			"age": 0.0, "flight_time": CAST_FLIGHT, "remaining": WAIT_EMPTY + CAST_FLIGHT, "expires_at": WAIT_EMPTY + CAST_FLIGHT,
		}
		return _reply(true, "Line cast. Reel in any time to try another spot.")
	var bite_time := CAST_FLIGHT + _rng.randf_range(4.0, 8.0)
	var nibble_times: Array[float] = []
	for i: int in range(_rng.randi_range(1, 3), 0, -1):
		nibble_times.append(bite_time - i * 0.9)
	line = {
		"position": target, "fish_id": nearest.id, "empty": false,
		"age": 0.0, "flight_time": CAST_FLIGHT, "bite_at": bite_time, "nibbles": nibble_times,
		"remaining": bite_time + REEL_WINDOW, "expires_at": bite_time + REEL_WINDOW,
	}
	return _reply(true, "Watch the bobber. Reel in when it goes under!")


func phase() -> String:
	if line.is_empty():
		return "idle"
	if line.age < CAST_FLIGHT:
		return "casting"
	if not line.empty:
		if line.age >= line.bite_at and line.age <= line.expires_at:
			return "bite"
		for nibble: float in line.nibbles:
			if line.age >= nibble and line.age < nibble + 0.22:
				return "nibble"
	return "waiting"


func reel() -> Dictionary:
	if line.is_empty():
		return _reply(false, "Cast your line first.")
	if line.empty:
		line.clear()
		return _reply(false, "No fish took the bait.")
	var was_bite := phase() == "bite"
	var was_late: bool = line.age > line.expires_at
	var fish := _fish_by_id(line.fish_id)
	line.clear()
	if fish.is_empty():
		return _reply(false, "That fish swam away.")
	_remove_fish(fish)
	if not was_bite:
		return _reply(false, "The fish got away." if was_late else "Too soon! Wait for the bite before reeling.")
	var kind: Dictionary = _by_type[fish.type]
	inventory.append(kind.id)
	if not _save_profile(0):
		inventory.pop_back()
		return _reply(false, "Couldn't save your catch. No fish was added.")
	_quote.clear()
	var result := _reply(true, "Caught a %s!" % kind.name)
	result["caught"] = kind.duplicate()
	return result


func cancel_cast() -> Dictionary:
	if line.is_empty():
		return {}
	var fish := _fish_by_id(line.fish_id)
	if not fish.is_empty():
		_remove_fish(fish)
	var empty: bool = line.empty
	line.clear()
	return _reply(true, "No fish took the bait." if empty else "Line reeled in.")


func advance(delta: float) -> Dictionary:
	if not is_finite(delta) or delta <= 0.0:
		return {}
	_time += delta
	if _time >= _next_refresh:
		_refresh_population()
	var previous := phase()
	if not line.is_empty():
		line.age += delta
	_swim(delta)
	if line.is_empty():
		return {}
	line.remaining = maxf(0.0, line.expires_at - line.age)
	if line.age > line.expires_at:
		var fish := _fish_by_id(line.fish_id)
		if not fish.is_empty():
			_remove_fish(fish)
		var empty: bool = line.empty
		line.clear()
		return _reply(false, "No fish took the bait." if empty else "The fish got away. Try another cast.")
	var current := phase()
	if current == "bite" and previous != "bite":
		return _reply(true, "Bite! Reel in now!")
	return {}


func sale_preview() -> Dictionary:
	if not line.is_empty():
		return _reply(false, "Reel in your line first.")
	if inventory.is_empty():
		return _reply(false, "Your fish bag is empty.")
	var items: Array[Dictionary] = []
	var total := 0
	for id: String in inventory:
		var kind: Dictionary = _by_type[id]
		items.append(kind.duplicate())
		total += int(kind.value)
	_quote = {
		"inventory": inventory.duplicate(), "items": items, "total": total,
		"expires_at": _time + SALE_LIFETIME,
	}
	return {"ok": true, "text": "Review your fish before selling.", "items": items.duplicate(true), "total": total}


func cancel_sale() -> void:
	_quote.clear()


func confirm_sale() -> Dictionary:
	if _quote.is_empty() or _time > _quote.expires_at or inventory != _quote.inventory or not line.is_empty():
		_quote.clear()
		return _reply(false, "Open a fresh fish sale preview.")
	var total: int = _quote.total
	var before := int(_town_profile.snapshot().get("stars",0)) if _town_profile != null else stars
	if before > 9223372036854775807 - total:
		return _reply(false, "Your star balance is full.")
	var sold := inventory.duplicate()
	var items: Array = _quote.items
	stars = before+total
	inventory.clear()
	if not _save_profile(total):
		stars = before
		inventory.assign(sold)
		return _reply(false, "Couldn't save the sale. Your fish and stars haven't changed.")
	_quote.clear()
	# A full combined bag can drain a saved legacy remainder after this sale.
	if _town_profile != null and not _legacy_inventory.is_empty():
		_migrate_legacy()
	return {"ok": true, "text": "Sold %d fish for %d stars!" % [sold.size(), total], "items": items, "total": total}


func _schedule_refresh() -> void:
	_next_refresh = _time + (_rng.randf_range(7.0,11.0) if population.size()<2 else _rng.randf_range(30.0,70.0))


func _remove_fish(fish: Dictionary) -> void:
	population.erase(fish)
	if population.size()<2:
		_next_refresh = minf(_next_refresh,_time+_rng.randf_range(7.0,11.0))


func _refresh_population() -> void:
	var target := _rng.randi_range(2, 10)
	if population.size() < 2:
		while population.size() < 2 and _spawn_fish():
			pass
	elif population.size() < target:
		_spawn_fish()
	elif population.size() > target:
		var free: Array[Dictionary] = []
		for fish: Dictionary in population:
			if line.is_empty() or fish.id != line.fish_id:
				free.append(fish)
		if not free.is_empty():
			population.erase(free[_rng.randi_range(0, free.size() - 1)])
	_schedule_refresh()


func _spawn_fish() -> bool:
	var candidates: Array[Vector3] = []
	for spot: Vector3 in _spots:
		if not _is_water(spot) or (not line.is_empty() and _water_distance(line.position, spot) <= 10.0):
			continue
		var free := true
		for fish: Dictionary in population:
			if _water_distance(fish.position, spot) < 7.0:
				free = false
				break
		if free:
			candidates.append(spot)
	if candidates.is_empty():
		return false
	var kind := _pick_fish()
	var spot := candidates[_rng.randi_range(0, candidates.size() - 1)]
	population.append({
		"id": _next_id, "position": spot, "home": spot, "heading": Vector3.FORWARD,
		"type": kind.id, "size": _rng.randf_range(0.8, 1.2),
	})
	_next_id += 1
	return true


func _swim(delta: float) -> void:
	for fish: Dictionary in population:
		var current: Vector3 = fish.position
		var desired: Vector3
		var speed := 0.9
		if not line.is_empty() and line.fish_id == fish.id and line.age >= CAST_FLIGHT:
			var target: Vector3 = line.position
			target.y = current.y
			var first_nibble: float = line.nibbles[0]
			var offset := current - target
			if offset.length_squared() < 0.01:
				offset = Vector3.BACK
			# Pause just short, then close the final gap for the true bite.
			var radius := 0.62 if line.age < line.bite_at else 0.12
			desired = target + offset.normalized() * radius if offset.length() > radius else target
			if line.age >= first_nibble and line.age < line.bite_at:
				desired = target + offset.normalized() * (0.54 + 0.14 * sin(line.age * 9.0))
			if not _is_water(desired):
				desired = target
			speed = 2.6
		else:
			var drift := _time * 0.53 + float(fish.id) * 2.399
			desired = fish.home + Vector3(sin(drift) * 1.2, 0.0, sin(drift * 0.7) * 0.85)
		var next := current.move_toward(desired, speed * delta)
		if not _clear_water_path(current, next):
			continue
		var movement := next - current
		if movement.length_squared() > 0.00001:
			var heading: Vector3 = fish.heading
			var next_heading := heading.lerp(movement.normalized(), minf(1.0, delta * 5.0))
			fish.heading = next_heading.normalized() if next_heading.length_squared() > 0.00001 else movement.normalized()
			fish.position = next


func _is_water(position: Vector3) -> bool:
	return not _water_validator.is_valid() or bool(_water_validator.call(position))


func _clear_water_path(from: Vector3, to: Vector3) -> bool:
	if not _water_validator.is_valid():
		return true
	var steps := maxi(1, ceili(_water_distance(from, to) / 0.35))
	for i: int in range(1, steps + 1):
		if not _is_water(from.lerp(to, float(i) / float(steps))):
			return false
	return true

 
func _pick_fish() -> Dictionary:
	return _fish_for_ticket(_rng.randi_range(1,_weight_total))


func _fish_for_ticket(ticket: int) -> Dictionary:
	var weight := ticket
	for fish: Dictionary in CATALOG:
		weight -= fish.weight
		if weight <= 0.0:
			return fish
	return CATALOG.back()


func _fish_by_id(id: int) -> Dictionary:
	for fish: Dictionary in population:
		if fish.id == id:
			return fish
	return {}


var _town_profile: RefCounted
var _stored_bag: Array = []
var _legacy_inventory: Array[String] = []
var _legacy_stars := 0
var _legacy_readable := true


## Use one wallet even when the two old saves don't fit in the same bag.
## Migration cursor and legacy-star receipt commit with the merged wallet.
func attach_town_profile(shared: RefCounted) -> void:
	if shared == null:
		return
	var next: Dictionary = shared.snapshot()
	var caught: Array = next.get("fish",[]).duplicate()
	for id in caught:
		if not id is String or not _by_type.has(id):
			_reject_profile()
			return
	_legacy_readable = _profile_valid
	if _legacy_readable:
		_legacy_inventory.assign(inventory)
		_legacy_stars = stars
	_town_profile = shared
	_stored_bag = caught.duplicate()
	inventory.assign(caught)
	stars = int(next.get("stars",0))
	# A corrupt old standalone file is left alone; the shared profile is safe.
	_profile_valid = true
	_migrate_legacy()


func _migrate_legacy() -> void:
	if _town_profile == null or not _legacy_readable:
		return
	var next: Dictionary = _town_profile.snapshot()
	if next.get("fish",[]) != _stored_bag or bool(next.get("fishing_migrated",false)):
		return
	var cursor := clampi(int(next.get("fishing_legacy_cursor",0)),0,_legacy_inventory.size())
	var stop := mini(_legacy_inventory.size(),cursor+MAX_FISH-inventory.size())
	var credit := not bool(next.get("fishing_legacy_stars_paid",false))
	if credit and int(next.get("stars",0)) > 9223372036854775807-_legacy_stars:
		return
	if stop==cursor and stop<_legacy_inventory.size() and not credit:
		return
	var merged := inventory.duplicate()
	for i: int in range(cursor,stop):
		merged.append(_legacy_inventory[i])
	next.fish = merged.duplicate()
	if credit:
		next.stars = int(next.get("stars",0))+_legacy_stars
		next.fishing_legacy_stars_paid = true
	next.fishing_legacy_cursor = stop
	next.fishing_migrated = stop >= _legacy_inventory.size()
	if not _town_profile.commit(next):
		return
	inventory.assign(merged)
	_stored_bag = merged.duplicate()
	stars = int(next.get("stars",0))

func _load_profile() -> void:
	if _save_path.is_empty() or not FileAccess.file_exists(_save_path):
		return
	var config := ConfigFile.new()
	if config.load(_save_path) != OK:
		_reject_profile()
		return
	var saved_fish: Variant = config.get_value("profile", "fish", [])
	var saved_stars: Variant = config.get_value("profile", "stars", 0)
	if not saved_fish is Array or saved_fish.size() > MAX_FISH or not saved_stars is int or saved_stars < 0:
		_reject_profile()
		return
	for id: Variant in saved_fish:
		if not id is String or not _by_type.has(id):
			_reject_profile()
			return
	inventory.assign(saved_fish)
	stars = saved_stars


func _reject_profile() -> void:
	_profile_valid = false
	push_warning("The Godot fishing profile is invalid. It will not be overwritten.")


func _save_profile(star_delta: int) -> bool:
	if _town_profile != null:
		var next: Dictionary = _town_profile.snapshot()
		# Reject stale writes rather than losing another change to the same bag.
		if next.get("fish",[]) != _stored_bag:
			return false
		next.fish = inventory.duplicate()
		next.stars = int(next.get("stars",0))+star_delta
		if not _town_profile.commit(next):
			return false
		_stored_bag = inventory.duplicate()
		stars = int(next.stars)
		return true
	if _save_path.is_empty():
		return true
	if not _profile_valid:
		return false
	var config := ConfigFile.new()
	config.set_value("profile", "fish", inventory)
	config.set_value("profile", "stars", stars)
	var temp := _save_path + ".tmp"
	if config.save(temp) != OK:
		return false
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(_save_path))
	return error == OK


func _water_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _reply(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "text": message}
