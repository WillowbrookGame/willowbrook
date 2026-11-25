extends "res://game/interiors/room.gd"

const BANK_ART := preload("res://game/bank/room_art.gd")
const CLERK_PROMPT := "Talk to the teller"
var _bank_request_until := 0

func setup(room_id: String, room_host: Node3D, body_player: CharacterBody3D, room_hud: CanvasLayer) -> void:
	super.setup(room_id,room_host,body_player,room_hud)
	var account := _account()
	if account!=null and account.has_signal("pet_result") and account.has_signal("bank_result"):
		account.bank_result.connect(_bank_result)

func _room_title(key: String) -> String:
	return "Willow Bank" if key == "bank" else ""

func _new_room_art() -> ART:
	return BANK_ART.new()

func _welcomes_visitors() -> bool:
	return true

func _fallback_seats() -> Array:
	return [Vector3(-6,0,1),Vector3(-6,0,3.5)]

func _publishes_sitting() -> bool:
	return true

func _clerk_prompt() -> String:
	return CLERK_PROMPT

func _interact_room_specific(prompt: String) -> bool:
	if prompt != CLERK_PROMPT: return false
	_bank_menu()
	return true

func _refresh_hire_menu() -> void:
	if active_panel == "bank": _bank_menu(false)
	else: super._refresh_hire_menu()

func _before_close_panel() -> void:
	if active_panel == "bank": feedback("Have a nice day!")

func _on_room_service_success(action: String, operation: String) -> void:
	if active_panel=="bank" and action=="housing" and operation=="claim": _bank_menu(false)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(host): return
	if _bank_request_until>0 and Time.get_ticks_msec()>_bank_request_until:
		_bank_request_until=0
		if active_panel=="bank" and is_modal_open():
			_bank_menu(false)
			feedback("No receipt yet. Check the same request without paying twice.")
	super._process(delta)

func _bank_menu(reset := true) -> void:
	var account := _account()
	if account!=null and account.has_method("pets_available") and account.pets_available():
		_online_bank(reset,account)
		return
	var p := _snapshot()
	var home: Dictionary = p.get("home",{})
	var loan: Dictionary = p.get("loan",{})
	var stars: int = p.get("stars",0)
	var owed := int(loan.get("balance",0))
	_open_panel("bank","Willow Bank","Play stars only. No interest, deadlines, fees, or penalties. Housing in this browser preview lasts for this session only." if _account()!=null else "Play stars only. Home loans have no interest, deadlines, fees, or penalties.",reset)
	_label("You have %d stars." % stars)
	_hire_button("bank")
	if home.is_empty():
		var eligible := not _memberships(p).is_empty()
		_label("Get hired to qualify for a 100-star starter home loan." if not eligible else "Choose a starter plot. You move in right away.")
		var plots := OptionButton.new()
		fields.add_child(plots)
		for i in range(6): plots.add_item("Plot %d" % (i+1),i)
		var apply := _button("Apply for starter home",func():
			var next := _snapshot()
			if not _memberships(next).is_empty() and next.get("home",{}).is_empty():
				next.home = {"plot":plots.get_selected_id(),"variant":"starter"}
				next.loan = {"principal":100,"balance":100}
				if _commit(next,"You have a starter home!"): _bank_menu(false)
		)
		apply.disabled = not eligible
	elif owed > 0:
		_label("Home %d · %s · %d of %d stars to repay." % [int(home.get("plot",0))+1,str(home.get("variant","starter")).capitalize(),owed,int(loan.get("principal",owed))])
		if stars<=0:
			_label("Earn stars before making a loan payment.")
		else:
			var maximum := mini(stars,owed)
			var custom := _spinner("Payment in stars",1,maximum,mini(10,maximum))
			_button("Make payment",func(): _repay(int(custom.value)))
			if maximum == owed and maximum > 1:
				_button("Pay off loan (%d stars)" % owed,_repay.bind(owed))
	else:
		match str(home.get("variant","starter")):
			"starter": _button("Apply for cottage upgrade · 200 stars",_upgrade.bind("cottage",200))
			"cottage": _button("Apply for family home upgrade · 300 stars",_upgrade.bind("family",300))
			_: _label("Your family home is fully paid and upgraded.")

func _repay(amount: int) -> void:
	var next := _snapshot()
	var loan: Dictionary = next.get("loan",{})
	var owed: int = loan.get("balance",0)
	if amount<1 or amount>owed or amount>int(next.get("stars",0)):
		feedback("Choose a payment within your balance and loan amount.")
		return
	next.stars -= amount
	loan.balance = owed-amount
	if _commit(next,"Paid %d stars toward your home." % amount): _bank_menu(false)

func _upgrade(variant: String, cost: int) -> void:
	var next := _snapshot()
	if int(next.get("loan",{}).get("balance",0))>0 or next.get("home",{}).is_empty(): return
	next.home.variant = variant
	next.loan = {"principal":cost,"balance":cost}
	if _commit(next,"Your %s is ready to move into." % variant): _bank_menu(false)

func _online_bank(reset: bool,account: Node) -> void:
	_open_panel("bank","Willow Bank","Play stars only. The 100-star starter mortgage has no upfront cost, interest, deadlines, fees, or penalties.",reset)
	_label("You have %d saved stars." % account.saved_stars())
	_hire_button("bank")
	var home: Dictionary = account.saved_home()
	if not home.is_empty():
		var mortgage: Dictionary = account.saved_mortgage()
		_label("You own plot %d (%s)." % [int(home.plot)+1,str(home.variant).capitalize()])
		if mortgage.is_empty():
			_label("No current mortgage information is available.")
			return
		if account.pending_bank_action():
			var retry := _button("Check the same Bank request",_online_bank_action.bind("retry",null))
			retry.disabled = _bank_request_until>0
			return
		var owed := int(mortgage.get("balance",0))
		if owed>0:
			_label("%d of %d stars remain on the mortgage." % [owed,int(mortgage.get("principal",owed))])
			var maximum := mini(owed,int(account.saved_stars()))
			if maximum<1:
				_label("Earn stars before making a loan payment.")
				return
			var payment := _spinner("Payment in stars",1,maximum,mini(10,maximum))
			_button("Make payment",func(): _online_bank_action("repay",int(payment.value)))
			if maximum==owed and maximum>1:
				_button("Pay off loan (%d stars)" % owed,_online_bank_action.bind("repay",owed))
			return
		var variant: String = {"starter":"cottage","cottage":"family"}.get(home.variant,"")
		if variant.is_empty():
			_label("This mortgage is fully paid." if home.variant!="family" else "Your family home is fully paid and upgraded.")
			return
		var spec: Dictionary = DATA.data.homeVariants.get(variant,{})
		var rooms := int(spec.get("rooms",0))
		if rooms!=(2 if variant=="cottage" else 3) or int(spec.get("cost",0))!=(200 if variant=="cottage" else 300):
			_label("The next home upgrade is not available in this build.")
			return
		_label("Add room %d inside and upgrade the outside of your current home." % rooms)
		_button("Upgrade to %s (%d-star loan)" % [variant.capitalize(),int(spec.cost)],_online_bank_action.bind("upgrade",variant))
		return
	var plots := OptionButton.new()
	for row: Dictionary in account.homes_for_bank():
		if not bool(row.available): continue
		plots.add_item("Plot %d" % (int(row.plot)+1),int(row.plot))
	fields.add_child(plots)
	var eligible: bool = account.eligible_for_home()
	if not eligible: _label("Get hired for a regular job to qualify for a starter home.")
	if plots.item_count==0: _label("No starter plots are available.")
	var claim := _button("Apply for starter home",func(): _online_pet_action("housing","claim",plots.get_selected_id()))
	claim.disabled = not eligible or plots.item_count==0

func _online_bank_action(operation: String, argument: Variant) -> void:
	if _bank_request_until>0: return
	var account := _account()
	if account==null or not account.has_method("bank_command") or not account.bank_command(operation,argument):
		feedback("Could not send your Bank request. Check your connection and mortgage.")
		return
	_bank_request_until=Time.get_ticks_msec()+8000
	_bank_menu(false)
	feedback("Checking with Willow Bank.")

func _bank_result(text: String) -> void:
	_bank_request_until=0
	if active_panel=="bank" and is_modal_open():
		_bank_menu(false)
		if not text.is_empty(): feedback(text)
