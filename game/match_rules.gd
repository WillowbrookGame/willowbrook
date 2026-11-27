extends RefCounted
## No scene, local input, or AI dependency. A future host can own this state.
const ROUND_LENGTH := 180.0
const ROUND_COUNT := 3
enum Phase { READY, PLAYING, BETWEEN, FINISHED }
var phase := Phase.READY
var round_number := 0
var round_length := ROUND_LENGTH
var target_points := 0
var remaining := 0.0
var totals: Dictionary = {}
var points: Dictionary = {}

func setup(nicknames: Array[String], length := ROUND_LENGTH, point_goal := 0) -> void:
	round_length = length
	target_points = point_goal
	for nick in nicknames:
		totals[nick] = 0
		points[nick] = 0

func start_round() -> bool:
	if phase != Phase.READY and phase != Phase.BETWEEN:
		return false
	round_number += 1
	remaining = round_length
	for nick in points:
		points[nick] = 0
	phase = Phase.PLAYING
	return true

func tick(delta: float) -> bool:
	if phase != Phase.PLAYING:
		return false
	remaining = maxf(0.0, remaining - delta)
	if remaining > 0.0:
		return false
	phase = Phase.FINISHED if round_number == ROUND_COUNT else Phase.BETWEEN
	return true

func tag(shooter: String, target: String) -> bool:
	if phase != Phase.PLAYING or shooter == target or not totals.has(shooter) or not totals.has(target):
		return false
	points[shooter] += 1
	totals[shooter] += 1
	if target_points > 0 and points[shooter] >= target_points:
		remaining = 0.0
		phase = Phase.FINISHED if round_number == ROUND_COUNT else Phase.BETWEEN
	return true

func rankings(cumulative: bool) -> Array:
	var scores := totals if cumulative else points
	var rows: Array = scores.keys()
	rows.sort_custom(func(a: String, b: String) -> bool:
		return scores[a] > scores[b] if scores[a] != scores[b] else a.naturalnocasecmp_to(b) < 0
	)
	var result: Array = []
	var rank := 0
	var previous := -1
	for index in range(rows.size()):
		var nick: String = rows[index]
		var score: int = scores[nick]
		if score != previous:
			rank = index + 1
		result.append([rank, nick, score])
		previous = score
	return result
