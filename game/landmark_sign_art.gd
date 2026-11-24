extends RefCounted
## Painted insert sized to the charcoal panel of the original notice board GLB.
const PANEL_SIZE := Vector2(1.44, .77)
const INK := Color("#fff3d2")
const RIM := Color("#b99566")

static func add_notice_face(model: Node3D, title: String, subtitle: String, color: Color, back := false) -> Label3D:
	var face := Node3D.new()
	face.name = "MountedNoticeBack" if back else "MountedNoticeFront"
	model.add_child(face)
	# Follow the timber frame rather than the roof overhang's misleading bounds.
	face.position = Vector3(0,1.205,-.047 if back else .056)
	face.rotation.y = PI if back else 0.0
	_box(face,"InsetPanel",Vector3.ZERO,Vector3(PANEL_SIZE.x,PANEL_SIZE.y,.032),color)
	_box(face,"HeaderRule",Vector3(0,.036,.017),Vector3(1.2,.014,.012),RIM)
	for x in [-.665,.665]:
		for y in [-.325,.325]:
			_box(face,"MountPin",Vector3(x,y,.020),Vector3(.022,.022,.015),RIM)
	var heading := _caption(face,"Heading",title,.185,58)
	fit_text(heading,Vector2(1.25,.20))
	var body := _caption(face,"NoticeCopy",subtitle,-.137,44)
	fit_text(body,Vector2(1.16,.245))
	return body

static func fit_text(label: Label3D, area: Vector2) -> void:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var width := 0.0
	var lines := label.text.split("\n")
	for line: String in lines:
		width = maxf(width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x)
	var height := font.get_height(label.font_size)*float(lines.size()) + label.line_spacing*maxi(0,lines.size()-1)
	var margin := float(label.outline_size)*2.0 + 2.0
	label.pixel_size = minf(area.x/maxf(1.,width+margin),area.y/maxf(1.,height+margin))

static func _caption(parent: Node3D, id: String, value: String, y: float, font_px: int) -> Label3D:
	var label := Label3D.new()
	label.name = id
	label.text = value
	label.font_size = font_px
	label.outline_size = 3
	label.line_spacing = 0
	label.modulate = INK
	parent.add_child(label)
	label.position = Vector3(0,y,.026)
	return label

static func _box(parent: Node3D, id: String, at: Vector3, size: Vector3, tint: Color) -> void:
	var piece := MeshInstance3D.new()
	piece.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = .92
	piece.material_override = mat
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece,true)
	piece.position = at
