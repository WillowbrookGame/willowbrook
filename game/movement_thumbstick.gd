
extends Control
## Fixed left-side thumbstick. Input ownership belongs to TouchRouter.
const DEADZONE := .15
const BASE_SIZE := 120.0
const PAD_MARGIN := 18.0
const TRAVEL_RATIO := .325
const MIN_WEB_CSS_SIZE := 92.0
var _deflection := Vector2.ZERO
var _engaged := false
var camera_control := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)


func fit_hud(logical_width: float, physical_scale: float, lift_css := 0.0) -> void:
	var factor := physical_scale
	if OS.has_feature("web"):
		var css_width: Variant = JavaScriptBridge.eval("document.getElementById('canvas')?.getBoundingClientRect().width || 0",true)
		if (css_width is int or css_width is float) and float(css_width) > 0.0:
			factor = maxf(factor,logical_width/float(css_width))
	var extent := minf(maxf(BASE_SIZE,MIN_WEB_CSS_SIZE * factor),logical_width * .27)
	var inset := maxf(PAD_MARGIN,10.0 * factor)
	offset_left = -inset - extent if camera_control else inset
	offset_right = -inset if camera_control else inset + extent
	offset_top = -inset - extent - lift_css * factor
	offset_bottom = -inset - lift_css * factor


func _travel() -> float:
	return maxf(1.0,minf(size.x,size.y) * TRAVEL_RATIO)


func contains_point(viewport_point: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	var local := get_global_transform_with_canvas().affine_inverse() * viewport_point
	return local.distance_to(size * .5) <= minf(size.x,size.y) * .5


func aim_at(viewport_point: Vector2) -> Vector2:
	var at := get_global_transform_with_canvas().affine_inverse() * viewport_point
	_deflection = ((at - size*.5)/_travel()).limit_length()
	_engaged = true
	queue_redraw()
	var strength := _deflection.length()
	if strength <= DEADZONE:
		return Vector2.ZERO
	return _deflection.normalized() * inverse_lerp(DEADZONE,1.0,strength)


func recenter() -> void:
	_deflection = Vector2.ZERO
	_engaged = false
	queue_redraw()


func _draw() -> void:
	var center := size*.5
	var radius := minf(center.x,center.y)
	var art_scale := radius / (BASE_SIZE*.5)
	draw_circle(center,radius,Color("#162b40b0"),true,-1.0,true)
	draw_arc(center,radius-1.5*art_scale,0,TAU,48,Color("#d9ebf480"),2.0*art_scale,true)
	draw_arc(center,_travel(),0,TAU,40,Color("#d9ebf43b"),art_scale,true)
	var knob := center + _deflection*_travel()
	draw_circle(knob+Vector2(0,2)*art_scale,19.0*art_scale,Color("#112533bb"),true,-1.0,true)
	draw_circle(knob,18.0*art_scale,Color("#f8f4ccf2") if _engaged or camera_control else Color("#d8eaf0db"),true,-1.0,true)
	draw_arc(knob,17.0*art_scale,0,TAU,32,Color("#304c57b0"),1.3*art_scale,true)
	draw_circle(knob,3.0*art_scale,Color("#647e83b3"),true,-1.0,true)
	if camera_control:
		var font := ThemeDB.fallback_font
		var label_size := maxi(9,roundi(12.0*art_scale))
		var label_width := font.get_string_size("LOOK",HORIZONTAL_ALIGNMENT_LEFT,-1,label_size).x
		draw_string(font,Vector2(center.x-label_width*.5,size.y-11.0*art_scale),"LOOK",HORIZONTAL_ALIGNMENT_LEFT,-1,label_size,Color("#edf7ff"))

