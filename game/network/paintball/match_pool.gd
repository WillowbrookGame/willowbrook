extends Node
## Private in-process authority pool; only a trusted broker may supply membership slots.
const MATCH = preload("res://game/network/paintball/match_authority.gd")
const MAX_ROOMS := 3
const RESULTS_HOLD_MS := 90000
var manual_clock := false
var _rooms: Dictionary = {}

func now_ms() -> int:
	return Time.get_ticks_msec()

func create_room(key: String, humans: Array, host_slot: String, now: int) -> bool:
	if _rooms.size()>=MAX_ROOMS or key.is_empty() or key.length()>32 or _rooms.has(key): return false
	var view := SubViewport.new()
	view.size=Vector2i(2,2)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(view)
	var match_room:=MATCH.new()
	view.add_child(match_room)
	if not match_room.open(humans,host_slot,now):
		view.queue_free()
		return false
	_rooms[key]={"world":view,"match":match_room,"ended":-1}
	return true

func room_for_broker(key: String) -> MATCH:
	return _rooms.get(key,{}).get("match") as MATCH

func view_for_member(key: String, slot: String, now: int) -> Dictionary:
	var match_room:=room_for_broker(key)
	return match_room.snapshot(slot,now) if match_room!=null else {}

func remove_room(key: String) -> void:
	var room: Dictionary=_rooms.get(key,{})
	if room.is_empty(): return
	room.world.queue_free()
	_rooms.erase(key)

func advance(dt: float, now: int) -> void:
	for k: String in _rooms.keys():
		var entry: Dictionary=_rooms[k]
		var match_room: MATCH=entry.match
		match_room.step(dt,now)
		if match_room.phase in ["finished","abandoned"] and int(entry.ended)<0:
			entry.ended=now
		if int(entry.ended)>=0 and now-int(entry.ended)>=RESULTS_HOLD_MS:
			remove_room(k)

func _physics_process(delta: float) -> void:
	if not manual_clock: advance(delta,now_ms())
