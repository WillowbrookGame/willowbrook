extends "res://game/interiors/room.gd"

const VET_LAYOUT := preload("res://game/vet/room_layout.tscn")
const CLERK_PROMPT := "Talk to the vet"
var _pet_species_index := 0

func _room_title(key: String) -> String:
	return "Willowbrook Vet" if key == "vet" else ""

func _new_room_art() -> ART:
	return VET_LAYOUT.instantiate() as ART

func _welcomes_visitors() -> bool:
	return true

func _publishes_sitting() -> bool:
	return true

func _clerk_prompt() -> String:
	return CLERK_PROMPT

func _interact_room_specific(prompt: String) -> bool:
	if prompt != CLERK_PROMPT: return false
	_vet_menu()
	return true

func _refresh_hire_menu() -> void:
	if active_panel == "vet": _vet_menu(false)
	else: super._refresh_hire_menu()

func _on_room_pet_success(operation: String) -> void:
	if active_panel == "vet" and operation == "adopt": _vet_menu()

func _vet_menu(reset := true) -> void:
	var account := _account()
	_open_panel("vet","Willowbrook Vet · Adoption","Welcome another pet for 8 stars. You can adopt more than one of each.",reset)
	_hire_button("vet")
	var current := _pet_state()
	_label("Owned pets: %d" % current.get("owned",[]).size())
	if account!=null and (not account.has_method("pets_available") or not account.pets_available()):
		_label("Online pet adoption is unavailable on this server.")
		return
	var kinds := OptionButton.new()
	kinds.fit_to_longest_item=false
	fields.add_child(kinds)
	for kind: String in PETS.SPECIES: kinds.add_item(PETS.display(kind))
	kinds.select(_pet_species_index)
	kinds.item_selected.connect(func(index: int): _pet_species_index=index)
	var adopt := _button("Adopt · 8 stars",func():
		var kind: String=PETS.SPECIES[kinds.selected]
		if account!=null:
			_online_pet_action("pets","adopt",kind)
			return
		var next := _snapshot()
		if int(next.get("stars",0))<PETS.COST:
			feedback("You need 8 stars to adopt.")
			return
		var state := PETS.state(next)
		state.owned.append({"id":Crypto.new().generate_random_bytes(12).hex_encode(),"species":kind})
		next.stars-=PETS.COST
		next.pet={}
		next.pets=state
		if _commit(next,"Your %s was adopted!" % PETS.display(kind)): _vet_menu()
	)
	adopt.disabled=(account.saved_stars() if account!=null else int(_snapshot().get("stars",0)))<PETS.COST
