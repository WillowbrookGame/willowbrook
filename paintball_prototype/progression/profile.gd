extends RefCounted
## Town's local profile and proximity-validated progression. Web task definitions retain
## original positions, pay, order and durations; indoor callers use room-local coordinates.
signal changed

const DATA_PATH := "res://paintball_prototype/progression/web_tasks.json"
const PROFILE_VERSION := 1
const MAX_STARS := 9007199254740991
const MAX_FISH := 500
const PETS := preload("res://paintball_prototype/pets/catalog.gd")

var _save_path: String
var _data: Dictionary
var _state: Dictionary
var _rng := RandomNumberGenerator.new()


func _init(save_path: String = "user://willowbrook_profile.cfg", seed_value: int = -1) -> void:
	_save_path = save_path
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_state = _defaults()
	if not _save_path.is_empty():
		for path in [_save_path,_save_path+".bak"]:
			var cfg := ConfigFile.new()
			if cfg.load(path) == OK and cfg.get_value("profile","version",0) == PROFILE_VERSION:
				var candidate: Variant = cfg.get_value("profile","data",null)
				if candidate is Dictionary:
					var merged := _defaults()
					merged.merge(candidate,true)
					if _valid(merged):
						_state = merged
						break


func _defaults() -> Dictionary:
	return {
		"stars":0, "fish":[], "fishing_migrated":false, "employed":"", "memberships":[],
		"classes":{}, "home":{}, "loan":{}, "pet":{}, "furniture":[], "furniture_stock":{},
		"deliveries":[], "portfolio":{}, "job":{"stage":"none","deliveries":0},
		"work":{}, "work_completed":{}, "starter":{"completed":{},"rewarded":{},"run":{}}
	}


func _valid(value: Dictionary) -> bool:
	if typeof(value.get("stars")) != TYPE_INT or value.stars < 0 or value.stars > MAX_STARS:
		return false
	if typeof(value.get("fishing_migrated")) != TYPE_BOOL or typeof(value.get("employed")) != TYPE_STRING:
		return false
	for field in ["classes","home","loan","pet","furniture_stock","portfolio","job","work","work_completed","starter"]:
		if not value.get(field) is Dictionary:
			return false
	for field in ["fish","furniture","deliveries","memberships"]:
		if not value.get(field) is Array:
			return false
	if value.fish.size() > MAX_FISH:
		return false
	for id in value.fish:
		if not id is String or id.length() > 64 or id.is_empty():
			return false
	if value.has("pets"):
		var pet_state: Variant = value.pets
		if not pet_state is Dictionary or not pet_state.get("owned") is Array: return false
		var ids: Dictionary = {}
		for row in pet_state.owned:
			if not row is Dictionary or not row.get("id") is String or String(row.id).is_empty() or String(row.id).length()>64 or row.get("species") not in PETS.SPECIES or ids.has(row.id):
				return false
			ids[row.id]=true
		if pet_state.get("activeId")!=null and not ids.has(pet_state.activeId): return false
	var starter: Dictionary = value.starter
	if not starter.get("completed") is Dictionary or not starter.get("rewarded") is Dictionary or not starter.get("run") is Dictionary:
		return false
	if str(value.job.get("stage","none")) not in ["none","pickup","deliver"]:
		return false
	for name in value.classes:
		var row: Variant = value.classes[name]
		if not row is Dictionary or typeof(row.get("tier")) != TYPE_INT or int(row.tier) not in [0,1,2,3] or typeof(row.get("paid",0)) != TYPE_INT or int(row.get("paid",0)) < 0:
			return false
	return true


func snapshot() -> Dictionary:
	return _state.duplicate(true)


func commit(next: Dictionary) -> bool:
	var merged := _defaults()
	merged.merge(next,true)
	if not _valid(merged):
		return false
	var candidate := merged.duplicate(true)
	if not _save_path.is_empty() and not _write(candidate):
		return false
	_state = candidate
	changed.emit()
	return true


func _write(candidate: Dictionary) -> bool:
	var path := ProjectSettings.globalize_path(_save_path)
	var temporary := path+".tmp"
	var backup := path+".bak"
	var previous := ConfigFile.new()
	var has_good_previous: bool = previous.load(path) == OK and previous.get_value("profile","version",0) == PROFILE_VERSION and previous.get_value("profile","data",null) is Dictionary
	var cfg := ConfigFile.new()
	cfg.set_value("profile","version",PROFILE_VERSION)
	cfg.set_value("profile","data",candidate)
	if cfg.save(temporary) != OK:
		return false
	if has_good_previous:
		if DirAccess.rename_absolute(path,backup) != OK:
			return false
	if DirAccess.rename_absolute(temporary,path) == OK:
		return true
	if has_good_previous:
		DirAccess.rename_absolute(backup,path)
	return false


func get_stars() -> int:
	return _state.stars


func change_stars(delta: int) -> bool:
	if delta < -get_stars() or delta > MAX_STARS-get_stars():
		return false
	var next := snapshot()
	next.stars += delta
	return commit(next)


func starter_eligible() -> bool:
	if not _state.employed.is_empty() or not _state.memberships.is_empty():
		return true
	for id in _data.starterQuests:
		if not _state.starter.completed.has(id):
			return false
	return true


func starter_checklist(now: float = -1.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var t := _time(now)
	var hints := {
		"cafe":"Find the snack tray in Sunny Cafe.",
		"store":"Find the stock box inside Town Store.",
		"park":"Find litter in the park east of the fountain.",
		"garden":"Find the watering can at the southeast garden."
	}
	for id: String in _data.starterQuests:
		var definition: Dictionary = _data.starterQuests[id]
		var ready_at := float(_state.starter.rewarded.get(id,0.0)) + (float(definition.cooldownMs)/1000.0 if _state.starter.rewarded.has(id) else 0.0)
		result.append({"id":id,"label":definition.label,"hint":hints[id],
			"reward":int(definition.reward),"done":_state.starter.completed.has(id),"wait":ceili(maxf(0,ready_at-t))})
	return result


func available_markers(zone: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if active():
		return result
	for id: String in _data.starterQuests:
		var step: Dictionary = _data.starterQuests[id].steps[0]
		if _zone_matches(zone,step):
			result.append({"position":_task_world(step)-_offset(zone),"label":step.label,"id":id+"-starter"})
	for id: String in memberships():
		if not _data.workDefinitions.has(id):
			continue
		var task: Dictionary = _data.parcelStation if id=="delivery" else _data.workTaskDefinitions[id].station
		if _zone_matches(zone,task):
			result.append({"position":_task_world(task)-_offset(zone),"label":task.label,"id":id+"-work"})
	return result


func memberships() -> Array:
	var result: Array = _state.memberships.duplicate()
	if not _state.employed.is_empty() and not result.has(_state.employed):
		result.append(_state.employed)
	return result


func job_names() -> Array:
	return _data.workDefinitions.keys().duplicate()


func job_guide(name: String) -> Dictionary:
	if not _data.workDefinitions.has(name):
		return {}
	var job: Dictionary = _data.workDefinitions[name]
	var employer: Dictionary = _data.employerSites[_data.jobEmployer[name]]
	var route: Dictionary = _data.workTaskDefinitions.get(name,{})
	return {
		"employer":employer.label, "zone":str(job.business) if job.business != null else "town",
		"station":route.get("station",_data.parcelStation).label,
		"tasks": route.get("tasks",[]).duplicate(true),
		"reward":work_reward(name)
	}


func work_reward(name: String) -> int:
	var progress: Dictionary = _state.classes.get(name,{})
	return [3,5,8,10][clampi(int(progress.get("tier",0)),0,3)]


func hire(name: String, zone: String, at: Vector3) -> Dictionary:
	if not _data.workDefinitions.has(name):
		return _result(false,"Choose a Willowbrook job.")
	if not _within(zone,at,_data.employerSites[_data.jobEmployer[name]]):
		return _result(false,"Visit the workplace employer to get hired.")
	if not starter_eligible():
		return _result(false,"Finish the four starter activities first: cafe, store, park, and garden.")
	if memberships().has(name):
		return _result(false,"You're already hired for this job.")
	var next := snapshot()
	if next.employed.is_empty():
		next.employed = name
	next.memberships.append(name)
	return _persist(next,"You're hired for %s! Visit the work supplies to start." % _job_label(name))


func take_class(name: String, amount: int) -> Dictionary:
	if not _data.workDefinitions.has(name) or amount < 1:
		return _result(false,"Choose a job class and a whole-star payment.")
	var next := snapshot()
	var row: Dictionary = next.classes.get(name,{"tier":0,"paid":0})
	var tier: int = row.tier
	if tier >= _data.classTiers.size():
		return _result(false,"You've completed all three tiers for this job.")
	var tier_def: Dictionary = _data.classTiers[tier]
	var cost := int(tier_def.cost)
	if amount > cost-int(row.get("paid",0)):
		return _result(false,"That is more than the remaining class price.")
	if amount > next.stars:
		return _result(false,"Earn more stars to pay for the class.")
	next.stars -= amount
	row.paid = int(row.get("paid",0)) + amount
	var message := "%d stars paid toward the %s class." % [amount,_job_label(name)]
	if row.paid == cost:
		row.tier += 1
		row.paid = 0
		message = "%s tier %d complete! This job now pays %d stars." % [_job_label(name),row.tier,int(tier_def.reward)]
	next.classes[name] = row
	return _persist(next,message)


func _job_label(name: String) -> String:
	if name == "singing":
		return "Stage"
	return name.capitalize()


func current_marker(zone: String) -> Dictionary:
	var task := _target()
	if task.is_empty() or not _zone_matches(zone,task):
		return {}
	var marker := task.duplicate(true)
	marker.position = _task_world(task) - _offset(zone)
	return marker


func status_text() -> String:
	var job: Dictionary = _state.job
	var target := _target()
	if job.get("stage") == "deliver" and not target.is_empty():
		return "Deliver to %s" % target.label
	if not target.is_empty():
		var label: String = target.label
		var zone = target.get("interiorBusiness")
		if zone != null:
			label += " (%s)" % str(zone).capitalize()
		return label
	return ""


func active() -> bool:
	return not _state.work.is_empty() or not _state.starter.run.is_empty() or _state.job.get("stage") != "none"


func _target() -> Dictionary:
	var work: Dictionary = _state.work
	var starter: Dictionary = _state.starter.run
	var job: Dictionary = _state.job
	if not work.is_empty() and _data.workTaskDefinitions.has(work.get("name")):
		var tasks: Array = _data.workTaskDefinitions[work.name].tasks
		var step := int(work.get("step",-1))
		return tasks[step] if step >= 0 and step < tasks.size() else {}
	if not starter.is_empty() and _data.starterQuests.has(starter.get("name")):
		var steps: Array = _data.starterQuests[starter.name].steps
		var step := int(starter.get("step",-1))
		return steps[step] if step >= 0 and step < steps.size() else {}
	match job.get("stage"):
		"pickup":
			return _data.parcelStation
		"deliver":
			for spot: Dictionary in _data.deliveryDestinations:
				if spot.id == job.get("destination"):
					return spot
	return {}


func _zone_matches(zone: String, target: Dictionary) -> bool:
	var business = target.get("interiorBusiness")
	return zone == ("town" if business == null else str(business))


func _task_world(target: Dictionary) -> Vector3:
	return Vector3(float(target.x),0,float(target.z))


func _offset(zone: String) -> Vector3:
	if _data.businessDefinitions.has(zone):
		return _task_world(_data.businessDefinitions[zone])
	return Vector3.ZERO


func _distance(zone: String, at: Vector3, target: Dictionary) -> float:
	var point := _task_world(target) - _offset(zone)
	return Vector2(at.x-point.x,at.z-point.z).length()


func _within(zone: String, at: Vector3, target: Dictionary) -> bool:
	return at.is_finite() and absf(at.y) < 2.0 and _zone_matches(zone,target) and _distance(zone,at,target) <= target.radius


func _offer(zone: String, at: Vector3, skip_hire := false) -> Dictionary:
	var target := _target()
	if active():
		if not target.is_empty() and _within(zone,at,target):
			var label: String = target.label
			if _state.job.get("stage") == "deliver":
				label = "Deliver the parcel"
			elif _pending() >= 0.0:
				label = "Working..."
			return {"kind":"continue","label":label}
		return {}
	var best_distance := INF
	var best := {}
	for id in _data.starterQuests:
		var step: Dictionary = _data.starterQuests[id].steps[0]
		if _within(zone,at,step) and _distance(zone,at,step) < best_distance:
			best_distance = _distance(zone,at,step)
			best = {"kind":"starter","name":str(id),"label":str(step.label)}
	# The store parcel, exterior jobs, and indoor supply stations are distinct from employers.
	var employed := memberships()
	for id in employed:
		if not _data.workDefinitions.has(id):
			continue
		var station: Dictionary = _data.parcelStation if id == "delivery" else _data.workTaskDefinitions[id].station
		if _within(zone,at,station) and _distance(zone,at,station) <= best_distance:
			best_distance = _distance(zone,at,station)
			best = {"kind":"start","name":str(id),"label":str(station.label)}
	# Inside, the room's business NPC panels choose which job to offer.
	if zone == "town" and not skip_hire:
		for id in ["park","nursery","singing"]:
			var employer: Dictionary = _data.employerSites[id]
			if not employed.has(id) and _within(zone,at,employer) and _distance(zone,at,employer) < best_distance:
				best_distance = _distance(zone,at,employer)
				best = {"kind":"hire","name":id,"label":"Talk to %s" % employer.label}
	return best


func prompt(zone: String, at: Vector3, skip_hire := false) -> String:
	return _offer(zone,at,skip_hire).get("label","")


func perform(zone: String, at: Vector3, now: float = -1.0, skip_hire := false) -> Dictionary:
	var offer := _offer(zone,at,skip_hire)
	if offer.is_empty():
		return {}
	var t := _time(now)
	var next := snapshot()
	var kind: String = offer.kind
	var id: String = offer.get("name","")
	match kind:
		"hire":
			return hire(id,zone,at)
		"starter":
			next.starter.run = {"name":id,"step":0,"started":t}
			return _persist(next,"%s. Stay close while you help." % offer.label)
		"start":
			if id == "delivery":
				next.job.stage = "pickup"
				return _persist(next,"Delivery started. Pick up your parcel.")
			next.work = {"name":id,"step":0}
			return _persist(next,"%s started. Follow the gold task marker." % _job_label(id))
		"continue":
			match next.job.stage:
				"pickup":
					var options: Array = _data.deliveryDestinations
					var destination: Dictionary = options[_rng.randi_range(0,options.size()-1)]
					next.job.stage = "deliver"
					next.job.destination = destination.id
					return _persist(next,"Deliver to %s." % destination.label)
				"deliver":
					next.job = {"stage":"none","deliveries":int(next.job.get("deliveries",0))+1}
					var reward := work_reward("delivery")
					_add_star_reward(next,reward)
					return _persist(next,"Parcel delivered! +%d stars." % reward)
			if _pending() >= 0.0:
				return _result(false,"Keep helping for a moment.")
			if not next.work.is_empty():
				next.work.started = t
			else:
				next.starter.run.started = t
			return _persist(next,"%s. Stay close while you help." % offer.label)
	return {}


func _pending() -> float:
	var run: Dictionary = _state.work if not _state.work.is_empty() else _state.starter.run
	return float(run.get("started",-1.0))


func _time(now: float) -> float:
	return Time.get_unix_time_from_system() if now < 0.0 else now


func advance(zone: String, at: Vector3, now: float = -1.0) -> Dictionary:
	var started := _pending()
	if started < 0.0:
		return {}
	var task := _target()
	if task.is_empty():
		return {}
	var in_range := _within(zone,at,task)
	var t := _time(now)
	if in_range and t >= started and (t-started)*1000.0 < float(task.durationMs):
		return {}
	var next := snapshot()
	var is_work: bool = not next.work.is_empty()
	var run: Dictionary = next.work if is_work else next.starter.run
	run.erase("started")
	if not in_range or t < started:
		return _persist(next,"Step paused. Return to the marker and try again.")
	run.step += 1
	var id: String = run.name
	var steps: Array = _data.workTaskDefinitions[id].tasks if is_work else _data.starterQuests[id].steps
	if run.step < steps.size():
		return _persist(next,"Step complete! Next: %s." % steps[run.step].label)
	if is_work:
		next.work = {}
		next.work_completed[id] = t
		var reward := work_reward(id)
		_add_star_reward(next,reward)
		return _persist(next,"Shift done! +%d stars." % reward)
	var quest: Dictionary = _data.starterQuests[id]
	var first_time: bool = not next.starter.completed.has(id)
	next.starter.completed[id] = t
	next.starter.run = {}
	var reward := 0
	if not next.starter.rewarded.has(id) or t-float(next.starter.rewarded[id]) >= float(quest.cooldownMs)/1000.0:
		reward = int(quest.reward)
		next.starter.rewarded[id] = t
		_add_star_reward(next,reward)
	var text := "Activity complete! +%d %s." % [reward,"star" if reward == 1 else "stars"] if reward else "Activity complete! Its star reward is still resting."
	if first_time and not starter_eligible() and next.starter.completed.size() == _data.starterQuests.size():
		text += " You can now get hired!"
	return _persist(next,text)


func _add_star_reward(next: Dictionary, value: int) -> void:
	next.stars = mini(MAX_STARS,int(next.stars)+value)


func cancel() -> Dictionary:
	if not active():
		return _result(false,"No active shift or activity.")
	var next := snapshot()
	next.work = {}
	next.starter.run = {}
	next.job = {"stage":"none","deliveries":int(next.job.get("deliveries",0))}
	return _persist(next,"Current work canceled.")


func _result(ok: bool, text: String) -> Dictionary:
	return {"ok":ok,"text":text}


func _persist(next: Dictionary, message: String) -> Dictionary:
	if not commit(next):
		return _result(false,"Couldn't save that change. Try again.")
	return _result(true,message)
