extends SceneTree
## Local transport only; commands arrive on the inherited parent pipe, not a socket.
const POOL = preload("res://paintball_prototype/network/paintball/match_pool.gd")
const FRAME_SIZE := 2048
const MAX_QUEUED := 64
var _pool: POOL
var _pipe := Thread.new()
var _lock := Mutex.new()
var _inbox: Array[String] = []
var _eof := false
var _fault := false
var _stopping := false

func _initialize() -> void:
	call_deferred("_boot")

func _boot() -> void:
	if OS.get_stdin_type() != OS.STD_HANDLE_PIPE or OS.get_stdout_type() != OS.STD_HANDLE_PIPE:
		quit(2)
		return
	_pool=POOL.new()
	root.add_child(_pool)
	if _pipe.start(_read_pipe)!=OK:
		quit(2)
		return
	_emit({"kind":"hello","version":1,"maxRooms":POOL.MAX_ROOMS})

func _read_pipe() -> void:
	while true:
		var b:=OS.read_buffer_from_stdin(FRAME_SIZE)
		if b.is_empty():
			_lock.lock()
			_eof=true
			_lock.unlock()
			return
		if b.size()!=FRAME_SIZE:
			_lock.lock()
			_fault=true
			_lock.unlock()
			return
		var text:=b.get_string_from_utf8().strip_edges()
		_lock.lock()
		if _inbox.size()>=MAX_QUEUED:
			_fault=true
			_lock.unlock()
			return
		_inbox.append(text)
		_lock.unlock()

func _physics_process(_delta: float) -> bool:
	_lock.lock()
	var frames:=_inbox
	_inbox=[]
	var ended:=_eof or _fault
	var fault:=_fault
	_lock.unlock()
	for text: String in frames:
		if not _handle(text):
			_stopping=true
			break
	if ended:
		if _pipe.is_started(): _pipe.wait_to_finish()
		quit(2 if fault or _stopping else 0)
	return false

func _handle(text: String) -> bool:
	var parser:=JSON.new()
	if parser.parse(text)!=OK or not parser.data is Dictionary:
		return false
	var m: Dictionary=parser.data
	if not (m.get("id") is int or m.get("id") is float) or not m.get("op") is String:
		return false
	if _stopping:
		return false
	var result: Dictionary={}
	var now:=_pool.now_ms()
	var key: String=m.get("room","") if m.get("room") is String else ""
	var slot: String=m.get("slot","") if m.get("slot") is String else ""
	var match_room:=_pool.room_for_broker(key)
	match m.op:
		"ping":
			result={"ok":true}
		"open":
			result={"ok":m.get("humans") is Array and _pool.create_room(key,m.humans,slot,now)}
		"close":
			_pool.remove_room(key)
			result={"ok":true}
		"ready":
			result={"ok":match_room!=null and match_room.ready_slot(slot,now)}
		"view":
			var view:=_pool.view_for_member(key,slot,now)
			result={"ok":not view.is_empty(),"view":view}
		"input":
			result={"ok":match_room!=null and m.get("frame") is Dictionary and match_room.input(slot,m.frame,now)}
			var after:=_pool.view_for_member(key,slot,now)
			if not after.is_empty(): result.view=after
		"next":
			result={"ok":match_room!=null and match_room.next_round(slot,now)}
		"disconnect":
			if match_room!=null: match_room.disconnect_player(slot,now)
			result={"ok":match_room!=null}
		"resume":
			result={"ok":match_room!=null and match_room.reconnect(slot,now)}
		"leave":
			result=match_room.leave(slot) if match_room!=null else {"ok":false}
		_:
			return false
	_emit({"kind":"reply","id":int(m.id),"result":result})
	return true

func _emit(value: Dictionary) -> void:
	print("WBPA1:",JSON.stringify(value))
