extends Node3D

const DAY := Color("#b7dce9")
const NIGHT := Color("#879db9")
const CLOUD := Color("#a2b6c2")
const DROP_COUNT := 72

var _env: Environment
var _sun: DirectionalLight3D
var _player: Node3D
var _badge: Label
var _session: Node
var _rain: MultiMeshInstance3D
var _default_sky: Color
var _default_ambient: float
var _default_sun: float
var _view := ""
var _tint_blend := 0.0

func setup(env: Environment, sun: DirectionalLight3D, player: Node3D, badge: Label, session: Node) -> void:
	_env = env
	_sun = sun
	_player = player
	_badge = badge
	_session = session
	_default_sky = env.background_color
	_default_ambient = env.ambient_light_energy
	_default_sun = sun.light_energy
	_badge.hide()

func _process(delta: float) -> void:
	if _session == null or not _session.has_method("outdoor_environment"):
		return
	var state: Dictionary = _session.outdoor_environment()
	var available := not state.is_empty()
	if not available and _view.is_empty() and _tint_blend <= 0.0:
		return
	_tint_blend = move_toward(_tint_blend,1.0 if available else 0.0,minf(delta,0.25)*0.75) if available else 0.0
	if not available:
		_env.background_color = _default_sky
		_env.ambient_light_energy = _default_ambient
		_sun.light_energy = _default_sun
		_badge.hide()
		_view = ""
		if _rain != null: _rain.hide()
		return
	var daylight := (sin(TAU * float(state.phase)) + 1.0) * 0.5
	var weather: String = state.weather
	var sky := NIGHT.lerp(DAY,daylight)
	if weather != "sunny":
		sky = sky.lerp(CLOUD,0.45)
	_env.background_color = _default_sky.lerp(sky,_tint_blend)
	# Keep signs, doors and characters legible at the darkest point.
	_env.ambient_light_energy = lerpf(_default_ambient,maxf(0.36,_default_ambient*(0.8+daylight*0.25)),_tint_blend)
	_sun.light_energy = lerpf(_default_sun,_default_sun*(0.40+daylight*0.60),_tint_blend)
	var label := "Daytime" if daylight > 0.65 else ("Evening" if daylight < 0.35 else "Dawn / dusk")
	var next := "%s · %s" % [label,weather.capitalize()]
	if next != _view:
		_view = next
		_badge.text = next
		_badge.show()
	if weather == "rain":
		if _rain == null: _build_rain()
		_rain.global_position = Vector3(_player.global_position.x,0.0,_player.global_position.z)
		_rain.show()
	elif _rain != null:
		_rain.hide()

func _build_rain() -> void:
	# One unlit instanced draw, GPU-only animation, no scene collisions or lights.
	var script := Shader.new()
	script.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never;
void vertex() {
	VERTEX.y += 10.0 - mod(TIME * 7.0 + INSTANCE_CUSTOM.x * 10.0, 10.0);
	VERTEX.x += VERTEX.y * 0.035;
}
void fragment() {
	ALBEDO = vec3(0.60, 0.73, 0.84);
	ALPHA = 0.32;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = script
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.024,0.23)
	mesh.material = mat
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = DROP_COUNT
	instances.custom_aabb = AABB(Vector3(-11,-1,-11),Vector3(22,12,22))
	var rng := RandomNumberGenerator.new()
	rng.seed = 74013
	for i in DROP_COUNT:
		var pos := Vector3(rng.randf_range(-10,10),0,rng.randf_range(-10,10))
		var rotation := Basis(Vector3.UP,rng.randf_range(0,TAU))
		instances.set_instance_transform(i,Transform3D(rotation,pos))
		instances.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
	_rain = MultiMeshInstance3D.new()
	_rain.name = "Rain"
	_rain.multimesh = instances
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)

