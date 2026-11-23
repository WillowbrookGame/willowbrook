extends RefCounted

static func physical_scale(viewport: Viewport) -> float:
	var logical_width := viewport.get_visible_rect().size.x
	var window_width := viewport.get_window().size.x
	return clampf(logical_width/maxf(1.0,window_width),1.0,5.0)


static func touch_scale(viewport: Viewport) -> float:
	var s := physical_scale(viewport)
	if OS.has_feature("web"):
		var css_width: Variant = JavaScriptBridge.eval("document.getElementById('canvas')?.getBoundingClientRect().width || 0",true)
		if (css_width is int or css_width is float) and float(css_width) > 0.0:
			s = maxf(s,viewport.get_visible_rect().size.x/float(css_width))
	return s

static func touch_available() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(navigator.maxTouchPoints || 0) > 0",true))
	return DisplayServer.is_touchscreen_available()

static func right_button(button: Button, size: Vector2, inset_bottom: float, s: float, reserve_camera := false) -> void:
	button.clip_text = true
	button.custom_minimum_size = size*s
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var shift_x := 0.0
	var shift_y := 0.0
	if reserve_camera:
		var camera := button.get_parent().get_node_or_null("CameraThumbstick") as Control
		if camera != null and camera.visible:
			var view := button.get_viewport().get_visible_rect().size
			if view.x/s >= 500.0:
				shift_x = -camera.offset_left
			else:
				shift_y = -camera.offset_top
	button.offset_right = -12.0*s-shift_x
	button.offset_left = -(12.0+size.x)*s-shift_x
	button.offset_bottom = -(12.0+inset_bottom)*s-shift_y
	button.offset_top = -(12.0+inset_bottom+size.y)*s-shift_y


static func left_pad(pad: GridContainer, s: float) -> void:
	pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pad.offset_left = 12.0*s
	pad.offset_top = -104.0*s
	pad.offset_right = 150.0*s
	pad.offset_bottom = -12.0*s
