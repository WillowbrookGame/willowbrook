extends Node3D
## Decorative only. The exterior projection never contains ownership data.
const ROOT := "res://game/town_assets/tiny-homely/"
const KINDS := ["fence","trees","decor"]
var _doors: Array
var _groups := {}
var _bounds := {}

func configure(doors: Array) -> void:
	_doors = doors.duplicate()

func update_rows(rows: Array) -> void:
	var seen := {}
	for state: Dictionary in rows:
		var plot := int(state.get("plot",-1))
		if plot < 0 or plot >= _doors.size():
			continue
		for kind: String in KINDS:
			if not bool(state.get(kind,false)):
				continue
			var key := "%d:%s" % [plot,kind]
			seen[key] = true
			if not _groups.has(key):
				_groups[key] = _build(plot,kind)
	for key: String in _groups.keys():
		if not seen.has(key):
			var group: Node3D = _groups[key]
			remove_child(group)
			group.queue_free()
			_groups.erase(key)

func _build(plot: int,kind: String) -> Node3D:
	var group := Node3D.new()
	group.name = "YardPlot%d_%s" % [plot+1,kind]
	add_child(group)
	group.position = _doors[plot] - Vector3(0,0,5)
	match kind:
		"fence":
			# Keep the west fence beyond the parking lane and the opposite fence unchanged.
			for x: float in [-11.65,7.5]:
				for z: float in [-3.0,-1.4,.2]:
					_piece(group,"fence_straight",Vector2(x,z),1.6,PI/2)
		"trees":
			for x: float in [-6.6,6.6]:
				_piece(group,"tree",Vector2(x,-3),1.3)
		"decor":
			_piece(group,"bench_A",Vector2(-5.55,5.6),1.6,PI/2)
			_piece(group,"foliage_A",Vector2(7,.2),.8)
			_piece(group,"boots",Vector2(2.4,5.55),.55)
			_piece(group,"doormat",Vector2(0,5.55),1.2)
	return group

func _piece(owner_node: Node3D,file: String,spot: Vector2,w: float,yaw := 0.0) -> void:
	var scene := load(ROOT+file+".gltf") as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	var holder := Node3D.new()
	holder.name = file
	owner_node.add_child(holder)
	holder.add_child(model)
	if not _bounds.has(file):
		var box := AABB()
		var has_mesh := false
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var local := holder.global_transform.affine_inverse()*mesh.global_transform
			var mesh_bounds := local*mesh.get_aabb()
			box = box.merge(mesh_bounds) if has_mesh else mesh_bounds
			has_mesh = true
		if not has_mesh:
			holder.queue_free()
			return
		_bounds[file] = box
	var b: AABB = _bounds[file]
	var factor := w/maxf(.001,maxf(b.size.x,b.size.z))
	var center := b.get_center()
	model.scale = Vector3.ONE*factor
	model.position = Vector3(-center.x,-b.position.y,-center.z)*factor
	holder.position = Vector3(spot.x,.04,spot.y)
	holder.rotation.y = yaw

