extends SceneTree
## Optional positional inputs: captured pre-match, reward, and post-relogin packets.
const SCHEMA := preload("res://game/network/browser/message_schema.gd")
const SESSION := preload("res://game/network/browser/account_session.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var progress := {
		"stars": 3, "serverTime": 100, "gardenLastTendedAt": null,
		"jobs": {"status": "", "eligible": false, "starterWaitMs": {"cafe": 0, "store": 0, "park": 0, "garden": 0},
			"memberships": [], "completed": [], "available": [], "employers": []},
		"scavenger": {"trophyAwarded": false, "rewardClaimed": false, "rewardKind": "", "collected": [], "placements": []},
		"scavengerLeaderboard": [],
	}
	var reward := progress.merged({"type": "progress", "action": "paintball", "operation": "onlineReward", "ok": true})
	reward.stars = 13
	var args := OS.get_cmdline_user_args()
	var relogin: Dictionary = {}
	if args.size() == 3:
		var initial := SCHEMA.parse(FileAccess.get_file_as_bytes(args[0]))
		reward = SCHEMA.parse(FileAccess.get_file_as_bytes(args[1]))
		relogin = SCHEMA.parse(FileAccess.get_file_as_bytes(args[2]))
		if initial.get("type") != "welcome" or reward.get("action") != "paintball" or relogin.get("type") != "welcome":
			_fail("The signed-in browser parser must accept initial, reward and relogin packets from the server.")
			return
		progress = initial.progress
		if int(reward.stars) - int(progress.stars) != 10 or reward.stars != relogin.progress.stars:
			_fail("Capture must show exactly +10 Stars immediately and the same balance after relogin.")
			return
	for bad: Dictionary in [{"operation": "soloReward"}, {"operation": "unknown"}, {"ok": false}, {"ok": 1}, {"stars": -1}, {"stars": "13"}]:
		if not _parse(reward.merged(bad, true)).is_empty():
			_fail("Malformed or unsupported Paintball update accepted: %s" % [bad])
			return
	var parsed := _parse(reward)
	if parsed.is_empty():
		_fail("Server-confirmed Paintball reward was dropped.")
		return
	var session := SESSION.new()
	var badge := Label.new()
	session._star_badge = badge
	session.admitted = true
	session._update_progress(progress)
	var initial_ok := badge.text == "Stars: %d" % int(progress.stars)
	session._on_web_message(parsed)
	var reward_ok := badge.text == "Stars: %d" % int(reward.stars)
	session._on_web_message(parsed)
	var duplicate_ok := badge.text == "Stars: %d" % int(reward.stars)
	session.free()
	badge.free()
	if not initial_ok or not reward_ok or not duplicate_ok:
		_fail("Did not apply initial balance, immediate reward, and repeated snapshot without double credit.")
		return
	print("PASS Paintball wallet packet: strict online reward, immediate badge refresh, no duplicate credit.")
	quit()

func _parse(packet: Dictionary) -> Dictionary:
	return SCHEMA.parse(JSON.stringify(packet).to_utf8_buffer())

func _fail(detail: String) -> void:
	push_error(detail)
	quit(1)
