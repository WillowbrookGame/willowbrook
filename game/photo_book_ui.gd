extends Control
## Reusable tabbed Photo Book / Field Guide modal.
## Displays discoveries provided by gameplay modules (Fishing, and later Scuba)
## without owning any gameplay rules itself.

signal closed

const HUD_FIT = preload("res://game/hud_fit.gd")

var _tabs: Array[Dictionary] = []
var _active_tab_id := ""
var _backdrop: ColorRect
var _center: CenterContainer
var _book_panel: PanelContainer
var _padding: MarginContainer
var _column: VBoxContainer
var _title_label: Label
var _progress_label: Label
var _close_button: Button
var _tab_bar: HBoxContainer
var _scroll: ScrollContainer
var _grid: GridContainer
var _thumb_cache: Dictionary = {}


func _ready() -> void:
	name = "PhotoBook"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.05, 0.11, 0.16, 0.58)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_book_panel = PanelContainer.new()
	_book_panel.name = "BookPanel"
	var book_style := StyleBoxFlat.new()
	book_style.bg_color = Color("#f7f1e3")
	book_style.border_color = Color("#6b4f3a")
	book_style.set_border_width_all(3)
	book_style.set_corner_radius_all(14)
	_book_panel.add_theme_stylebox_override("panel", book_style)
	_center.add_child(_book_panel)

	_padding = MarginContainer.new()
	_book_panel.add_child(_padding)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 10)
	_padding.add_child(_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_column.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	_title_label = Label.new()
	_title_label.name = "BookTitle"
	_title_label.text = "Photo Book"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_color_override("font_color", Color("#2a3742"))
	title_box.add_child(_title_label)

	_progress_label = Label.new()
	_progress_label.name = "BookProgress"
	_progress_label.text = ""
	_progress_label.add_theme_color_override("font_color", Color("#4e6573"))
	title_box.add_child(_progress_label)

	_close_button = Button.new()
	_close_button.name = "CloseBook"
	_close_button.text = "Close"
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(close_book)
	header.add_child(_close_button)

	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "BookTabs"
	_tab_bar.add_theme_constant_override("separation", 8)
	_tab_bar.hide()
	_column.add_child(_tab_bar)

	_scroll = ScrollContainer.new()
	_scroll.name = "BookScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.name = "EntryGrid"
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)

	get_viewport().size_changed.connect(resize_book)
	resize_book()
	hide()


func configure_tabs(tabs: Array[Dictionary]) -> void:
	_tabs = tabs.duplicate(true)
	var valid_active := false
	for tab: Dictionary in _tabs:
		if String(tab.get("id", "")) == _active_tab_id:
			valid_active = true
			break
	if not valid_active:
		_active_tab_id = String(_tabs[0].get("id", "")) if not _tabs.is_empty() else ""
	_rebuild_tabs()
	_rebuild_entries()


func open(tab_id: String = "") -> void:
	if not tab_id.is_empty():
		for tab: Dictionary in _tabs:
			if String(tab.get("id", "")) == tab_id:
				_active_tab_id = tab_id
				break
	elif _active_tab_id.is_empty() and not _tabs.is_empty():
		_active_tab_id = String(_tabs[0].get("id", ""))
	resize_book()
	_rebuild_tabs()
	_rebuild_entries()
	show()
	_close_button.grab_focus()


func close_book() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func active_tab_id() -> String:
	return _active_tab_id


func resize_book() -> void:
	if _book_panel == null or not is_inside_tree():
		return
	var view_size := get_viewport().get_visible_rect().size
	var s := HUD_FIT.physical_scale(get_viewport())
	var logical_w := view_size.x / s
	var logical_h := view_size.y / s
	var narrow := logical_w < 500.0
	var short := logical_h < 440.0

	var target_w := clampf(logical_w - 24.0, 260.0, 680.0) * s
	var target_h := clampf(logical_h - 28.0, 220.0, 540.0) * s
	_book_panel.custom_minimum_size = Vector2(target_w, target_h)

	var pad := roundi((10.0 if narrow or short else 18.0) * s)
	for edge: String in ["left", "right", "top", "bottom"]:
		_padding.add_theme_constant_override("margin_" + edge, pad)
	_column.add_theme_constant_override("separation", roundi((8.0 if short else 12.0) * s))
	_title_label.add_theme_font_size_override("font_size", roundi((20.0 if narrow else 24.0) * s))
	_progress_label.add_theme_font_size_override("font_size", roundi((14.0 if narrow else 16.0) * s))
	_close_button.add_theme_font_size_override("font_size", roundi(16.0 * s))
	_close_button.custom_minimum_size = Vector2(78.0, 40.0) * s

	var cols := 2 if logical_w < 480.0 else (3 if logical_w < 680.0 else 4)
	if _grid.columns != cols:
		_grid.columns = cols
	var sep := roundi((8.0 if narrow else 10.0) * s)
	_grid.add_theme_constant_override("h_separation", sep)
	_grid.add_theme_constant_override("v_separation", sep)
	if visible:
		_rebuild_entries()


func _current_tab() -> Dictionary:
	for tab: Dictionary in _tabs:
		if String(tab.get("id", "")) == _active_tab_id:
			return tab
	return _tabs[0] if not _tabs.is_empty() else {}


func _rebuild_tabs() -> void:
	for child in _tab_bar.get_children():
		_tab_bar.remove_child(child)
		child.queue_free()
	_tab_bar.visible = _tabs.size() > 1
	if not _tab_bar.visible:
		return
	var s := HUD_FIT.physical_scale(get_viewport())
	for tab: Dictionary in _tabs:
		var id := String(tab.get("id", ""))
		var btn := Button.new()
		btn.text = String(tab.get("label", id.capitalize()))
		btn.toggle_mode = true
		btn.button_pressed = id == _active_tab_id
		btn.custom_minimum_size = Vector2(96.0, 36.0) * s
		btn.add_theme_font_size_override("font_size", roundi(15.0 * s))
		btn.pressed.connect(func():
			_active_tab_id = id
			_rebuild_tabs()
			_rebuild_entries()
		)
		_tab_bar.add_child(btn)


func _rebuild_entries() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var tab := _current_tab()
	if tab.is_empty():
		_title_label.text = "Photo Book"
		_progress_label.text = ""
		return
	_title_label.text = String(tab.get("title", tab.get("label", "Photo Book")))
	var entries: Array = tab.get("entries", [])
	var found := 0
	for entry: Dictionary in entries:
		if bool(entry.get("discovered", false)):
			found += 1
	_progress_label.text = "%d / %d discovered" % [found, entries.size()]

	var s := HUD_FIT.physical_scale(get_viewport())
	var narrow := get_viewport().get_visible_rect().size.x / s < 500.0
	var thumb_size := Vector2(84.0, 56.0) * s if narrow else Vector2(102.0, 68.0) * s
	var name_font := roundi((13.0 if narrow else 14.0) * s)

	var found_style := StyleBoxFlat.new()
	found_style.bg_color = Color("#fffdf8")
	found_style.border_color = Color("#4b8b96")
	found_style.set_border_width_all(2)
	found_style.set_corner_radius_all(10)

	var hidden_style := StyleBoxFlat.new()
	hidden_style.bg_color = Color("#e7dfd0")
	hidden_style.border_color = Color("#c4b7a3")
	hidden_style.set_border_width_all(2)
	hidden_style.set_corner_radius_all(10)

	for entry: Dictionary in entries:
		var discovered := bool(entry.get("discovered", false))
		var card := PanelContainer.new()
		card.name = "Entry_" + String(entry.get("id", ""))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", found_style if discovered else hidden_style)

		var margin := MarginContainer.new()
		var card_pad := roundi((6.0 if narrow else 8.0) * s)
		for edge: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, card_pad)
		card.add_child(margin)

		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", roundi(4.0 * s))
		margin.add_child(box)

		var thumb := TextureRect.new()
		thumb.name = "Thumb"
		thumb.custom_minimum_size = thumb_size
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var thumb_path := String(entry.get("thumb", ""))
		var tex := _load_thumb(thumb_path)
		if tex != null:
			thumb.texture = tex
		if not discovered:
			thumb.modulate = Color(0.10, 0.16, 0.20, 0.55)
		box.add_child(thumb)

		var caption := Label.new()
		caption.name = "Caption"
		caption.text = String(entry.get("name", "")) if discovered else "???"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", name_font)
		caption.add_theme_color_override("font_color", Color("#24333d") if discovered else Color("#6e665a"))
		box.add_child(caption)

		_grid.add_child(card)


func _load_thumb(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _thumb_cache.has(path):
		return _thumb_cache[path] as Texture2D
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_thumb_cache[path] = tex
		return tex
	return null
