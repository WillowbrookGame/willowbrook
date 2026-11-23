extends SceneTree

const Profile := preload("res://game/progression/profile.gd")
const HomeLot := preload("res://game/progression/home_lot.gd")

class FakeHost extends Node3D:
	var profile: Profile

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := FakeHost.new()
	host.profile = Profile.new("")
	root.add_child(host)
	var plot := Vector3(11,0,-12)
	var another := Vector3(-11,0,12)
	var player := CharacterBody3D.new()
	host.add_child(player)
	var hud := CanvasLayer.new()
	host.add_child(hud)
	var lot := HomeLot.new()
	host.add_child(lot)
	lot.setup(host,player,hud,[plot,another])
	var state := host.profile.snapshot()
	state.home = {"plot":0,"variant":"starter"}
	state.furniture = [
		{"kind":"chair","quantity":3},
		{"kind":"chair","id":"decor-chair","room":0,"x":0.0,"z":0.0,"rotation":0}
	]
	state.deliveries = [
		{"kind":"chair","quantity":2,"homeId":1},
		{"kind":"chair","quantity":2},
		{"kind":"lamp","quantity":1,"homeId":0}
	]
	host.profile.commit(state)
	player.position = another
	if lot.interact() or not lot.interaction_prompt().is_empty():
		push_error("Non-owner porch cannot collect any parcel")
		quit(1)
		return
	player.position = plot + Vector3(0,0,1)
	if lot.interaction_prompt() != "Pick up 2 × Chair" or not lot.interact():
		push_error("Own porch did not collect pending delivery")
		quit(1)
		return
	var picked := host.profile.snapshot()
	if picked.furniture[0].quantity != 5 or picked.furniture[1].has("quantity") or picked.deliveries.size() != 2:
		push_error("Picked up wrong parcel or edited existing decoration")
		quit(1)
		return
	if lot.interaction_prompt() != "Pick up 1 × Lamp" or not lot.interact():
		push_error("Own porch didn't reveal the next package")
		quit(1)
		return
	picked = host.profile.snapshot()
	if picked.furniture[2] != {"kind":"lamp","quantity":1} or not lot.interaction_prompt().is_empty() or lot.interact():
		push_error("Package collection isn't one-shot")
		quit(1)
		return
	print("PASS: furniture delivery requires own porch, increments inventory once, and preserves placed decor")
	quit()
