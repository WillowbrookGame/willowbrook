extends RefCounted
## Presentation only: use the existing park job desk/step anchors, not new targets.
const BIN_SCENE = preload("res://paintball_prototype/town_assets/kenney-furniture/trashcan.glb")
const ANCHORS := {
	Vector2(11,-24): "paper",
	Vector2(21,-24): "bin",
	Vector2(13,-20): "basket",
	Vector2(12,-22): "paper",
	Vector2(20,-22): "cup",
	Vector2(20,-27): "bin",
}


static func prop_for(marker: Dictionary) -> String:
	# Native marker dictionaries expose task IDs; account markers intentionally
	# only expose job/position. Both share exact Town anchors from web_tasks.json.
	if marker.get("job","park") != "park":
		return ""
	var point: Vector3 = marker.position
	return ANCHORS.get(Vector2(point.x,point.z),"")


static func make_prop(kind: String) -> Node3D:
	var prop := Node3D.new()
	prop.name = "Park" + kind.capitalize()
	prop.position.y = -0.01 # Existing park slab/path tops are about 0.10–0.11 m.
	match kind:
		"paper":
			var page := _box(prop,Vector3(.47,.024,.34),Vector3(0,.033,0),Color("#fff5d9"))
			page.rotation.y = .46
			var fold := _box(page,Vector3(.22,.023,.235),Vector3(.115,.031,.026),Color("#e3cc9c"))
			fold.rotation.z = -.22
			for i in 3:
				_box(page,Vector3(.18,.005,.014),Vector3(-.092,.015,-.075+i*.05),Color("#9aa99a"))
		"cup":
			var tipped := Node3D.new()
			prop.add_child(tipped)
			tipped.position.y = .15
			tipped.rotation_degrees = Vector3(0,25,81)
			_cylinder(tipped,.15,.10,.32,Vector3.ZERO,Color("#de774d"))
			_cylinder(tipped,.157,.156,.029,Vector3(0,.163,0),Color("#fff1d1"))
			_cylinder(tipped,.117,.117,.004,Vector3(0,.179,0),Color("#773d37"))
			_cylinder(tipped,.136,.125,.07,Vector3(0,.012,0),Color("#f2bc77"))
		"basket":
			var dark := Color("#996339")
			_box(prop,Vector3(.60,.11,.37),Vector3(0,.064,0),dark)
			for direction in [-1,1]:
				_box(prop,Vector3(.62,.19,.045),Vector3(0,.185,.17*direction),Color("#d9a662"))
				_box(prop,Vector3(.047,.19,.34),Vector3(.28*direction,.185,0),Color("#c68a4f"))
				_box(prop,Vector3(.049,.34,.047),Vector3(.28*direction,.327,0),dark)
			_box(prop,Vector3(.60,.042,.053),Vector3(0,.499,0),dark)
		"bin":
			var model := BIN_SCENE.instantiate() as Node3D
			prop.add_child(model)
			model.scale *= 1.85
			for mesh: Node in model.find_children("*","MeshInstance3D",true,false):
				_tint_bin(mesh as MeshInstance3D)
			if model is MeshInstance3D:
				_tint_bin(model)
			_box(prop,Vector3(.25,.13,.028),Vector3(0,.41,.227),Color("#12615a"))
			var sign := Label3D.new()
			sign.text = "RECYCLE"
			sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sign.font_size = 24
			sign.outline_size = 0
			sign.pixel_size = .002
			sign.modulate = Color("#edf9e3")
			sign.position = Vector3(0,.41,.243)
			prop.add_child(sign)
	return prop


static func _tint_bin(instance: MeshInstance3D) -> void:
	for slot in instance.get_surface_override_material_count():
		var original := instance.mesh.surface_get_material(slot) as StandardMaterial3D
		if original == null:
			continue
		var tinted := original.duplicate() as StandardMaterial3D
		tinted.albedo_color = Color("#64be82") if original.albedo_color.v > .65 else Color("#20594a")
		instance.set_surface_override_material(slot,tinted)


static func _box(parent: Node3D, size: Vector3, at: Vector3, tint: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _piece(parent,shape,at,tint)


static func _cylinder(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, tint: Color) -> void:
	var shape := CylinderMesh.new()
	shape.radial_segments = 8
	shape.rings = 1
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	_piece(parent,shape,at,tint)


static func _piece(parent: Node3D, shape: PrimitiveMesh, at: Vector3, tint: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = .94
	piece.mesh = shape
	piece.material_override = material
	piece.position = at
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)
	return piece
