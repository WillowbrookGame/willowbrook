extends RefCounted
## The solo transition contract. No presence packets, saves, or flight state changes.

const AVATARS := preload("res://game/avatars/catalog.gd")
const PARK := "res://game/skyhill/skyhill.tscn"
const TOWN := "res://game/town.tscn"
const ARRIVAL := &"skyhill_solo_arrival"
const RETURN := &"skyhill_solo_return"

static func enter(tree: SceneTree, avatar: Variant) -> Error:
	tree.set_meta(ARRIVAL, AVATARS.sanitize(avatar))
	var result := tree.change_scene_to_file(PARK)
	if result != OK:
		tree.remove_meta(ARRIVAL)
	return result

static func take_arrival(tree: SceneTree) -> String:
	var avatar: String = ""
	if tree.has_meta(ARRIVAL):
		avatar = AVATARS.sanitize(tree.get_meta(ARRIVAL))
		tree.remove_meta(ARRIVAL)
	return avatar

static func return_to_town(tree: SceneTree) -> Error:
	tree.set_meta(RETURN, true)
	var result := tree.change_scene_to_file(TOWN)
	if result != OK:
		tree.remove_meta(RETURN)
	return result

static func take_return(tree: SceneTree) -> bool:
	if not tree.has_meta(RETURN):
		return false
	tree.remove_meta(RETURN)
	return true
