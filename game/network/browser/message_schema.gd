
extends RefCounted
## Validate backend packets once, before they reach account views or the arcade relay.
const MAX_PACKET_BYTES := 1048576
const REEF_PHOTO_IDS := ["clownfish","bluetang","butterflyfish","coralgrouper","parrotfish","tuna","shark","sunfish"]
const ZONES := ["town","beach","arcade","bank","vet","salon","store","cafe","library","private"]


static func parse(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size() > MAX_PACKET_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(packet.get_string_from_utf8()) != OK:
		return {}
	var body: Variant = parser.data
	return body if valid(body) else {}


static func _num(v: Variant, low: float, high: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) >= low and float(v) <= high


static func _whole(v: Variant, low: float, high: float) -> bool:
	return _num(v,low,high) and floorf(float(v)) == float(v)


static func _text(v: Variant, maximum: int) -> bool:
	return v is String and v.length() <= maximum


static func _nullable_num(v: Variant, low: float, high: float) -> bool:
	return v == null or _whole(v,low,high)


static func _rows(v: Variant, maximum: int, predicate: Callable) -> bool:
	if not v is Array or v.size() > maximum:
		return false
	for row: Variant in v:
		if not predicate.call(row):
			return false
	return true


static func _alias_row(v: Variant) -> bool:
	return v is Dictionary and _text(v.get("alias"),32) and _text(v.get("place"),64)


static func _pose(v: Variant) -> bool:
	return v is Dictionary and v.get("zone") in ZONES and _whole(v.get("id"),1,2147483647) and _text(v.get("alias"),32) and _num(v.get("x"),-240,240) and _num(v.get("y"),-10,25) and _num(v.get("z"),-240,240) and _num(v.get("yaw"),-7,7) and v.get("grounded") is bool and (not v.has("character") or _text(v.character,16)) and v.get("moving") is bool and v.get("rest","") in ["","sit"] and (not v.has("vehicleSeat") or _vehicle_seat(v.vehicleSeat))


static func _marker(v: Variant) -> bool:
	return v is Dictionary and v.get("zone") in ZONES and v.get("zone") != "private" and _num(v.get("x"),-240,240) and _num(v.get("z"),-240,240) and _num(v.get("radius"),0.1,12.0) and _text(v.get("label"),128)


static func _job_marker(v: Variant) -> bool:
	return _marker(v) and _text(v.get("job"),32) and v.get("kind") in ["starter","work","delivery","start","hire"] and v.get("pending") is bool


static func _hunt_marker(v: Variant) -> bool:
	return _marker(v) and _text(v.get("id"),32) and _text(v.get("hint"),180) and _text(v.get("asset"),120)


static func _rank(v: Variant, field: String) -> bool:
	return v is Dictionary and _whole(v.get("rank"),1,50) and _text(v.get("displayName"),32) and _whole(v.get(field),0,9007199254740991.0)


static func _starter_waits(v: Variant) -> bool:
	if v == null:
		return true # Older isolated preview packets show unknown, never a false "ready".
	if not v is Dictionary or v.size() != 4:
		return false
	for id in ["cafe","store","park","garden"]:
		if not _whole(v.get(id),0,300000):
			return false
	return true


static func _job_state(v: Variant) -> bool:
	return v is Dictionary and _text(v.get("status"),180) and v.get("eligible") is bool and _starter_waits(v.get("starterWaitMs")) and (v.get("current")==null or _job_marker(v.current)) and _rows(v.get("memberships"),30,func(r): return _text(r,32)) and _rows(v.get("completed"),12,func(r): return _text(r,32)) and _rows(v.get("available"),40,_job_marker) and _rows(v.get("employers"),12,_job_marker)


static func _hunt_state(v: Variant) -> bool:
	if not v is Dictionary:
		return false
	for key in ["startedAt","completedAt","bestMs","elapsedMs"]:
		if not _nullable_num(v.get(key),0,9007199254740991.0):
			return false
	return (v.get("runId")==null or _text(v.runId,64)) and v.get("trophyAwarded") is bool and v.get("rewardClaimed") is bool and _text(v.get("rewardKind"),48) and _rows(v.get("collected"),8,func(r): return _text(r,32)) and _rows(v.get("placements"),8,_hunt_marker)


static func _pet_row(v: Variant) -> bool:
	return v is Dictionary and _text(v.get("id"),64) and not v.id.is_empty() and _text(v.get("species"),16)

static func _pet_payload(progress: Dictionary) -> bool:
	if not progress.has("pets"): return true
	var ours: Variant = progress.pets
	if not ours is Dictionary or not _rows(ours.get("owned"),20000,_pet_row): return false
	if ours.get("activeId")!=null and not _text(ours.activeId,64): return false
	var home: Variant = progress.get("home")
	if home!=null and (not home is Dictionary or not _whole(home.get("plot"),0,5) or not _text(home.get("variant"),20)): return false
	var mortgage: Variant = progress.get("mortgage")
	if mortgage!=null:
		if not mortgage is Dictionary or not _text(mortgage.get("id"),32) or mortgage.id.length()!=32 or not _whole(mortgage.get("principal"),12,300) or int(mortgage.principal) not in [12,100,200,300]: return false
		if home==null or mortgage.get("homeId")!=home.plot or not _whole(mortgage.get("balance"),0,mortgage.principal): return false
	return progress.get("bankEligible") is bool and _rows(progress.get("homePlots"),6,func(r): return r is Dictionary and _whole(r.get("plot"),0,5) and r.get("available") is bool)

static func _classes(v: Variant) -> bool:
	if not v is Dictionary or v.size()!=10: return false
	for course in ["delivery","bank","vet","salon","cafe","store","library","nursery","park","singing"]:
		var row: Variant = v.get(course)
		if not row is Dictionary or not _whole(row.get("tier"),0,3): return false
		var tier := int(row.tier)
		if not _whole(row.get("paid"),0,[49,119,199,0][tier]) or row.get("reward")!=[3,5,8,10][tier]: return false
	return true


static func _fish_id(v: Variant) -> bool:
	return _text(v,64) and not v.is_empty()

static func _fish_item(v: Variant) -> bool:
	return v is Dictionary and _fish_id(v.get("id")) and _text(v.get("type"),32) and _text(v.get("name"),40) and _whole(v.get("value"),1,50)

static func _fish_cast(v: Variant) -> bool:
	return v == null or (v is Dictionary and _fish_id(v.get("id")) and (v.get("fishId")==null or _fish_id(v.fishId)) and _num(v.get("x"),-60,60) and _num(v.get("z"),-60,60) and _fish_time(v.get("startedAt")) and _fish_time(v.get("landAt")) and _rows(v.get("nibbles"),3,_fish_time) and (v.get("biteAt")==null or _fish_time(v.biteAt)) and _fish_time(v.get("expiresAt")) and v.startedAt<=v.landAt and v.landAt<=v.expiresAt)

static func _fish_time(v: Variant) -> bool:
	return _whole(v,0,9007199254740991.0)

static func _fish_state(v: Variant) -> bool:
	return v is Dictionary and v.get("equipped") is bool and _fish_cast(v.get("cast")) and _rows(v.get("inventory"),500,_fish_item)

static func _fish_display(v: Variant) -> bool:
	return v is Dictionary and v.get("equipped") is bool and _fish_cast(v.get("cast"))

static func _fish_shadow(v: Variant) -> bool:
	return v is Dictionary and _fish_id(v.get("id")) and _num(v.get("x"),-60,60) and _num(v.get("z"),-60,60) and _num(v.get("size"),.1,3) and _num(v.get("headingX",0),-1,1) and _num(v.get("headingZ",0),-1,1)

static func _home_scene(v: Variant) -> bool:
	if not v is Dictionary or v.get("variant") not in ["starter","cottage","family"] or not v.get("owner") is bool: return false
	if not _rows(v.get("visitors"),15,func(row):
		return row is Dictionary and _whole(row.get("id"),1,2147483647) and _text(row.get("alias"),32) and _text(row.get("character"),16) and _num(row.get("x"),-6,30) and _num(row.get("y"),-.2,4.3) and _num(row.get("z"),-5,5) and _num(row.get("yaw"),-3.142,3.142) and row.get("moving") is bool and row.get("grounded") is bool): return false
	if v.owner: return v.get("locked") is bool and not v.has("decor")
	return not v.has("locked") and _rows(v.get("decor"),20,func(row):
		return row is Dictionary and _text(row.get("id"),12) and _text(row.get("kind"),48) and _whole(row.get("room"),0,2) and _num(row.get("x"),-5,5) and _num(row.get("y"),0,4) and _num(row.get("z"),-4,4) and _whole(row.get("rotation"),0,3))

static func _visit_reply(v: Dictionary) -> bool:
	var op: Variant = v.get("action")
	if op in ["eject","readOnly"]: return _text(v.get("text"),120)
	if op not in ["enter","leave","lock","invalid"] or not v.get("ok") is bool: return false
	if not v.ok: return _text(v.get("error"),120)
	if op=="enter": return _whole(v.get("plot"),0,5) and v.get("variant") in ["starter","cottage","family"]
	if op=="lock": return v.get("locked") is bool
	return op=="leave"

static func _playground_state(v: Variant) -> bool:
	if not v is Dictionary or v.get("self") not in ["","swing-0","slide","seesaw-0","seesaw-1"]: return false
	return _rows(v.get("active"),4,func(row): return row is Dictionary and row.get("target") in ["swing-0","slide","seesaw-0","seesaw-1"] and _whole(row.get("ageMs"),0,86400000))


static func _fish_world(v: Dictionary) -> bool:
	if v.has("fishPopulation") and (not _fish_time(v.get("serverTime")) or not _rows(v.fishPopulation,10,_fish_shadow)):
		return false
	if v.has("fishingVisual") and not _fish_display(v.fishingVisual):
		return false
	for row: Dictionary in v.players:
		if row.has("fishingEquipped") and not row.fishingEquipped is bool:
			return false
		if row.has("fishingCast") and not _fish_cast(row.fishingCast):
			return false
	return true

static func _fish_reply(m: Dictionary) -> bool:
	if m.action != "fishing":
		return true
	if not _fish_id(m.get("requestId")) or m.get("operation") not in ["equip","putAway","cast","reel","cancel","quote","sell"] or not _fish_state(m.get("fishing")):
		return false
	if m.has("caught") and not _fish_item(m.caught):
		return false
	if m.has("quote"):
		var q: Variant = m.quote
		if not q is Dictionary or not _fish_id(q.get("quoteId")) or not _whole(q.get("total"),0,25000) or not _fish_time(q.get("expiresAt")) or not _rows(q.get("items"),500,_fish_item):
			return false
	return true

static func _furniture_row(r: Variant) -> bool:
	return r is Dictionary and _text(r.get("kind"),48) and _whole(r.get("quantity"),1,9007199254740991.0)

static func _furniture_placement(r: Variant) -> bool:
	return r is Dictionary and _text(r.get("id"),24) and _text(r.get("kind"),48) and _whole(r.get("room"),0,2) and _num(r.get("x"),-5,5) and _num(r.get("z"),-4,4) and _num(r.get("y"),0,4) and _whole(r.get("rotation"),0,3) and _whole(r.get("revision"),0,9007199254740991.0) and (r.get("supportId")==null or _text(r.supportId,24)) and (r.get("surfaceId")==null or _text(r.surfaceId,32))

static func _furniture(v: Variant) -> bool:
	return v is Dictionary and _rows(v.get("stock"),60,_furniture_row) and _rows(v.get("placed"),20,_furniture_placement) and _rows(v.get("deliveries"),50,func(r): return _furniture_row(r) and _text(r.get("id"),24))

static func _neighbor_marker(v: Variant) -> bool:
	return v is Dictionary and _text(v.get("label"),70) and _num(v.get("worldX"),-80,80) and _num(v.get("worldZ"),-62,62) and v.get("radius")==7 and v.get("business") in [null,"library","cafe"]


static func _neighbor_state(v: Variant) -> bool:
	if not v is Dictionary or not v.get("available") is bool or not v.get("routes") is Array:
		return false
	if not v.available:
		return v.get("revision")==null and v.get("current")==null and v.routes.is_empty()
	if not _whole(v.get("revision"),0,9007199254740991.0) or v.routes.size()!=2:
		return false
	for i in range(2):
		var r: Variant = v.routes[i]
		if not r is Dictionary or r.get("route")!=["gardener","librarian"][i] or not _text(r.get("label"),15) or (not _whole(r.get("reward"),3,10) or int(r.get("reward")) not in [3,5,8,10]) or not _neighbor_marker(r.get("marker")) or not _whole(r.get("waitMs"),0,60000) or (r.has("completed") and not r.completed is bool):
			return false
	var c: Variant = v.get("current")
	return c==null or (c is Dictionary and c.get("route") in ["gardener","librarian"] and _whole(c.get("step"),0,2) and _neighbor_marker(c.get("marker")))


static func _neighbor_reply(m: Dictionary) -> bool:
	if m.get("action")!="neighborQuest": return true
	if not m.has("neighborQuests") or m.get("operation") not in ["start","step","cancel","invalid"] or (m.get("requestId")!=null and not _text(m.requestId,64)): return false
	return not m.ok or (_whole(m.get("earned"),0,10) and m.get("replay") is bool)


static func _yard_flags(v: Variant) -> bool:
	return v is Dictionary and v.get("fence") is bool and v.get("trees") is bool and v.get("decor") is bool

static func _yard(v: Variant) -> bool:
	return v is Dictionary and v.get("eligible") is bool and _yard_flags(v.get("flags"))

static func _yard_public(v: Variant) -> bool:
	return _rows(v,6,func(r): return _yard_flags(r) and _whole(r.get("plot"),0,5))

static func _reef_photo_ids(v: Variant) -> bool:
	return _rows(v, REEF_PHOTO_IDS.size(), func(id): return id is String and id in REEF_PHOTO_IDS) and v.all(func(id): return v.count(id) == 1)


static func _reef_photo_reply(m: Dictionary) -> bool:
	if m.action != "reefPhotos":
		return true
	if m.operation != "record" or not _fish_id(m.get("requestId")) or not _reef_photo_ids(m.get("reefPhotos")):
		return false
	if not m.ok:
		return true
	return m.get("species") in m.reefPhotos and m.get("newDiscovery") is bool and _whole(m.get("count"),m.reefPhotos.size(),m.reefPhotos.size()) and _whole(m.get("total"),REEF_PHOTO_IDS.size(),REEF_PHOTO_IDS.size())


static func _progress(v: Variant) -> bool:
	return v is Dictionary and _whole(v.get("stars"),0,9007199254740991.0) and _whole(v.get("serverTime"),0,9007199254740991.0) and _nullable_num(v.get("gardenLastTendedAt"),0,9007199254740991.0) and (not v.has("vehicleOffer") or (v.vehicleOffer is Dictionary and _whole(v.vehicleOffer.get("tier"),-1,2))) and _pet_payload(v) and (not v.has("furniture") or _furniture(v.furniture)) and (not v.has("yard") or _yard(v.yard)) and (not v.has("neighborQuests") or _neighbor_state(v.neighborQuests)) and (not v.has("classes") or _classes(v.classes)) and (not v.has("fishing") or _fish_state(v.fishing)) and (not v.has("reefPhotos") or _reef_photo_ids(v.reefPhotos)) and _job_state(v.get("jobs")) and _hunt_state(v.get("scavenger")) and _rows(v.get("scavengerLeaderboard"),50,func(r): return _rank(r,"durationMs"))


static func _vehicle_seat(v: Variant) -> bool:
	return v==null or (v is Dictionary and _text(v.get("car"),16) and v.get("seat") in ["driver","passenger"])


static func _vehicle_row(v: Variant) -> bool:
	return v is Dictionary and _text(v.get("id"),16) and v.get("kind") in ["car","scooter"] and _whole(v.get("tier"),0,2) and _num(v.get("x"),-256,256) and _num(v.get("z"),-256,256) and _num(v.get("yaw"),-3.2,3.2) and _num(v.get("speed"),-4,10) and _nullable_num(v.get("driver"),1,9007199254740991.0) and _nullable_num(v.get("passenger"),1,9007199254740991.0) and v.get("canDrive") is bool


static func _home_exteriors(v: Variant) -> bool:
	if not v is Array or v.size() > 6:
		return false
	var plots: Dictionary = {}
	for row in v:
		if not row is Dictionary or row.size() != 2 or not _whole(row.get("plot"),0,5) or not row.get("variant") in ["cottage","family"]:
			return false
		var plot := int(row.plot)
		if plots.has(plot):
			return false
		plots[plot] = true
	return true

static func _vehicle_world(v: Variant) -> bool:
	return v is Dictionary and _rows(v.get("rows"),104,_vehicle_row) and _vehicle_seat(v.get("self")) and v.get("recallHome") is bool and v.get("parkHome") is bool


static func _hoops_run(v: Variant) -> bool:
	return v == null or (v is Dictionary and _text(v.get("id"),64) and _whole(v.get("startedAt"),0,9007199254740991.0) and _whole(v.get("endsAt"),0,9007199254740991.0) and v.get("finished") is bool and _nullable_num(v.get("score"),0,100000))


static func _pb_lobby_row(v: Variant) -> bool:
	return v is Dictionary and _whole(v.get("slot"),1,2147483647) and _text(v.get("alias"),32) and v.get("connected") is bool and v.get("ready") is bool

static func _pb_lobby(v: Dictionary) -> bool:
	if v.get("action") not in ["join","leave","state","ready","invalid"] or not v.get("ok") is bool:return false
	if not v.ok:return _text(v.get("error"),180)
	var room: Variant=v.get("room")
	if room==null:return true
	return room is Dictionary and room.get("phase") in ["lobby","starting"] and _whole(room.get("selfSlot"),1,2147483647) and _whole(room.get("hostSlot"),1,2147483647) and _rows(room.get("humans"),4,_pb_lobby_row) and _rows(room.get("botPreview"),3,func(b):return _text(b,16)) and room.get("arenaBusy") is bool and room.get("workerReady") is bool and _text(room.get("notice"),180)

static func _pb_slot(v: Variant) -> bool:
	return _text(v,24) and not v.is_empty()

static func _pb_xyz(v: Variant) -> bool:
	return v is Array and v.size()==3 and v.all(func(n):return _num(n,-75,75))

static func _pb_pose(v: Variant) -> bool:
	return v is Dictionary and _pb_slot(v.get("slot")) and _text(v.get("alias"),32) and v.get("bot") is bool and v.get("connected") is bool and _pb_xyz(v.get("position")) and _num(v.get("yaw"),-7,7) and v.get("moving") is bool and v.get("grounded") is bool and _whole(v.get("points"),0,4000)

static func _pb_rank(v: Variant) -> bool:
	return v is Dictionary and _pb_slot(v.get("slot")) and _text(v.get("alias"),32) and _whole(v.get("rank"),1,8) and _whole(v.get("score"),0,20000) and v.get("left") is bool

static func _pb_event(v: Variant) -> bool:
	if not v is Dictionary or not _whole(v.get("eid"),1,100000):return false
	match v.get("kind"):
		"paint":return _pb_slot(v.get("slot")) and _text(v.get("tagged"),24) and _pb_xyz(v.get("from")) and _pb_xyz(v.get("to"))
		"round","results":return _whole(v.get("round"),1,3)
		"abandoned":return true
	return false

static func _pb_view(v: Variant) -> bool:
	return v is Dictionary and v.get("phase") in ["loading","playing","between","finished","abandoned"] and _pb_slot(v.get("selfSlot")) and _text(v.get("hostSlot"),24) and _whole(v.get("round"),0,3) and _whole(v.get("remainingMs"),0,180000) and _rows(v.get("players"),4,_pb_pose) and _rows(v.get("ranking"),8,_pb_rank) and _rows(v.get("events"),48,_pb_event)

static func _pb_match(v: Dictionary) -> bool:
	if v.get("action") not in ["enter","ended","leave","ready","view","input","next","invalid"] or not v.get("ok") is bool:return false
	if v.has("error") and not _text(v.error,220):return false
	if v.has("text") and not _text(v.text,220):return false
	if v.has("epoch") and (not _text(v.epoch,16) or v.epoch.length()!=16):return false
	if v.get("action")=="enter" and (not v.has("epoch") or not _pb_slot(v.get("selfSlot"))):return false
	if v.has("view") and not _pb_view(v.view):return false
	return true

static func valid(message: Variant) -> bool:
	if not message is Dictionary or not message.get("type") is String:
		return false
	var m: Dictionary = message
	match m.type:
		"welcome":
			if not _whole(m.get("id"),1,2147483647) or not _text(m.get("alias"),32) or m.alias.is_empty() or (m.has("character") and not _text(m.character,16)):
				return false
			if m.has("session") or m.has("progress"):
				return _text(m.get("session"),96) and not m.session.is_empty() and _progress(m.get("progress"))
			return true
		"denied","airHockeyError":
			return _text(m.get("error"),250)
		"homeVisit":
			return _visit_reply(m)
		"playground":
			return m.get("ok") is bool and (not m.has("error") or _text(m.error,100))
		"vehicleEvent":
			var exit: Variant = m.get("exit")
			return m.get("ok") is bool and _text(m.get("text"),160) and (exit==null or (exit is Dictionary and _num(exit.get("x"),-256,256) and _num(exit.get("z"),-256,256)))
		"hideSeekInvite":
			return _text(m.get("id"),16) and m.id.length() == 16 and _text(m.get("host"),32) and (not m.has("remainingMs") or _whole(m.remainingMs,0,60000))
		"hideSeekInviteClosed":
			return _text(m.get("id"),16) and m.id.length()==16
		"hideSeek":
			return m.get("action") in ["join","leave","start","tag","state","accept","decline","invalid"] and m.get("ok") is bool and (not m.has("error") or _text(m.error,180)) and (not m.has("found") or m.found is bool) and _hide_seek_state(m.get("state"))
		"paintballCapability": return m.get("available") is bool
		"paintballLobby": return _pb_lobby(m)
		"paintballMatch": return _pb_match(m)
		"world":
			if m.has("yards") and (m.get("zone")!="town" or not _yard_public(m.yards)):
				return false
			return (not m.has("vehicles") or (m.get("zone")=="town" and _vehicle_world(m.vehicles))) and m.get("zone") in ZONES and _rows(m.get("players"),16,_pose) and _rows(m.get("presence"),16,_alias_row) and _fish_world(m) and _hide_seek_state(m.get("hideSeek")) and (not m.has("playground") or (m.zone=="town" and _playground_state(m.playground))) and (not m.has("homeScene") or (m.zone=="private" and _home_scene(m.homeScene))) and (not m.has("homeExteriors") or (m.zone=="town" and _home_exteriors(m.homeExteriors)))
		"progress":
			if m.get("action") == "paintball":
				return m.get("operation") == "onlineReward" and m.get("ok") is bool and m.ok and _progress(m)
			return m.get("action") in ["tendGarden","jobs","scavenger","pets","housing","fishing","classes","furniture","neighborQuest","vehicles","yard","reefPhotos"] and (m.get("action")!="vehicles" or (m.get("operation") in ["buy","upgrade","unknown"] and (m.get("requestId")==null or _text(m.requestId,64)))) and (m.get("action")!="classes" or (m.get("operation")=="pay" and (m.get("requestId")==null or _text(m.requestId,64)))) and m.get("ok") is bool and (not m.has("text") or _text(m.text,250)) and (not m.has("error") or _text(m.error,250)) and (not m.has("operation") or _text(m.operation,48)) and _progress(m) and _fish_reply(m) and _neighbor_reply(m) and _reef_photo_reply(m)
		"scavengerLeaderboard":
			return _rows(m.get("rows"),50,func(r): return _rank(r,"durationMs"))
		"chat":
			return _text(m.get("from"),32) and _text(m.get("text"),160) and not String(m.text).strip_edges().is_empty()
		"chatStatus":
			return m.get("available") is bool
		"chatError":
			return _text(m.get("code"),48) and _text(m.get("text"),200)
		"airHockeyFrame":
			if not m.has("frame"):
				return false
			var frame: Variant = m.frame
			return frame == null or (frame is Dictionary and frame.get("encoding") in ["text","base64"] and _text(frame.get("data"),24576))
		"hoops88":
			return (not m.has("error") or _text(m.error,250)) and (not m.has("action") or _text(m.action,48)) and _hoops_run(m.get("run")) and (not m.has("serverTime") or _whole(m.serverTime,0,9007199254740991.0)) and _nullable_num(m.get("best"),0,100000) and (not m.has("rows") or _rows(m.rows,50,func(r): return _rank(r,"score")))
		_:
			return false



static func _hide_seek_state(state: Variant) -> bool:
	if state == null: return true
	return state is Dictionary and state.get("phase") in ["lobby","hide","seek","results"] and state.get("role") in ["waiting","seeker","hider"] and state.get("host") is bool and _whole(state.get("remainingMs"),0,900000) and _whole(state.get("memberCount"),0,16) and state.get("found") is bool and _whole(state.get("remaining"),0,16) and state.get("result") in [null,"seeker","hiders"] and (not state.has("tagEligible") or state.tagEligible is bool)
