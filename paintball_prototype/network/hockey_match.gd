extends RefCounted
## Normalized version of the original Willowbrook server rules. Host only advances the simulation.
const PUCK_RADIUS := 0.045
const PADDLE_RADIUS := 0.11
const GOAL_HALF := 0.32
const PADDLE_SPEED := 3.0
const MAX_PUCK_SPEED := 3.0
const WIN_SCORE := 5
const ARENAS := ["ice","sea","desert"]
var seats: Array[int] = [0,0]
var paddles: Array[Vector2] = [Vector2(0,-0.65),Vector2(0,0.65)]
var targets: Array[Vector2] = paddles.duplicate()
var scores: Array[int] = [0,0]
var ready: Array[bool] = [false,false]
var last_input: Array[int] = [-1000,-1000]
var puck := Vector2.ZERO
var velocity := Vector2.ZERO
var phase := "waiting"
var winner := -1
var serve_left := 0.8
var round_number := 1
var wins: Array[int] = [0,0]
var round_left := 0.0


func side(id: int) -> int:
	return seats.find(id) if id > 0 else -1


func join(id: int) -> bool:
	if id <= 0:
		return false
	if side(id) >= 0:
		return true
	var next := seats.find(0)
	if next < 0:
		return false
	seats[next] = id
	_reset()
	return true


func leave(id: int) -> void:
	var index := side(id)
	if index >= 0:
		seats[index] = 0
		_reset()


func aim(id: int, target: Vector2, now: int) -> void:
	var index := side(id)
	if index < 0 or phase != "playing" or not target.is_finite() or now - last_input[index] < 33:
		return
	last_input[index] = now
	targets[index] = Vector2(clampf(target.x,-0.89,0.89),clampf(target.y,-0.89,-0.11) if index == 0 else clampf(target.y,0.11,0.89))


func rematch(id: int) -> void:
	var index := side(id)
	if index < 0 or phase != "finished":
		return
	ready[index] = true
	if ready[0] and ready[1]:
		_reset()


func _reset() -> void:
	round_number = 1
	wins.assign([0,0])
	winner = -1
	_reset_round()


func _reset_round() -> void:
	paddles.assign([Vector2(0,-0.65),Vector2(0,0.65)])
	targets.assign(paddles)
	scores.assign([0,0])
	ready.assign([false,false])
	last_input.assign([-1000,-1000])
	winner = -1
	phase = "playing" if seats[0] > 0 and seats[1] > 0 else "waiting"
	_serve(1.0)


func _serve(direction: float) -> void:
	puck = Vector2.ZERO
	velocity = Vector2(0.23,direction*1.1)
	serve_left = 0.8


func advance(dt: float) -> void:
	if phase == "round_over":
		round_left -= dt
		if round_left <= 0.0:
			round_number += 1
			_reset_round()
		return
	if phase != "playing" or dt <= 0.0:
		return
	dt = minf(dt,0.05)
	var n := ceili(dt * 240)
	var step := dt / n
	var wall := 1.0 - PUCK_RADIUS
	for _i in range(n):
		var motion: Array[Vector2] = []
		for i in range(2):
			var before := paddles[i]
			paddles[i] = before.move_toward(targets[i],PADDLE_SPEED*step)
			motion.append((paddles[i]-before)/step)
		if serve_left > 0.0:
			serve_left -= step
			continue
		puck += velocity * step
		for i in range(2):
			var diff := puck - paddles[i]
			var radius := PUCK_RADIUS + PADDLE_RADIUS
			if diff.length_squared() < radius * radius:
				var normal := diff.normalized() if diff.length_squared() > 0.0000001 else Vector2(0,1 if i == 0 else -1)
				puck = paddles[i] + normal*radius
				var approach := (velocity-motion[i]).dot(normal)
				if approach < 0.0:
					velocity = (velocity - 2.0*approach*normal).limit_length(MAX_PUCK_SPEED)
		if absf(puck.x) > wall:
			puck.x = clampf(puck.x,-wall,wall)
			velocity.x = -signf(puck.x)*absf(velocity.x)
		if absf(puck.y) > wall:
			if absf(puck.x) < GOAL_HALF-PUCK_RADIUS:
				var scoring_side := 0 if puck.y > 0 else 1
				scores[scoring_side] += 1
				if scores[scoring_side] >= WIN_SCORE:
					wins[scoring_side] += 1
					velocity = Vector2.ZERO
					if wins[scoring_side] >= 2:
						phase = "finished"
						winner = scoring_side
					else:
						phase = "round_over"
						round_left = 1.1
				else:
					_serve(1.0 if scoring_side == 0 else -1.0)
				return
			puck.y = clampf(puck.y,-wall,wall)
			velocity.y = -signf(puck.y)*absf(velocity.y)


func state(id: int, entries: Dictionary) -> Dictionary:
	var names: Array[String] = []
	for peer_id in seats:
		names.append(String(entries.get(peer_id, {}).get("alias","")))
	return {"side":side(id),"paddles":paddles.duplicate(),"puck":puck,"scores":scores.duplicate(),"phase":phase,"winner":winner,"names":names,"ready":ready.duplicate(),"serve_left":maxf(serve_left,0),"round":round_number,"wins":wins.duplicate(),"arena":ARENAS[round_number-1]}
