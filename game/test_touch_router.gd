
extends SceneTree
const ROUTER=preload("res://game/touch_router.gd")
class TestPlayer extends CharacterBody3D:
	var held: Dictionary = {}
var router := ROUTER.new()
var actions: Dictionary = {}
var look := Vector2.ZERO
func _initialize() -> void:
	call_deferred("_run")
func tap(index: int, point: Vector2, down: bool = true, blocked: bool = false, canceled: bool = false) -> bool:
	var ev := InputEventScreenTouch.new()
	ev.index=index
	ev.position=point
	ev.pressed=down
	ev.canceled=canceled
	return router.route(ev,blocked,1000)
func drag(index: int, delta: Vector2, blocked: bool = false) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index=index
	ev.screen_relative=delta
	router.route(ev,blocked,1000)
func emulated(point: Vector2, down: bool, blocked: bool) -> bool:
	var ev:=InputEventMouseButton.new()
	ev.device=-1
	ev.button_index=MOUSE_BUTTON_LEFT
	ev.position=point
	ev.pressed=down
	return router.route(ev,blocked,1000)
func count_action(label: String) -> void:
	actions[label]=actions.get(label,0)+1
func _run() -> void:
	var hud := CanvasLayer.new()
	root.add_child(hud)
	var player := TestPlayer.new()
	root.add_child(player)
	var pad:=Control.new()
	hud.add_child(pad)
	var up := Button.new()
	up.position=Vector2(30,420)
	up.size=Vector2(70,45)
	pad.add_child(up)
	router.register_direction(up,"up")
	var controls: Dictionary = {}
	for label: String in ["Jump","E","Cast","Put Away","Multiplayer"]:
		var button := Button.new()
		button.text=label
		button.position=Vector2(850,50+60*controls.size())
		button.size=Vector2(130,45)
		hud.add_child(button)
		button.pressed.connect(func(): count_action(label))
		controls[label]=button
	router.configure(hud,player,controls.Jump,func(): count_action("Jump"),func(v: Vector2,k: float): look+=v*k)
	# Camera remains owned by one world finger while a pad finger moves, independently.
	assert(tap(1,Vector2(52,440)))
	assert(player.held.has("up"))
	assert(tap(2,Vector2(700,360)))
	drag(2,Vector2(100,0))
	assert(is_equal_approx(look.x,.5))
	assert(tap(3,Vector2(52,440)))
	assert(tap(1,Vector2(52,440),false))
	assert(player.held.has("up"),"same direction still owned by another finger")
	assert(tap(3,Vector2(52,440),false))
	assert(not player.held.has("up"))
	# HUD taps start on the right side without hijacking either current or later look.
	for label: String in controls:
		var point: Vector2 = controls[label].position+Vector2(10,10)
		assert(emulated(point,true,false))
		assert(tap(7,point))
		drag(7,Vector2(60,0))
		assert(tap(7,point,false))
		assert(emulated(point,false,true),"consume synthetic release even if action opens a modal")
		assert(actions[label]==1)
	assert(is_equal_approx(look.x,.5))
	drag(2,Vector2(100,0))
	assert(is_equal_approx(look.x,1.0))
	# Releasing outside, a cancelled touch, and modal touches must not fire world commands.
	var p2: Vector2 = controls.E.position+Vector2(10,10)
	assert(tap(6,p2));assert(tap(6,Vector2(600,60),false))
	assert(tap(6,p2));assert(tap(6,p2,false,false,true))
	assert(not tap(6,p2,true,true))
	assert(not emulated(p2,true,true));assert(not emulated(p2,false,true))
	assert(actions.E==1)
	router.reset()
	drag(2,Vector2(100,0))
	assert(is_equal_approx(look.x,1.0))
	assert(tap(8,Vector2(700,360)));drag(8,Vector2(100,0))
	assert(is_equal_approx(look.x,1.5))
	router.set_mouse_direction("up",true); assert(player.held.has("up"))
	router.reset(); assert(not player.held.has("up"))
	var desktop:=InputEventMouseButton.new()
	desktop.device=0
	desktop.button_index=MOUSE_BUTTON_LEFT
	desktop.pressed=true
	assert(not router.route(desktop,false,1000))
	print("PASS touch ownership: Jump/E/Cast/Put Away/Multiplayer, duplicate suppression, multiple move/look fingers, cancel/modal/reset, desktop pass-through")
	quit()

