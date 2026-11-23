extends RefCounted
## Kenney Mini Characters 2.0 (CC0). A single bounded preset ID, never a resource path from the wire.
const DEFAULT := "male-a"
const ROOT := "res://game/"
const MODELS := {
	"male-a":"character-male-a.glb",
	"male-b":"interiors/art/kenney-mini/character-male-b.glb",
	"male-c":"avatars/models/character-male-c.glb",
	"male-d":"avatars/models/character-male-d.glb",
	"male-e":"town_assets/kenney-mini-npcs/character-male-e.glb",
	"male-f":"avatars/models/character-male-f.glb",
	"male-g":"avatars/models/character-male-g.glb",
	"female-a":"beach_art/kenney-mini/character-female-a.glb",
	"female-b":"interiors/art/kenney-mini/character-female-b.glb",
	"female-c":"interiors/art/kenney-mini/character-female-c.glb",
	"female-d":"town_assets/kenney-mini-npcs/character-female-d.glb",
	"female-e":"avatars/models/character-female-e.glb",
	"female-f":"avatars/models/character-female-f.glb",
	"alien":"avatars/models/character-alien.glb",
	"knight":"avatars/models/character-knight.glb",
	"raider":"avatars/models/character-raider.glb",
	"robot":"avatars/models/character-robot.glb",
	"soldier":"avatars/models/character-soldier.glb",
	"worker":"town_assets/kenney-mini-npcs/character-worker.glb",
	"zombie":"avatars/models/character-zombie.glb",
}

static func sanitize(value: Variant) -> String:
	return str(value) if value is String and MODELS.has(value) else DEFAULT

static func instantiate(value: Variant) -> Node3D:
	var id := sanitize(value)
	var path := ROOT + str(MODELS[id])
	var resource := (load(path) as PackedScene) if ResourceLoader.exists(path) else null
	if resource == null:
		id = DEFAULT
		resource = load(ROOT + str(MODELS[DEFAULT])) as PackedScene
	var model := resource.instantiate() as Node3D
	model.set_meta("avatar_id",id)
	return model

static func animator(model: Node3D) -> AnimationPlayer:
	return model.find_children("*","AnimationPlayer",true,false).front() as AnimationPlayer

