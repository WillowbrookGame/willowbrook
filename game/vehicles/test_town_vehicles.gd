extends SceneTree

const VEHICLES = preload("res://game/vehicles/town_vehicles.gd")
const PLAYER = preload("res://game/player.gd")

class Wallet extends Node:
	var profile := {"stars":120,"fish":["goldfish"]}
	var allow_commit := true
	func profile_snapshot() -> Dictionary:
		return profile.duplicate(true)
	func profile_commit(next: Dictionary) -> bool:
		if not allow_commit:
			return false
		profile = next.duplicate(true)
		return true

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var wallet := Wallet.new()
	root.add_child(wallet)
	var world := Node3D.new()
	wallet.add_child(world)
	var body := PLAYER.new()
	body.world_bounds = Vector2(80,62)
	world.add_child(body)
	var avatar := Node3D.new()
	body.add_child(avatar)
	var hud := CanvasLayer.new()
	world.add_child(hud)
	var module := VEHICLES.new()
	world.add_child(module)
	module.setup(wallet,body,avatar,hud)
	module.set_physics_process(false)
	await physics_frame
	_check(module.parked.size()==3,"Three shared scooters are staged in town")
	_check(VEHICLES.is_vehicle_ground(Vector3(-20,0,8.6)) and not VEHICLES.is_vehicle_ground(Vector3(-28,0,8)),"Scooter bay can connect to the road, not the lawn")
	_check(VEHICLES.is_vehicle_ground(Vector3(44.5,0,6)) and not VEHICLES.is_vehicle_ground(Vector3(44.9,0,6)),"East paved driveway allowed, neighboring lawn blocked")
	_check(VEHICLES.is_vehicle_ground(Vector3(-61.8,0,6)) and not VEHICLES.is_vehicle_ground(Vector3(-62.4,0,6)),"West paved driveway allowed, neighboring lawn blocked")
	_check((body.collision_mask & VEHICLES.VEHICLE_LAYER) != 0,"Town pedestrians include the parked vehicle collision layer")
	body.position = Vector3(-20,0.1,4.7)
	_check(module.interaction_prompt()=="Ride Scooter" and module.interact() and module.is_driving(),"Scooter boards through the interaction")
	_check(not body.is_physics_processing() and body.movement_locked and body.jump_buffer==0 and body.collision_mask==0,"Driving pauses on-foot movement and ignores the mounted vehicle")
	var scooter: CharacterBody3D = module.driven
	var scooter_start := scooter.position
	for i in 13:
		module.step_drive(1.0,0.0,0.1)
	_check(scooter.position.z > scooter_start.z+3.0 and body.position.z==scooter.position.z,"Scooter drives forward out of bay with player following")
	_check(module.interact() and module.is_driving(),"Can't dismount while moving")

	for i in 16:
		module.step_drive(0.0,0.0,0.1)
	scooter.position = Vector3(-20,0.08,5)
	_check(module.interact() and not module.is_driving() and body.is_physics_processing() and not body.movement_locked,"Stopping lets the rider dismount")
	_check(module.in_scooter_bay(scooter.position) and wallet.profile.stars==120 and (body.collision_mask & VEHICLES.VEHICLE_LAYER) != 0,"Returning scooter restores walking collision and parks it for free")
	body.position = VEHICLES.LOT
	_check(module.interaction_prompt()=="Shop at Willow Wheels" and module.interact() and module.is_modal_open(),"Willow Wheels opens the car offer")
	wallet.allow_commit = false
	module.purchase.pressed.emit()
	_check(wallet.profile.stars==120 and module.owned_car==null,"Failed purchase doesn't debit or spawn a car")
	wallet.allow_commit = true
	module.purchase.pressed.emit()
	_check(wallet.profile.stars==90 and wallet.profile.ownedCar.tier==0 and wallet.profile.fish.size()==1 and module.owned_car!=null,"30-star purchase atomically persists vehicle and stars")
	var car: CharacterBody3D = module.owned_car
	body.position = car.position + Vector3(0,0,1.3)
	_check(module.interaction_prompt()=="Drive My Car" and module.interact() and module.hides_avatar(),"Purchased car becomes drivable")
	var start := car.position
	for i in 10:
		module.step_drive(1.0,0.0,0.1)
	_check(car.position.x < start.x-2.0,"Car drives along its road")
	for i in 28:
		module.step_drive(0.0,0.0,0.1)
	var parked_at := car.position
	_check(module.interact() and not module.is_driving(),"Car can park and driver can exit")
	_check(is_equal_approx(float(wallet.profile.ownedCar.x),parked_at.x),"Parking persists the car position")
	body.position = VEHICLES.LOT
	module.interact()
	module.purchase.pressed.emit()
	_check(wallet.profile.stars==30 and wallet.profile.ownedCar.tier==1 and is_equal_approx(module.owned_car.position.x,parked_at.x),"Upgrade charges 60 stars and keeps the parking spot")
	module.queue_free()
	await process_frame
	var reloaded := VEHICLES.new()
	world.add_child(reloaded)
	reloaded.setup(wallet,body,avatar,hud)
	_check(reloaded.owned_car.get_meta("tier")==1 and is_equal_approx(reloaded.owned_car.position.x,parked_at.x),"Reload reconstructs car and parked position")
	print("Town vehicle checks: ", failures, " failures")
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

