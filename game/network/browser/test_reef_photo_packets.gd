extends SceneTree
const SCHEMA := preload("res://game/network/browser/message_schema.gd")

func _initialize() -> void:
	var progress := {
		"stars": 0, "serverTime": 100, "gardenLastTendedAt": null,
		"jobs": {"status": "", "eligible": false, "starterWaitMs": {"cafe": 0, "store": 0, "park": 0, "garden": 0}, "memberships": [], "completed": [], "available": [], "employers": []},
		"scavenger": {"trophyAwarded": false, "rewardClaimed": false, "rewardKind": "", "collected": [], "placements": []},
		"scavengerLeaderboard": [],
	}
	var reply := progress.merged({
		"type": "progress", "action": "reefPhotos", "operation": "record", "requestId": "a1234567",
		"ok": true, "text": "Reef photo saved!", "reefPhotos": ["shark"],
		"species": "shark", "newDiscovery": true, "count": 1, "total": 8,
	})
	if not _check(not _parse(reply).is_empty(), "Accept a successful Reef Photo reply"):
		return
	var duplicate := reply.merged({"newDiscovery": false}, true)
	var failed := progress.merged({"type": "progress", "action": "reefPhotos", "operation": "record", "requestId": "a1234567", "ok": false, "error": "Could not save your reef photo.", "reefPhotos": []})
	if not _check(not _parse(duplicate).is_empty() and not _parse(failed).is_empty(), "Accept already-discovered and failed-save replies"):
		return
	var legacy := progress.merged({"type": "progress", "action": "tendGarden", "ok": true})
	if not _check(not _parse(legacy).is_empty(), "Accept legacy progress without Reef Photos"):
		return
	for bad: Variant in [{}, ["shark", 1], [""], ["unknown-fish"], ["shark", "shark"]]:
		if not _check(_parse(reply.merged({"reefPhotos": bad}, true)).is_empty(), "Reject malformed collections: %s" % [bad]):
			return
	for bad_field: Dictionary in [{"requestId": 23}, {"operation": "other"}, {"species": "tuna"}, {"newDiscovery": 1}, {"count": 2}, {"total": 0}]:
		if not _check(_parse(reply.merged(bad_field, true)).is_empty(), "Reject malformed confirmations: %s" % [bad_field]):
			return
	print("PASS: browser parser accepts Reef Photo confirmations, duplicates and failures; validates collection data.")
	quit()

func _parse(packet: Dictionary) -> Dictionary:
	return SCHEMA.parse(JSON.stringify(packet).to_utf8_buffer())

func _check(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok
