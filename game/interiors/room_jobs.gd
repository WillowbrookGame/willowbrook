extends Node3D
## Three.js task locations and names are shared with the progression model.
const TASK_DATA := preload("res://game/progression/web_tasks.json")
const ART = preload("res://game/interiors/room_art.gd")

var zone := ""
var art: ART
var room_origin := Vector3.ZERO
var captions := {}
var station: Dictionary = {}
var props := {}
var panel: PanelContainer
var title: Label
var tasks: Label
var progress: ProgressBar
var last_mode := ""
var last_marker := ""
var marker: Node3D
var starter_markers: Dictionary = {}

func setup(id_: String, room_art: ART, hud: CanvasLayer) -> void:
	zone=id_
	art=room_art
	var zone_def: Dictionary = TASK_DATA.data.businessDefinitions.get(zone,{})
	if zone_def.is_empty(): return
	room_origin = Vector3(float(zone_def.x),0,float(zone_def.z))
	var definition: Dictionary = TASK_DATA.data.workTaskDefinitions.get(zone,{})
	if not definition.is_empty():
		station = definition.station
		var stations: Array = [station]
		stations.append_array(definition.tasks)
		for spot: Dictionary in stations: _build_prop(spot)
	# Always show named starter spots, not only after the player guesses where
	# to begin. After a shift starts only its active task gets the gold cue.
	if zone in ["cafe","store"]:
		var starter: Dictionary = TASK_DATA.data.starterQuests.get(zone,{})
		for step: Dictionary in starter.get("steps",[]):
			var at := Vector3(float(step.x),0,float(step.z))-room_origin
			var cue := art.mark_task(at,String(step.label),"blue")
			cue.name = "Starter"+String(step.id).to_pascal_case()
			var caption := cue.get_child(cue.get_child_count()-1) as Label3D
			caption.position.y = 1.25
			caption.font_size = 33
			starter_markers[String(step.label)] = cue
	if zone=="store": _build_prop(TASK_DATA.data.parcelStation)
	_build_hud(hud)

func _build_hud(hud: CanvasLayer) -> void:
	panel = PanelContainer.new()
	panel.name = "IndoorJobChecklist"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left=-270
	panel.offset_right=-16
	panel.offset_top=86
	panel.offset_bottom=87
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#273745e6")
	style.set_corner_radius_all(10)
	style.content_margin_left=12
	style.content_margin_right=12
	style.content_margin_top=10
	style.content_margin_bottom=10
	panel.add_theme_stylebox_override("panel",style)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	title=Label.new()
	title.add_theme_color_override("font_color",Color("#ffda82"))
	title.add_theme_font_size_override("font_size",17)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	tasks=Label.new()
	tasks.add_theme_font_size_override("font_size",14)
	tasks.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tasks.mouse_filter=Control.MOUSE_FILTER_IGNORE
	col.add_child(tasks)
	progress=ProgressBar.new()
	progress.show_percentage=false
	progress.custom_minimum_size.y=7
	progress.max_value=1.0
	progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	col.add_child(progress)
	panel.hide()

func update_status(snapshot: Dictionary, current: Dictionary, dialog_visible: bool, suggested: Dictionary = {}) -> void:
	if not is_instance_valid(panel): return
	if not is_instance_valid(art): return
	var work: Dictionary = snapshot.get("work",{})
	var starter: Dictionary = snapshot.get("starter",{}).get("run",{})
	var parcel: Dictionary = snapshot.get("job",{})
	var name_: String = work.get("name",starter.get("name",""))
	var run := work if not work.is_empty() else starter
	var definition: Dictionary = TASK_DATA.data.workTaskDefinitions.get(name_,{}) if not work.is_empty() else TASK_DATA.data.starterQuests.get(name_,{})
	panel.visible = not dialog_visible and not current.is_empty() and (not definition.is_empty() or parcel.get("stage","none")=="pickup")
	var active_id: String = current.get("id","")
	var display := current if not current.is_empty() else suggested
	for label: String in starter_markers:
		starter_markers[label].visible = current.is_empty() and not dialog_visible
	if current.is_empty() and starter_markers.has(String(display.get("label",""))):
		display = {}
	var signature := "%s:%s:%s" % [display.get("id",""),display.get("position",Vector3.ZERO),dialog_visible]
	if signature!=last_marker:
		last_marker=signature
		if is_instance_valid(marker): marker.queue_free()
		if not display.is_empty() and not dialog_visible: marker = art.mark_task(display.position,display.get("label","Next job step"),"gold" if not current.is_empty() else "blue")
	var started := float(run.get("started",-1))
	var pending := started>=0 and float(current.get("durationMs",0))>0
	for key: String in props:
		var prop: Dictionary = props[key]
		prop.ring.visible = active_id in prop.ids
		if prop.ring.visible: prop.ring.scale = Vector3.ONE * (1.0+.07*sin(Time.get_ticks_msec()*.005))
		if is_instance_valid(prop.spark): prop.spark.visible = prop.ring.visible and pending
	if not panel.visible: return
	var mode := "%s:%d:%s" % [name_,int(run.get("step",0)),active_id]
	if mode!=last_mode:
		last_mode=mode
		var lines: Array[String]=[]
		if definition.is_empty():
			title.text="Parcel delivery"
			lines=["› Collect parcel at Town Store","○ Read its delivery destination"]
		else:
			title.text=definition.get("title",name_.capitalize())
			var steps: Array=definition.get("tasks",definition.get("steps",[]))
			var step: int=run.get("step",0)
			for i in range(steps.size()):
				var prefix: String = "✓ " if i<step else ("› " if i==step else "○ ")
				lines.append(prefix+str(steps[i].label))
		tasks.text="\n".join(lines)
	progress.visible=pending
	if pending: progress.value=clampf((Time.get_unix_time_from_system()-started)*1000.0/float(current.durationMs),0.0,1.0)

func _build_prop(spot: Dictionary) -> void:
	var kind: String = spot.get("kind","parcel" if spot.get("id")=="parcel" else "clipboard")
	var at := Vector3(float(spot.x),0,float(spot.z))-room_origin
	var key := "%s:%s" % [kind,at]
	if props.has(key):
		props[key].ids.append(spot.id)
		return
	var contents := Node3D.new()
	contents.name = "Station"+str(spot.id).to_pascal_case()
	art.add_child(contents)
	contents.position=at+Vector3(-1.1 if kind=="customer" else 0.0,.02,-.9 if kind=="dog" else -.65)
	match kind:
		"brush", "care-kit":
			_table(contents)
			_box(contents,Vector3(.05,.64,.13),Vector3(.12,.07,.47),"799f9b")
			_box(contents,Vector3(.05,.68,-.14),Vector3(.27,.09,.28),"c68a63")
			for i in range(4):
				_box(contents,Vector3(-.03+i*.053,.73,-.14),Vector3(.018,.082,.22),"69524a")
		"dog":
			art.piece("rugRectangle",Vector3.ZERO,Vector3(1.35,.03,1.1),0,false,contents)
			art.piece("animal-dog",Vector3(0,.035,0),Vector3(0,.82,0),0,false,contents)
		"customer":
			var model := art.piece("character-female-c",Vector3.ZERO,Vector3(0,1.57,0),PI/2,false,contents)
			var anim := model.find_children("*","AnimationPlayer",true,false)
			if not anim.is_empty() and anim[0].has_animation("idle"): anim[0].play("idle")
		"bowl":
			_cylinder(contents,Vector3(0,.105,0),.27,.18,"8fc4db")
			_cylinder(contents,Vector3(0,.204,0),.22,.017,"54a9cd")
		"plate", "muffin":
			_table(contents)
			art.piece("food/"+("plate-rectangle" if kind=="plate" else "muffin"),Vector3(0,.63,0),Vector3(.45,.07 if kind=="plate" else .27,.4),0,false,contents)
		"tray":
			_table(contents)
			_box(contents,Vector3(0,.65,0),Vector3(.77,.045,.51),"c7bb8e")
			art.piece("food/cup-coffee",Vector3(.16,.68,.04),Vector3(.24,.19,.25),0,false,contents)
			art.piece("food/plate-rectangle",Vector3(-.12,.68,-.03),Vector3(.3,.035,.28),0,false,contents)
		"ribbon":
			_table(contents)
			for pos: float in [-.13,.13]:
				var tie := _box(contents,Vector3(pos,.68,0),Vector3(.23,.11,.24),"d28db8")
				tie.rotation.y=signf(pos)*.4
			_cylinder(contents,Vector3(0,.69,0),.09,.135,"e6b774")
		"package", "parcel":
			_box(contents,Vector3(0,.27,0),Vector3(.58,.54,.48),"c59560")
			_box(contents,Vector3(0,.544,0),Vector3(.13,.018,.48),"e7c887")
			_box(contents,Vector3(.13,.56,-.08),Vector3(.22,.012,.18),"f6edce")
		"book", "book-basket", "blue-book", "red-book":
			_table(contents)
			var tint := "c77975" if kind=="red-book" else "5996b6"
			for i in range(3 if kind=="book-basket" else 1):
				_box(contents,Vector3(0,.67+i*.11,0),Vector3(.52,.09,.35),tint)
				_box(contents,Vector3(0,.67+i*.11,.18),Vector3(.43,.054,.018),"f3e7bd")
		"coins", "copper-coins", "silver-coins", "gold-coins", "coin-pouch":
			_table(contents)
			_box(contents,Vector3(0,.65,0),Vector3(.76,.045,.52),"64879b")
			var tint := "c88858" if kind=="copper-coins" else ("d0dadd" if kind=="silver-coins" else "edcd67")
			for i in range(6):
				_cylinder(contents,Vector3((i%3-1)*.2,.705,float(i/3)*.14-.12),.073,.045,tint)
		_:
			_table(contents)
			_box(contents,Vector3(0,.64,0),Vector3(.54,.035,.39),"ad906c" if kind=="clipboard" else "ba8aa9")
			for i in range(3):
				_box(contents,Vector3(0,.663,-.1+i*.09),Vector3(.32,.012,.02),"fff2d4")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius=.45
	torus.outer_radius=.52
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color("#ffdc70")
	ring.mesh=torus
	ring.material_override=mat
	ring.position=Vector3(0,.034,0)
	contents.add_child(ring)
	ring.hide()
	var spark: Node3D
	if kind=="dog":
		spark=Node3D.new()
		contents.add_child(spark)
		spark.position.y=1
		for i in range(3):
			var point := Vector3((i-1)*.27,sin(i)*.18,.08)
			_box(spark,point,Vector3(.045,.21,.045),"fff1a6")
			_box(spark,point,Vector3(.18,.047,.047),"fff1a6")
		spark.hide()
	props[key]={"ids":[spot.id],"ring":ring,"spark":spark}

func _table(parent: Node3D) -> void:
	_box(parent,Vector3(0,.56,0),Vector3(.83,.09,.61),"cfae87")
	for x: float in [-.33,.33]:
		for z: float in [-.22,.22]:
			_box(parent,Vector3(x,.27,z),Vector3(.064,.54,.064),"ab8b6c")

func _box(parent: Node3D,at: Vector3,size: Vector3,tint: String) -> Node3D:
	return art.box("JobProp",at,size,Color(tint),false,1,parent)

func _cylinder(parent: Node3D,at: Vector3,radius: float,height: float,tint: String) -> void:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=10
	item.mesh=mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(tint)
	item.material_override=mat
	parent.add_child(item)
	item.position=at
