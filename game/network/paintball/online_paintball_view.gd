extends Node
## Detached online Paintball view. Reads only the private authority snapshots.
const AVATARS = preload("res://game/avatars/catalog.gd")
const FIT = preload("res://game/hud_fit.gd")
const SFX = preload("res://game/paintball_audio.gd")
const COLORS := [Color("#4ce9fc"),Color("#ff7886"),Color("#9cff6b"),Color("#ffbc52")]
var host: Node3D
var session: Node
var hud: CanvasLayer
var panel: CenterContainer
var card: VBoxContainer
var note: Label
var _lobby_room: Dictionary = {}
var _discard_on_resume := false
var status: Label
var popup: Label
var paint_button: Button
var leave_button: Button
var action_button: Button
var match_phase := ""
var owner_pose: Dictionary = {}
var _epoch := ""
var _last_eid := 0
var _round := -1
var _sequence := 0
var _pending := ""
var _since := 0
var _next := 0
var _queued_advance_round := -1
var _jump := false
var _paint := false
var _closed := false
var _actor_root: Node3D
var _actors: Dictionary = {}
var _aliases: Dictionary = {}
var _last_view: Dictionary = {}
var _notice := ""
var _notice_time := 0.0
var _last_start_beat := 0
var _last_end_sec := -1

func setup(world: Node3D, canvas: CanvasLayer, account: Node, in_match: bool) -> void:
	host=world;hud=canvas;session=account
	session.paintball_packet.connect(_incoming)
	if not in_match:
		session.paintball_capability_changed.connect(_refresh_capability)
	panel=CenterContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	var frame:=PanelContainer.new()
	panel.add_child(frame)
	var pad:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		pad.add_theme_constant_override("margin_"+side,16)
	frame.add_child(pad)
	card=VBoxContainer.new()
	pad.add_child(card)
	card.custom_minimum_size.x=minf(340.,get_viewport().get_visible_rect().size.x-50)
	panel.hide()
	if not in_match:
		return
	_epoch=session.paintball_epoch()
	_actor_root=Node3D.new()
	_actor_root.name="PrivatePaintballPeers"
	host.add_child(_actor_root)
	status=Label.new()
	status.position=Vector2(16,143)
	status.add_theme_constant_override("outline_size",5)
	hud.add_child(status)
	popup=Label.new()
	popup.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size",26)
	popup.add_theme_constant_override("outline_size",7)
	popup.mouse_filter=Control.MOUSE_FILTER_IGNORE
	popup.hide()
	hud.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP,Control.PRESET_MODE_MINSIZE,64)
	paint_button=_hud_button("Paint",126.0,paint)
	leave_button=_hud_button("Leave match",190.0,leave)
	paint_button.hide()
	_show_wait("Loading private matchâ€¦")
	call_deferred("_request_ready")

func _hud_button(title: String, offset: float, action: Callable) -> Button:
	var b:=Button.new()
	hud.add_child(b)
	b.text=title
	b.focus_mode=Control.FOCUS_NONE
	b.pressed.connect(action)
	var resize := func():
		var camera := hud.get_node_or_null("CameraThumbstick") as Control
		var scale := FIT.touch_scale(get_viewport()) if camera != null and camera.visible else FIT.physical_scale(get_viewport())
		FIT.right_button(b,Vector2(118,48),offset,scale,true)
	var viewport := get_viewport()
	viewport.size_changed.connect(resize)
	b.tree_exiting.connect(func():
		if is_instance_valid(viewport) and viewport.size_changed.is_connected(resize):
			viewport.size_changed.disconnect(resize),CONNECT_ONE_SHOT)
	resize.call()
	return b

func is_playing() -> bool:
	return not _closed and match_phase=="playing" and session.admitted and not panel.visible

func blocks_world() -> bool:
	return panel.visible or (not _epoch.is_empty() and not is_playing())

func _label(text: String, size:=16) -> Label:
	var l:=Label.new()
	l.text=text
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",size)
	card.add_child(l)
	return l

func _button(title: String, action: Callable) -> Button:
	var b:=Button.new()
	b.text=title
	b.custom_minimum_size.y=44
	card.add_child(b)
	b.pressed.connect(action)
	return b

func _clear_card() -> void:
	for kid in card.get_children():
		card.remove_child(kid)
		kid.queue_free()
	action_button=null

func _panel(value: bool) -> void:
	if panel.visible==value: return
	panel.visible=value
	host.set_zone_modal(value)
	if value: reset_inputs()

func open_lobby() -> void:
	_discard_on_resume=false
	_build_lobby({})
	session.paintball_lobby("state")

func close_lobby() -> void:
	if not _epoch.is_empty(): return
	_discard_on_resume=not session.paintball_lobby("leave")
	_lobby_room.clear()
	_panel(false)

func _refresh_capability() -> void:
	if panel.visible and _epoch.is_empty():
		_build_lobby(_lobby_room)

func _send_lobby(action: String, ready:=false) -> void:
	if not session.paintball_lobby(action,ready):
		note.text="Online Paintball is unavailable. Try again when connected."
		return
	if is_instance_valid(action_button): action_button.disabled=true
	note.text="Joining the lobby..." if action=="join" else "Updating readiness..."

func _build_lobby(room: Dictionary) -> void:
	_lobby_room=room.duplicate(true)
	_clear_card()
	_label("Paintball",24)
	if room.is_empty():
		_label("Play solo or join the shared Multiplayer lobby.")
		_button("Play Solo",func(): close_lobby();host._enter_solo_paintball())
		action_button=_button("Multiplayer",func(): _send_lobby("join"))
		action_button.disabled=not session.can_show_paintball_lobby()
		note=_label("Online Paintball is unavailable right now." if action_button.disabled else "")
	else:
		_label("Multiplayer Lobby",19)
		for person: Dictionary in room.humans:
			var role := " (host)" if person.slot==room.hostSlot else ""
			var state := "Reconnecting" if not person.connected else ("Ready" if person.ready else "Not ready")
			_label(String(person.alias)+role+"  -  "+state)
		var info := ""
		if room.phase=="starting": info="Starting match..."
		elif not room.workerReady: info="Online arena unavailable right now."
		elif room.arenaBusy: info="A match is running. This group is waiting for the next round of play."
		elif room.humans.size()<2: info="Waiting for another player. You can mark Ready now."
		else: info="Starts as soon as everyone is Ready. Computer players fill open spots."
		_label(info)
		var self_ready := false
		for person: Dictionary in room.humans:
			if person.slot==room.selfSlot: self_ready=person.ready;break
		action_button=_button("Not Ready" if self_ready else "Ready",func():_send_lobby("ready",not self_ready))
		action_button.disabled=room.phase=="starting" or not room.workerReady
		note=_label(String(room.notice))
	_button("Close" if room.is_empty() else "Leave Lobby",close_lobby)
	_panel(true)

func _show_wait(text: String) -> void:
	_clear_card()
	_label("Private Paintball",24)
	note=_label(text)
	_button("Back to Town",leave)
	_panel(true)

func _request_ready() -> void:
	if not session.admitted or _epoch.is_empty() or _closed:return
	_send("ready")

func leave() -> void:
	if _closed:
		host._return_to_town_after_match()
		return
	_queued_advance_round=-1
	reset_inputs()
	if not session.admitted or not session.paintball_match("leave",_epoch):
		_finish("Left the private match.")
	else:
		_show_wait("Leaving matchâ€¦")
		_pending="leave";_since=Time.get_ticks_msec()

func _finish(text: String) -> void:
	if _closed:return
	_closed=true
	_queued_advance_round=-1
	match_phase="ended"
	_pending=""
	_show_wait(text)
	if is_instance_valid(leave_button):leave_button.hide()
	if is_instance_valid(paint_button):paint_button.hide()
	session.forget_paintball_view(_epoch)

func _incoming(m: Dictionary) -> void:
	if m.type=="paintballLobby":
		if not _epoch.is_empty():return
		if not panel.visible:
			if _discard_on_resume and m.get("room") is Dictionary:
				_discard_on_resume=not session.paintball_lobby("leave")
			return
		if not m.ok:
			if is_instance_valid(note):note.text=String(m.get("error","Could not update the lobby."))
			if is_instance_valid(action_button):action_button.disabled=not session.can_show_paintball_lobby()
		elif m.action!="leave":
			var latest: Dictionary = m.room if m.get("room") is Dictionary else {}
			if _lobby_room!=latest or (m.action=="ready" and is_instance_valid(action_button) and action_button.disabled and latest.get("phase")!="starting"):
				_build_lobby(latest)
			if m.has("reason") and is_instance_valid(note):note.text=String(m.reason)
		return
	if _epoch.is_empty() or _closed:return
	if m.action=="enter":
		if m.epoch==_epoch:
			_pending="";_sequence=0;_request_ready()
		return
	if m.has("epoch") and m.epoch!=_epoch:return
	if m.action=="ended" or (m.action=="leave" and bool(m.get("returnTown",false))):
		_finish(String(m.get("text","Returned to Town.")))
		if m.action=="leave":host._return_to_town_after_match()
		return
	if m.get("epoch","")!=_epoch and m.get("ok",false):return
	if m.action==_pending:_pending=""
	if m.get("view") is Dictionary: _apply_view(m.view)
	if not bool(m.ok) and m.action!="ready":
		if m.action in ["view","next","input"] and m.has("error"):
			_finish(String(m.error))
		return

func _send(action: String, frame: Dictionary = {}) -> bool:
	if not _pending.is_empty() or not session.paintball_match(action,_epoch,frame):return false
	_pending=action
	_since=Time.get_ticks_msec()
	return true

func reset_inputs() -> void:
	_jump=false;_paint=false

func jump() -> void:
	if is_playing():_jump=true

func paint() -> void:
	if is_playing():_paint=true

func _frame() -> Dictionary:
	var p: CharacterBody3D=host.player
	var axis: Vector2=Input.get_vector("ui_left","ui_right","ui_up","ui_down")+p.analog_motion()
	if Input.is_physical_key_pressed(KEY_A):axis.x-=1
	if Input.is_physical_key_pressed(KEY_D):axis.x+=1
	if Input.is_physical_key_pressed(KEY_W):axis.y-=1
	if Input.is_physical_key_pressed(KEY_S):axis.y+=1
	axis=axis.limit_length()
	_sequence+=1
	var frame:={"sequence":_sequence,"x":axis.x,"z":axis.y,"yaw":wrapf(host.look_yaw,-PI,PI),"pitch":host.look_pitch,"jump":_jump,"paint":_paint}
	reset_inputs()
	return frame

func tick(dt: float) -> void:
	if _epoch.is_empty() or _closed:return
	var t:=Time.get_ticks_msec()
	if not session.admitted:
		_queued_advance_round=-1
		_pending=""
		if not panel.visible:_show_wait("Reconnecting to the private matchâ€¦")
	elif not _pending.is_empty() and t-_since>2000:
		if _pending=="leave":
			_finish("Connection lost while leaving. Back to Town.")
			return
		_pending=""
	if _queued_advance_round>=0 and session.admitted and _pending.is_empty():
		var valid: bool=match_phase=="between" and _round==_queued_advance_round and _last_view.get("hostSlot","")==_last_view.get("selfSlot","")
		_queued_advance_round=-1
		if valid and _send("next"):return
		if is_instance_valid(action_button):action_button.disabled=false
	if session.admitted and t>=_next and _pending.is_empty():
		_next=t+(55 if is_playing() else 180)
		if is_playing():_send("input",_frame())
		else:_send("view")
	var blend:=1.-exp(-18.*maxf(0.,dt))
	if _notice_time>0.0:
		_notice_time=maxf(0.0,_notice_time-dt)
		if _notice_time<=0.0 and is_instance_valid(popup) and int(_last_view.get("countdownMs",0))<=0:
			popup.hide()
	if not owner_pose.is_empty():
		var p: CharacterBody3D=host.player
		var target:=_vec(owner_pose.position)
		p.position=target if p.position.distance_to(target)>3.5 else p.position.lerp(target,blend)
	for actor: Dictionary in _actors.values():
		var n: Node3D=actor.node
		n.position=n.position.lerp(actor.target,blend)
		n.rotation.y=lerp_angle(n.rotation.y,actor.yaw,blend)
		var label: Label3D=actor.get("label")
		if is_instance_valid(label):
			if bool(actor.get("immune",false)):
				label.text="%s (tagged!)" % actor.alias
				label.modulate=Color.WHITE if int(Time.get_ticks_msec()/120)%2==0 else Color("#ffbc52")
			else:
				label.text=actor.alias
				label.modulate=Color.WHITE

func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

func _apply_view(v: Dictionary) -> void:
	var old_phase:=match_phase
	var old_host: String=_last_view.get("hostSlot","")
	match_phase=v.phase
	_last_view=v
	if v.round!=_round:
		_round=v.round
		_last_start_beat=0
		_last_end_sec=-1
		_notice=""
		_notice_time=0.0
		if is_instance_valid(popup):popup.hide()
		if _round>0: host._reset_arena_round_view()
	var seen:={}
	_aliases.clear()
	for row: Dictionary in v.players:
		_aliases[row.slot]=String(row.get("alias",row.slot))
		if row.slot==v.selfSlot:
			owner_pose=row;continue
		if not row.connected or row.slot.is_empty():continue
		seen[row.slot]=true
		if not _actors.has(row.slot):
			var n:=AVATARS.instantiate(row.get("avatar",AVATARS.DEFAULT))
			_actor_root.add_child(n)
			n.position=_vec(row.position)
			n.rotation.y=float(row.yaw)+PI
			n.scale=Vector3.ONE*2.9
			var label:=Label3D.new()
			label.text=row.alias
			label.position.y=.73
			label.pixel_size=.0021
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			n.add_child(label)
			_actors[row.slot]={"node":n,"anim":AVATARS.animator(n),"label":label,"alias":String(row.alias),"immune":false}
		var rec: Dictionary=_actors[row.slot]
		rec.target=_vec(row.position)
		rec.yaw=float(row.yaw)+PI
		rec.immune=int(row.get("immuneMs",0))>0
		var clip: String="walk" if row.moving else "idle"
		if rec.anim.has_animation(clip) and rec.anim.current_animation!=clip:rec.anim.play(clip)
	for key: String in _actors.keys():
		if not seen.has(key):
			_actors[key].node.queue_free()
			_actors.erase(key)
	var newest:=_last_eid
	for event: Dictionary in v.events:
		if int(event.eid)<=_last_eid:continue
		newest=maxi(newest,int(event.eid))
		if event.kind=="paint" and match_phase=="playing":
			var tint: Color=COLORS[int(event.eid)%4]
			var to_pos:=_vec(event.to)
			var tagged_slot: String=String(event.get("tagged",""))
			var shooter_slot: String=String(event.get("slot",""))
			var on_hit:=Callable()
			if not tagged_slot.is_empty():
				on_hit=host.marker_preview.burst_at.bind(to_pos,tint)
			host.marker_preview._animate_paint(_vec(event.from),to_pos,{},tint,on_hit)
			if shooter_slot==v.selfSlot:
				SFX.play(self,"pop",-7.0,1.0)
			if not tagged_slot.is_empty():
				if shooter_slot==v.selfSlot:
					SFX.play(self,"tag",-5.0,1.0)
					if host.has_method("flash_hitmarker"):host.flash_hitmarker()
					_show_popup("Tagged %s!  +1" % _aliases.get(tagged_slot,"Player"),Color("#4ce9fc"),1.4)
				elif tagged_slot==v.selfSlot:
					SFX.play(self,"tagged",-5.0,1.0)
					var dur:=maxf(0.5,float(event.get("immuneMs",2200))/1000.0)
					if host.has_method("flash_tagged"):host.flash_tagged(tint,dur)
					_show_popup("%s tagged you!" % _aliases.get(shooter_slot,"Player"),Color("#ffbc52"),1.4)
	_last_eid=newest
	match match_phase:
		"playing":
			_panel(false)
			var countdown_ms:=int(v.get("countdownMs",0))
			if countdown_ms>0:
				var beat:=ceili(float(countdown_ms)/650.0)
				if beat!=_last_start_beat and beat>0:
					_last_start_beat=beat
					SFX.play(self,"tick",-7.0,0.92+(3-beat)*0.12)
				if is_instance_valid(popup) and beat>0:
					popup.text="%d" % beat
					popup.add_theme_color_override("font_color",Color("#ffbc52"))
					popup.show()
			elif _last_start_beat>0:
				_last_start_beat=0
				SFX.play(self,"finish",-7.0,1.12)
				_show_popup("PAINT!",Color("#4ce9fc"),0.7)
			var seconds:=ceili(float(v.remainingMs)/1000.)
			if countdown_ms<=0 and seconds<=5 and seconds>0 and seconds!=_last_end_sec:
				_last_end_sec=seconds
				SFX.play(self,"tick",-8.0,1.0+(5-seconds)*0.06)
			var sorted_players: Array = v.players.duplicate()
			sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("points",0)) > int(b.get("points",0)))
			var board := PackedStringArray()
			for i in sorted_players.size():
				var row: Dictionary = sorted_players[i]
				board.append("%d. %s %d" % [i+1, String(row.get("alias","")), int(row.get("points",0))])
			status.text="Round %d / 3   •   %d:%02d   •   You: %d\n%s" % [_round,floori(seconds/60.0),seconds%60,int(owner_pose.get("points",0)),"  ·  ".join(board)]
			paint_button.visible = not host.camera_thumbstick.visible
		"between","finished":
			paint_button.hide()
			if is_instance_valid(popup):popup.hide()
			if old_phase=="playing":SFX.play(self,"finish",-6.0,1.0)
			if old_phase!=match_phase or old_host!=v.hostSlot or not panel.visible:_results(v)
		"loading":
			paint_button.hide()
			if old_phase!=match_phase:_show_wait("Waiting for everyone to load the arena…")
		"abandoned":
			_finish("This private match ended. Back to Town.")

func _show_popup(text: String, color: Color, seconds: float) -> void:
	_notice=text
	_notice_time=seconds
	if is_instance_valid(popup):
		popup.text=text
		popup.add_theme_color_override("font_color",color)
		popup.show()

func _results(v: Dictionary) -> void:
	_clear_card()
	_label("Final rankings" if v.phase=="finished" else "Round %d rankings" % int(v.round),24)
	for row: Dictionary in v.ranking:
		_label("%d. %s  •  %d%s" % [int(row.rank),row.alias,int(row.score)," (left)" if bool(row.left) else ""])
	var reward:=int(v.get("rewardStars",0))
	if v.phase=="finished" and reward>0:
		_label("Match reward: +%d Stars!" % reward,18)
	if v.phase=="between":
		if v.hostSlot==v.selfSlot:
			action_button=_button("Start Round %d" % (int(v.round)+1),_queue_advance)
			action_button.disabled=_queued_advance_round==int(v.round) or _pending=="next"
		else:_label("Waiting for the host to start the next round.")
	var back:=_button("Back to Town",leave)
	_panel(true)
	var primary:=action_button if is_instance_valid(action_button) else back
	if not primary.disabled:primary.call_deferred("grab_focus")

func _queue_advance() -> void:
	if not session.admitted or match_phase!="between" or _pending=="next" or _pending=="leave":return
	if _last_view.get("hostSlot","")!=_last_view.get("selfSlot",""):return
	_queued_advance_round=_round
	if is_instance_valid(action_button):action_button.disabled=true

