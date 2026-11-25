extends "res://game/interiors/room.gd"

const STORE_ART := preload("res://game/store/room_art.gd")
const CLERK_PROMPT := "Talk to the shopkeeper"

func _room_title(key: String) -> String:
	return "Town Store" if key == "store" else ""

func _new_room_art() -> ART:
	return STORE_ART.new()

func _uses_furniture_account() -> bool:
	return true

func _desk() -> Vector3:
	return Vector3(0,0,-1.8)

func _clerk_prompt() -> String:
	return CLERK_PROMPT

func _interact_room_specific(prompt: String) -> bool:
	if prompt != CLERK_PROMPT: return false
	_store_menu()
	return true

func _refresh_hire_menu() -> void:
	if active_panel == "store": _store_menu(false)
	else: super._refresh_hire_menu()

func _on_furniture_result(ok: bool, message: String) -> void:
	if ok and is_modal_open() and active_panel == "store":
		_store_menu(false)
	feedback(message)

func _near_clerk() -> bool:
	var actor := art.conversation_actor
	if not is_instance_valid(actor):
		return false
	var at := player.global_position
	var npc_at := actor.global_position
	# Remain on the public side of the desk. Eye-level sight crosses low counters,
	# but not partitions, cabinets, or walls.
	if at.z <= npc_at.z + .45:
		return false
	# The Store register is a solid 1.65m prop. At its normal checkout
	# queue, terminate LOS on the customer-side counter, not inside the till.
	if absf(at.x) <= 1.9 and at.z >= -2.35 and at.z <= -.3:
		return PROX.visible_from(self,at,npc_at,4.75,Vector3(0,0,-2.35),[player.get_rid()])
	return PROX.visible_from(self,at,npc_at,4.75,npc_at,[player.get_rid()])

func _store_menu(reset := true) -> void:
	var p := _snapshot()
	_open_panel("store","Town Store · Furniture","Order furnishings with stars. Collect the package outside your front door before decorating.",reset)
	_hire_button("store")
	_hire_button("delivery")
	if p.get("home",{}).is_empty():
		_label("Get a home at Willow Bank first.")
		return
	var account := _account()
	_label("Saved stars: %d" % account.saved_stars() if account != null and account.furniture_available() else "You have %d stars." % int(p.get("stars",0)))
	var selector := OptionButton.new()
	selector.fit_to_longest_item = false
	fields.add_child(selector)
	var kinds: Array[String] = []
	for kind: String in DATA.data.furnitureCatalog:
		var spec: Dictionary = DATA.data.furnitureCatalog[kind]
		if spec.get("rewardOnly",false): continue
		kinds.append(kind)
		selector.add_item("%s · %d stars each" % [spec.name,int(spec.price)])
	var amount := _spinner("Copies",1,10,1)
	var total := _label("")
	var update := func(_value: float): total.text = "Total: %d stars" % (int(DATA.data.furnitureCatalog[kinds[selector.selected]].price)*int(amount.value))
	selector.item_selected.connect(update)
	amount.value_changed.connect(update)
	update.call(0.0)
	_button("Order furniture",func(): _place_order(kinds[selector.selected],int(amount.value)))
	if account != null and account.furniture_available():
		var resale := OptionButton.new()
		resale.fit_to_longest_item = false
		var sell_rows: Array[Dictionary] = []
		for item: Dictionary in p.get("furniture",[]):
			var spec: Dictionary = DATA.data.furnitureCatalog.get(item.get("kind",""),{})
			if item.has("x") or spec.is_empty() or spec.get("rewardOnly",false): continue
			sell_rows.append(item)
			resale.add_item("%s: %d stars each" % [spec.name,int(spec.price)/2])
		if sell_rows.is_empty():
			resale.free()
			_label("No packed furniture to resell. Trophies cannot be sold.")
		else:
			_label("Resell packed furniture")
			fields.add_child(resale)
			var copies := _spinner("Copies to sell",1,mini(10,int(sell_rows[0].quantity)),1)
			resale.item_selected.connect(func(index: int):
				copies.max_value = mini(10,int(sell_rows[index].quantity))
				copies.value = 1
			)
			_button("Sell selected furniture",func(): _send_furniture("sell",{"kind":str(sell_rows[resale.selected].kind),"quantity":int(copies.value)}))

func _place_order(kind: String, quantity: int) -> void:
	var p := _snapshot()
	var spec: Dictionary = DATA.data.furnitureCatalog.get(kind,{})
	if quantity<1 or quantity>10 or p.get("home",{}).is_empty() or spec.is_empty() or spec.get("rewardOnly",false): return
	var account := _account()
	if account != null:
		if not account.furniture_available():
			feedback("Reconnect to order saved furniture.")
			return
		_send_furniture("buy",{"kind":kind,"quantity":quantity})
		return
	var cost := quantity*int(spec.price)
	if cost>int(p.get("stars",0)):
		feedback("You need %d stars for this order." % cost)
		return
	p.stars -= cost
	var deliveries: Array = p.get("deliveries",[])
	deliveries.append({"kind":kind,"quantity":quantity})
	p.deliveries = deliveries
	if _commit(p,"Order placed. Collect it outside your front door."): _store_menu(false)
