extends Node3D
## Willowbrook Island preserves the original beach activity coordinates.
const FERRY = preload("res://game/ferry_landing.gd")
const SPAWN := Vector3(0, 0.05, 34)
const TOWN_DOOR := Vector3(0, 0, 38)
const WORLD_BOUNDS := Rect2(-57, -55, 114, 98)
const POLE := Vector3(2.8, 0, 2)
# Interaction happens in the customer aisle, not at the clerk's position inside.
const SHOP_NPC := Vector3(-19, 0, 28.5)
const MARINA_POSITION := Vector3(-19, .48, 32.65)
const FISHER_NPC := Vector3(1.7, 0.55, -31)
const SLIDE_ENTRY := Vector3(-46.05, 0, 3.5)
const SLIDE_SECONDS := 4.35
const SLIDE_CREST_TIME := 2.10
const SLIDE_GLIDE_END := 4.03
# Exact centerline at the top surface of the imported yellow straight chute,
# transformed by the Beach model's .35 scale. x=-46.05 throughout.
const SLIDE_CHUTE := [
	Vector2(7.203,3.521),Vector2(7.553,3.518),Vector2(7.903,3.468),
	Vector2(8.253,3.344),Vector2(8.603,3.156),Vector2(8.953,2.920),
	Vector2(9.303,2.641),Vector2(9.653,2.336),Vector2(10.003,2.014),
	Vector2(10.353,1.688),Vector2(10.703,1.370),Vector2(11.053,1.071),
	Vector2(11.403,.802),Vector2(11.753,.575),Vector2(12.103,.405),
	Vector2(12.453,.298),Vector2(12.803,.267),Vector2(13.503,.266)
]
const ART := "res://game/beach_art/"
const ROD := ART + "beach-fishing/FishingRod_Lvl1.glb"

# Conservative waterline footprints for the two existing moored models;
# these fixed XZ bounds remain valid while the meshes bob in Y.
const MOORING_HULLS := [
	Rect2(20.15,-9.25,2.7,4.5),
	Rect2(41.40,-9.80,3.2,5.6),
]

var departure_only := false
var _boats: Array[Node3D] = []

static func is_water(at: Vector3) -> bool:
	if absf(at.x) >= 57.0 or at.z < -55.0 or at.z >= 1.0:
		return false
	var main_dock := (absf(at.x) <= 2.2 and at.z >= -23.0) or (absf(at.x) <= 3.25 and at.z >= -35.0 and at.z <= -23.0)
	var rental_dock := (absf(at.x - 32.0) <= 2.2 and at.z >= -11.0) or (absf(at.x - 32.0) <= 7.0 and at.z >= -11.45 and at.z <= -6.0)
	return not main_dock and not rental_dock and not is_boat_water(at)


static func is_boat_water(at: Vector3) -> bool:
	for hull: Rect2 in MOORING_HULLS:
		if hull.has_point(Vector2(at.x,at.z)):
			return true
	return false


static func slide_is_seated(elapsed: float) -> bool:
	return elapsed >= SLIDE_CREST_TIME and elapsed <= SLIDE_GLIDE_END


static func _slide_surface(z: float) -> float:
	for i in range(1,SLIDE_CHUTE.size()):
		var a: Vector2 = SLIDE_CHUTE[i-1]
		var b: Vector2 = SLIDE_CHUTE[i]
		if z <= b.x:
			return lerpf(a.y,b.y,clampf(inverse_lerp(a.x,b.x,z),0.0,1.0))
	return SLIDE_CHUTE.back().y


static func slide_pitch(elapsed: float) -> float:
	if not slide_is_seated(elapsed):
		return 0.0
	var z := slide_pose(elapsed).z
	return clampf(atan2(_slide_surface(z-.13)-_slide_surface(z+.13),.26)*.77,0.0,.67)


static func slide_pose(elapsed: float) -> Vector3:
	var t := clampf(elapsed,0.0,SLIDE_SECONDS)
	if t < .29:
		return Vector3(SLIDE_ENTRY.x,0.0,lerpf(3.5,5.1,t/.29))
	if t < 1.63:
		var u := inverse_lerp(.29,1.63,t)
		return Vector3(SLIDE_ENTRY.x,lerpf(0.0,3.521,u),lerpf(5.1,6.12,u))
	if t < SLIDE_CREST_TIME:
		return Vector3(SLIDE_ENTRY.x,3.521,lerpf(6.12,7.203,inverse_lerp(1.63,SLIDE_CREST_TIME,t)))
	if t <= SLIDE_GLIDE_END:
		var u := pow(inverse_lerp(SLIDE_CREST_TIME,SLIDE_GLIDE_END,t),1.20)
		var z := lerpf(7.203,13.503,u)
		return Vector3(SLIDE_ENTRY.x,_slide_surface(z),z)
	var u := inverse_lerp(SLIDE_GLIDE_END,SLIDE_SECONDS,t)
	return Vector3(SLIDE_ENTRY.x,lerpf(.266,.04,u),lerpf(13.503,14.35,u))


func _ready() -> void:
	_sky_and_sand()
	_make_water()
	if departure_only: return
	_make_island_landing()
	_make_docks()
	_make_shops()
	_make_scenery()
	_make_fishing_props()
	# These low-cost invisible colliders are on layer 2, not on the camera probe's layer.
	_box_collision(Vector3(-57.5, .8, 22), Vector3(1, 4, 44), 2)
	_box_collision(Vector3(57.5, .8, 22), Vector3(1, 4, 44), 2)
	_box_collision(Vector3(0, .8, 42.8), Vector3(115, 4, .64), 2)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _boats.size():
		_boats[i].position.y = -0.34 + sin(t * .7 + i * 2.0) * .035
		_boats[i].rotation.z = sin(t * .5 + i) * .012


func _sky_and_sand() -> void:
	var globe := ProceduralSkyMaterial.new()
	globe.sky_top_color = Color("#57a7d9")
	globe.sky_horizon_color = Color("#aeddea")
	globe.ground_horizon_color = globe.sky_horizon_color
	globe.ground_bottom_color = Color("#70a8a7")
	var sky := Sky.new()
	sky.sky_material = globe
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff2cc")
	env.ambient_light_energy = .72
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -28, 0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 1.0
	add_child(sun)
	var sand := _material(Color("#e8c897"))
	sand.albedo_texture = load(ART + "beach-nature/sand-color.png") as Texture2D
	sand.uv1_scale = Vector3(12, 4.5, 1)
	sand.normal_enabled = true
	sand.normal_texture = load(ART + "beach-nature/sand-normal.png") as Texture2D
	sand.normal_scale = .22
	_island_mesh(sand)
	_box_collision(Vector3(0, -.3, 22), Vector3(120, .6, 42))
	# Leave the mouths of both piers open so the broad beach can flow into both approaches.
	_box_collision(Vector3(-29.65, .55, .5), Vector3(54.7, 3.1, 1.05), 2)
	_box_collision(Vector3(16, .55, .5), Vector3(27.6, 3.1, 1.05), 2)
	_box_collision(Vector3(45.6, .55, .5), Vector3(22.8, 3.1, 1.05), 2)


func _make_water() -> void:
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """
shader_type spatial;
render_mode unshaded;
varying vec3 ground_pos;
void vertex() {
	ground_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 shore = max(abs(ground_pos.xz - vec2(0.0,20.70)) - vec2(57.6,21.0),vec2(0.0));
	float depth = smoothstep(0.0, 52.0, length(shore));
	vec3 color = mix(vec3(0.33, 0.72, 0.68), vec3(0.08, 0.37, 0.54), depth);
	vec2 grid = ground_pos.xz;
	float drift = sin(grid.x * .34 + grid.y * .12 - TIME * .62);
	float waves = sin(grid.y * 2.05 + drift * 1.05 - TIME * 2.0);
	float cross_wave = sin(grid.x * .62 + grid.y * 1.36 + TIME * 1.07 + drift * .58);
	float distance_fade = 1.0 - smoothstep(30.0, 105.0, distance(CAMERA_POSITION_WORLD, ground_pos));
	// Wider traveling swells and broken highlight crests stay visible near the piers.
	float swells = waves * .038 + cross_wave * .020;
	float crest = smoothstep(.59, .97, waves) * smoothstep(-.77, .43, cross_wave);
	color += (vec3(.31, .87, .92) * crest * .12 + vec3(.65, .92, .86) * swells) * distance_fade;
	float lip = -1.43 + sin(grid.x * .37 - TIME * .75) * .34 + sin(TIME * 1.16) * .39;
	float foam = (1.0 - smoothstep(.04, .34, abs(grid.y - lip))) * (1.0-smoothstep(56.0,60.0,abs(grid.x)));
	float back = 1.0 - smoothstep(.06,.36,abs(grid.y-42.3+sin(grid.x*.32+TIME)*.18));
	float edge = 1.0 - smoothstep(.07,.41,abs(abs(grid.x)-59.30+sin(grid.y*.21+TIME)*.31));
	foam = max(foam,back*(1.0-smoothstep(49.0,57.0,abs(grid.x)))*.66);
	foam = max(foam,edge*smoothstep(.0,3.8,grid.y)*(1.0-smoothstep(37.0,42.0,grid.y))*.64);
	float foam_tail = (1.0 - smoothstep(.03, .43, abs(grid.y - lip + .58))) * (1.0-smoothstep(56.0,60.0,abs(grid.x)));
	color = mix(color, vec3(0.88, 0.98, 0.93), foam * .81 + foam_tail * .14);
	color = mix(color, vec3(0.67, 0.86, 0.91), smoothstep(76.0, 193.0, distance(CAMERA_POSITION_WORLD, ground_pos)));
	ALBEDO = color;
}
"""
	_plane(Vector3(0, -.17, 0), Vector2(500, 500), material)


func _island_mesh(sand: StandardMaterial3D) -> void:
	# Outline is outside all activity and recovery coordinates. The back
	# corners curve into the water; the existing north beach remains flat.
	var perimeter := PackedVector2Array([Vector2(-57.7,0),Vector2(57.7,0),Vector2(59,5),
		Vector2(59.4,24),Vector2(59.0,37),Vector2(57.8,40.7),Vector2(56.3,42.26),Vector2(42.0,42.25),
		Vector2(10,42.4),Vector2(-18,42.25),Vector2(-42,42.35),Vector2(-56.4,42.26),Vector2(-58.0,40.55),
		Vector2(-59.1,37.3),Vector2(-59.6,24),Vector2(-59,5.5)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(perimeter)
	for i in range(0,indices.size(),3):
		for index: int in [indices[i],indices[i+1],indices[i+2]]:
			var p := perimeter[index]
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2((p.x+60.0)/120.0,p.y/43.0))
			surface.add_vertex(Vector3(p.x,0,p.y))
	surface.generate_tangents()
	_mesh(surface.commit(),Vector3.ZERO,sand)


func _make_island_landing() -> void:
	var path_material := _material(Color("#cbb088"))
	path_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(15):
		var a := _path_row(23.0 + float(i))
		var b := _path_row(24.0 + float(i))
		for p: Vector3 in [a[0], b[0], a[1], a[1], b[0], b[1]]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(p)
	_mesh(surface.commit(),Vector3.ZERO,path_material)
	_box_collision(Vector3(0,-.16,42.4),Vector3(5.6,.46,8.4))
	var ferry := FERRY.new()
	ferry.name = "FerryLanding"
	add_child(ferry)
	# The longer passenger ferry needs a little extra clearance aft to float.
	ferry.position = TOWN_DOOR + Vector3(0,.065,1.15)
	ferry.build("ISLAND FERRY","To Willowbrook Town")
	var image := ShaderMaterial.new()
	image.shader = Shader.new()
	image.shader.code = """
shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never;
uniform sampler2D snapshot : source_color;
void fragment() {
	vec4 sample_color = texture(snapshot, vec2(UV.x, 0.25 + UV.y * 0.52));
	float sky = smoothstep(.09, .26, distance(sample_color.rgb, vec3(.49,.71,.77)));
	float edges = smoothstep(.01, .14, UV.x) * (1.0 - smoothstep(.86, .99, UV.x));
	float foot = 1.0 - smoothstep(.73, .98, UV.y);
	ALBEDO = sample_color.rgb;
	ALPHA = sample_color.a * sky * edges * foot * .83;
}
"""
	image.set_shader_parameter("snapshot", load(ART + "beach-town-backdrop/town-from-beach.png"))
	var quad := QuadMesh.new()
	quad.size = Vector2(70, 20)
	var silhouette := MeshInstance3D.new()
	silhouette.mesh = quad
	silhouette.position = Vector3(0, 4, 119)
	silhouette.rotation.y = PI
	silhouette.material_override = image
	add_child(silhouette)


func _path_row(z: float) -> Array[Vector3]:
	var x := sin((z - 38.0) * .16) * 1.4
	var width := 2.55 + .18 * sin(z * 1.4) + .14 * sin(z * .49)
	return [Vector3(x - width, .028, z), Vector3(x + width, .028, z)]


func _make_docks() -> void:
	_place_asset(ART + "beach-fishing/Dock_Long.glb", Vector3(0, .48, -5), Vector3(4.4, 0, 12), true)
	_place_asset(ART + "beach-fishing/Dock_Long.glb", Vector3(0, .48, -17), Vector3(4.4, 0, 12), true)
	_place_asset(ART + "beach-fishing/Dock_Wide.glb", Vector3(0, .48, -29), Vector3(6.5, 0, 12), true)
	_box_collision(Vector3(0, .35, -10.9), Vector3(4.4, .4, 24.2))
	_box_collision(Vector3(0, .35, -29), Vector3(6.5, .4, 12.05))
	_ramp(0, 2.4, 4.2)
	_dock_guard(2.18, -10.9, 24.2)
	_dock_guard(-2.18, -10.9, 24.2)
	_dock_guard(3.22, -29, 12.0)
	_dock_guard(-3.22, -29, 12.0)
	for x in [-2.73, 2.73]:
		_box_collision(Vector3(x, .8, -23), Vector3(1.05, 2.5, .18), 2)
	_box_collision(Vector3(0, .8, -35.0), Vector3(6.5, 2.5, .18), 2)
	_raw_asset(ART + "beach-shops/rental-dock.glb", Vector3(32, -.72, 4), .5, 0)
	_box_collision(Vector3(32, .465, 4.0), Vector3(4.0, .43, 20.0))
	_box_collision(Vector3(32, .465, -8.50), Vector3(14.0, .43, 5.0))
	_box_collision(Vector3(25.5, .465, 9.0), Vector3(9.0, .43, 6.0))
	_ramp(32, 15.2, 3.8, .27)
	_ramp(28, 13.2, 2.8, .27)
	for x in [29.99, 34.01]:
		_dock_guard(x, -2.5, 7.0)
	for x in [24.99, 39.01]:
		_dock_guard(x, -8.5, 5.1)
	_box_collision(Vector3(32, .8, -11), Vector3(14, 2.5, .18), 2)
	for x in [27.5, 36.5]:
		_box_collision(Vector3(x, .8, -6), Vector3(5.0, 2.5, .18), 2)
	for data in [["boat-row-small", 21.5, 4.6], ["boat-speed-a", 43.0, 5.5]]:
		var boat := _place_asset(ART + "beach-boats/" + data[0] + ".glb", Vector3(data[1], -.34, -7), Vector3(0, 0, data[2]))
		if boat != null:
			_boats.append(boat)


func _dock_guard(x: float, z: float, distance: float) -> void:
	_box_collision(Vector3(x, .8, z), Vector3(.18, 2.5, distance), 2)


func _ramp(x: float, z: float, width: float, tilt: float = .22) -> void:
	var ramp := _box_collision(Vector3(x, tilt * 1.13, z), Vector3(width, .12, 2.5))
	ramp.rotation.x = tilt
	_box_mesh(ramp.position, Vector3(width, .12, 2.5), Color("#a37453"))
	(get_child(get_child_count() - 1) as Node3D).rotation.x = tilt


func _make_shops() -> void:
	_place_asset(ART + "beach-shops/dive-shop.glb", Vector3(-25, 0, 8), Vector3(10, 0, 0), false, true)
	_box_collision(Vector3(-25, 2.65, 8), Vector3(8.8, 5.3, 7))
	_box_collision(Vector3(24.5, 3.0, 9), Vector3(5.3, 6.0, 4.4))
	_raw_asset(ART + "beach-shops/snack-kiosk.glb", Vector3(-19, 0, 30), .48, PI)
	_box_collision(Vector3(-19, 2.4, 33.6), Vector3(9.8, 4.8, 6.8))
	# The counter face is around z=31.1 with a .48-high interior floor.
	# Turn the imported model toward the customer aisle on the -Z side.
	var marina := _npc(ART + "kenney-mini/character-female-a.glb", MARINA_POSITION, 3.7, PI, "idle")
	if marina != null:
		marina.name = "Marina"
	_place_asset(ART + "beach-shops/snack-slide.glb", Vector3(-43, 0, 9), Vector3(0, 0, 0), false, false, .35)
	_box_collision(Vector3(-43, 1.6, 9), Vector3(10, 3.2, 9.2))
	_disc(SLIDE_ENTRY + Vector3.UP * .026, .68, Color("#f5cc6a"))


func _make_scenery() -> void:
	var palms := ["tree_palmDetailedTall", "tree_palmDetailedShort", "tree_palmBend"]
	var positions := [Vector2(-52, 24), Vector2(-43, 36), Vector2(-47, 18), Vector2(-40, 29), Vector2(43, 25), Vector2(52, 36), Vector2(48, 19), Vector2(40, 36)]
	for i in positions.size():
		var p: Vector2 = positions[i]
		var palm := _place_asset(ART + "beach-nature/" + palms[i % 3] + ".glb", Vector3(p.x, 0, p.y), Vector3(0, 5.8 if i % 3 == 1 else 7.5, 0))
		if palm != null:
			palm.rotation.y = i * 1.7
	for x in [-52.0, -15.0, 14.0, 43.0]:
		_box_mesh(Vector3(x, .08, 5.85), Vector3(2.0, .16, 3.4), Color("#e99d76"))
		var skirt := CylinderMesh.new()
		skirt.top_radius = 0.1
		skirt.bottom_radius = 2.3
		skirt.height = .7
		skirt.radial_segments = 10
		_mesh(skirt, Vector3(x, 2.96, 5), _material(Color("#efd992") if x < 0 else Color("#6bb1b2")))
		_box_mesh(Vector3(x, 1.39, 5), Vector3(.10, 2.78, .10), Color("#a6774a"))


func _make_fishing_props() -> void:
	var waiting_rod := make_rod(2.45)
	waiting_rod.position = POLE + Vector3(0, .05, 0)
	waiting_rod.rotation_degrees.z = 20.0
	add_child(waiting_rod)
	var finn := _npc("res://game/character-male-a.glb", FISHER_NPC, 3.05, PI / 2.0, "holding-right")
	if finn != null:
		finn.name = "Finn"
	var fisher_rod := make_rod(3.4)
	fisher_rod.position = Vector3(2.1, 1.55, -31)
	fisher_rod.rotation_degrees.z = -58.0
	add_child(fisher_rod)
	var bobber := SphereMesh.new()
	bobber.radius = .095
	bobber.height = .19
	bobber.radial_segments = 8
	bobber.rings = 4
	var end := Vector3(6.2, -.12, -31)
	_mesh(bobber, end, _material(Color("#ec694f")))
	var tip := fisher_rod.transform * Vector3(0, 3.4, 0)
	var line := ImmediateMesh.new()
	var white := _material(Color("#fff4d6"))
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, white)
	line.surface_add_vertex(tip)
	line.surface_add_vertex(Vector3(5.6, .35, -31))
	line.surface_add_vertex(end)
	line.surface_end()
	_mesh(line, Vector3.ZERO)


func make_rod(length: float = 2.4) -> Node3D:
	var root := Node3D.new()
	var visual := _new_asset(ROD)
	if visual == null:
		return root
	var bounds := _model_bounds(visual)
	var s := length / maxf(.001, bounds.size.y)
	visual.scale *= s
	visual.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * s
	root.add_child(visual)
	return root


func _npc(path: String, at: Vector3, amount: float, yaw: float, anim: String) -> Node3D:
	var model := _raw_asset(path, at, amount, yaw)
	if model == null:
		return null
	var player := model.find_children("*", "AnimationPlayer", true, false)
	if not player.is_empty():
		var animation := player[0] as AnimationPlayer
		if animation.has_animation(anim):
			animation.play(anim)
	return model


func _new_asset(path: String) -> Node3D:
	var source := load(path) as PackedScene
	return source.instantiate() as Node3D if source != null else null


func _raw_asset(path: String, at: Vector3, amount: float, yaw: float) -> Node3D:
	var model := _new_asset(path)
	if model != null:
		add_child(model)
		model.position = at
		model.scale *= amount
		model.rotation.y = yaw
	return model


func _place_asset(path: String, at: Vector3, fit: Vector3, center_y: bool = false, ignore_surf: bool = false, default_scale: float = 1.0) -> Node3D:
	var model := _new_asset(path)
	if model == null:
		return null
	var b := _model_bounds(model, ignore_surf)
	var mid := b.get_center()
	var s := Vector3.ONE * default_scale
	if fit.x > 0:
		s = Vector3.ONE * (fit.x / maxf(.001, b.size.x))
	elif fit.y > 0:
		s = Vector3.ONE * (fit.y / maxf(.001, b.size.y))
	elif fit.z > 0:
		s = Vector3.ONE * (fit.z / maxf(.001, maxf(b.size.z, b.size.x)))
	if fit.x > 0 and fit.z > 0:
		s.z = fit.z / maxf(.001, b.size.z)
	var pivot := Node3D.new()
	pivot.name = path.get_file().get_basename()
	add_child(pivot)
	pivot.position = at
	model.position -= Vector3(mid.x, mid.y if center_y else b.position.y, mid.z) * s
	model.scale *= s
	pivot.add_child(model)
	if fit.z > 0 and fit.x <= 0 and b.size.x > b.size.z:
		pivot.rotation.y = PI / 2.0
	return pivot


func _model_bounds(root: Node3D, ignore_surf: bool = false) -> AABB:
	var bounds := AABB()
	var found := false
	var candidates := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		candidates.push_front(root)
	for node in candidates:
		var piece := node as MeshInstance3D
		if piece.mesh == null or (ignore_surf and (piece.name.begins_with("Surfboard_") or piece.name.begins_with("SurfRack"))):
			continue
		var t := piece.transform
		var ancestor := piece.get_parent_node_3d()
		while ancestor != null:
			t = ancestor.transform * t
			if ancestor == root:
				break
			ancestor = ancestor.get_parent_node_3d()
		var box := t * piece.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	return bounds


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _mesh(shape: Mesh, at: Vector3, material: Material = null) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = shape
	result.material_override = material
	add_child(result)
	result.position = at
	return result


func _plane(at: Vector3, size: Vector2, material: Material) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	_mesh(plane, at, material)


func _disc(at: Vector3, radius: float, color: Color) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = .022
	disc.radial_segments = 24
	_mesh(disc, at, _material(color))


func _box_mesh(at: Vector3, size: Vector3, color: Color) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	_mesh(shape, at, _material(color))


func _box_collision(at: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	body.position = at
	return body







