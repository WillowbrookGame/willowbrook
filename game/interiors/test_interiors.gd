extends SceneTree
const ROOM := preload("res://game/interiors/room.gd")
const SALON_ROOM := preload("res://game/salon/room.tscn")
const CAFE_ROOM := preload("res://game/cafe/room.tscn")
const STORE_ROOM := preload("res://game/store/room.tscn")
const LIBRARY_ROOM := preload("res://game/library/room.tscn")
const BANK_ROOM := preload("res://game/bank/room.tscn")
const VET_ROOM := preload("res://game/vet/room.tscn")
class MockProfile extends RefCounted:
	var data := {"stars":150,"employed":"bank","home":{},"loan":{},"classes":{},"pet":{},"furniture":[],"deliveries":[]}
	func take_class(name_: String, amount: int) -> Dictionary:
		if amount>int(data.stars): return {"ok":false,"text":"Not enough stars"}
		data.stars -= amount
		data.classes[name_]={"tier":1,"paid":0}
		return {"ok":true,"text":"Course complete"}
	func prompt(_zone: String,_at: Vector3) -> String: return ""
class MockHost extends Node3D:
	var profile := MockProfile.new()
	var modal := false
	var returned := false
	func profile_snapshot() -> Dictionary: return profile.data.duplicate(true)
	func profile_commit(next: Dictionary) -> bool:
		profile.data=next.duplicate(true)
		return true
	func go_to_town() -> void: returned=true
	func set_zone_modal(value: bool) -> void: modal=value

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(pass_: bool, message: String) -> void:
	if not pass_:
		failures += 1
		push_error(message)

func _button(room: Node3D, caption: String) -> Button:
	for child in room.fields.find_children("*","Button",true,false):
		if child.text==caption: return child
	return null

func _run() -> void:
	var host := MockHost.new()
	root.add_child(host)
	for zone: String in ["bank","vet","library","store","salon","cafe","home"]:
		var pc := CharacterBody3D.new()
		var hud := CanvasLayer.new()
		host.add_child(pc)
		host.add_child(hud)
		var room = VET_ROOM.instantiate() if zone=="vet" else (BANK_ROOM.instantiate() if zone=="bank" else LIBRARY_ROOM.instantiate() if zone=="library" else STORE_ROOM.instantiate() if zone=="store" else CAFE_ROOM.instantiate() if zone=="cafe" else SALON_ROOM.instantiate() if zone=="salon" else ROOM.new())
		host.add_child(room)
		room.setup(zone,host,pc,hud)
		_check(room.art.get_child_count()>10,"Room art missing: "+zone)
		pc.position=room.spawn_position()
		_check(not room.is_modal_open(),"Opened modal on entering")
		await physics_frame
		var settings := PhysicsRayQueryParameters3D.create(pc.position+Vector3.UP,pc.position+Vector3.DOWN)
		_check(not pc.get_world_3d().direct_space_state.intersect_ray(settings).is_empty(),"No room floor at spawn")
		pc.position=room._desk() if zone!="home" else Vector3(0,0,2)
		_check(room.interact() and host.modal,"No interaction: "+zone)
		match zone:
			"bank":
				var loan := _button(room,"Apply for starter home")
				_check(loan!=null and not loan.disabled,"Starter mortgage unavailable")
				loan.pressed.emit()
				_check(host.profile.data.home.variant=="starter" and host.profile.data.loan.balance==100,"Starter loan not applied")
				room._repay(10)
				_check(host.profile.data.stars==140 and host.profile.data.loan.balance==90,"Repayment not saved")
			"vet":
				var adopt := _button(room,"Adopt · 8 stars")
				_check(adopt!=null and not adopt.disabled,"Adoption unavailable")
				adopt.pressed.emit()
				_check(host.profile.data.pets.owned.size()==1 and host.profile.data.stars==132,"Pet purchase not recorded")
			"library":
				room._pay_class("delivery",50)
				_check(host.profile.data.stars==82 and host.profile.data.classes.delivery.tier==1,"Tuition not recorded")
			"store":
				room._place_order("chair",2)
				_check(host.profile.data.deliveries.size()==1 and host.profile.data.stars==78,"Furniture order not recorded")
			"home":
				host.profile.data.furniture=[{"kind":"chair","quantity":2}]
				room._home_menu()
				room._place_furniture(0,0,2.5,-2,0)
				_check(host.profile.data.furniture.size()==2 and host.profile.data.furniture[1].has("x"),"Furniture placement not recorded")
				room.close_modal()
				pc.position=Vector3(2.5,0,-.8)
				var prior := pc.position
				room.interact()
				_check(room.seated and not pc.is_physics_processing(),"Seat interaction did not stop physics")
				room.interact()
				_check(not room.seated and pc.position.is_equal_approx(prior),"Standing did not restore position")
				room._pack_furniture(1)
				_check(host.profile.data.furniture[0].quantity==2,"Packing did not return stock")
				host.profile.data.furniture=[{"kind":"table","quantity":1},{"kind":"books","quantity":1}]
				room._place_furniture(0,0,2.5,-2,0)
				var surface: Dictionary=ROOM.DATA.data.furnitureSurfaces.table[0]
				room._place_furniture(0,0,2.5,-2,0,{"index":1,"surface":surface})
				_check(host.profile.data.furniture[1].get("supportId","")==host.profile.data.furniture[0].id,"Books did not place on table")
				room._pack_furniture(0)
				_check(host.profile.data.furniture.size()==2 and not host.profile.data.furniture[1].has("supportId"),"Packing table did not return its books")
		room.close_modal()
		_check(not host.modal,"Room did not dismiss overlay")
		pc.position=Vector3(0,0,4.35 if zone=="home" else 6.55)
		host.returned=false
		_check(room.interact() and host.returned,"Room exit failed: "+zone)
		room.queue_free(); hud.queue_free(); pc.queue_free()
		await process_frame
	print("ROOMS: bank, vet, library, store, salon, cafe, home; floor, doors, economy, furniture/rest")
	quit(failures)
