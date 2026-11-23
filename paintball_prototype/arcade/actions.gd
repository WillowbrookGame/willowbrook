extends RefCounted

const PORT := Vector2(480,360)
const DIRECTIONS := {"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP,"down":Vector2.DOWN}
const PALETTE := [Color("#f0ac9e"),Color("#e5cd72"),Color("#96c4aa"),Color("#99b8df")]
var id: String
var held: Dictionary
var s: Dictionary
var rng := RandomNumberGenerator.new()

func setup(value: String) -> void:
	id=value
	rng.randomize()
	held={}
	s={"score":0,"elapsed":0.0,"cool":0.0,"done":false,"paused":false,"text":""}
	match id:
		"road-hop":
			s.merge({"pos":Vector2(4,0),"best":0,"top":7,"lanes":{}})
			s.text="Cross as far as you can. Dodge vehicles and trees!"
			for row:int in range(1,8):
				_road_lane(row)
		"brick-breaker":
			s.merge({"paddle":240.0,"ball":Vector2(240,307),"velocity":Vector2(120,-180),"alive":28,"tries":3,"launched":false,"blocks":[],"width":90.0,"power":Vector2(-1,-1),"wide":0.0,"level":1})
			_bricks()
			s.text="Move the paddle, then press Launch."
		"maze-chase":
			s.merge({"pos":PORT*.5,"vel":Vector2.ZERO,"angle":-PI/2,"shots":[],"foes":[],"round":1,"tries":3,"safe":2.0})
			_rocks()
			s.text="Turn, thrust and fire. Clear the asteroid field!"
		"survivors":
			s.merge({"pos":PORT*.5,"target":Vector2(-1,-1),"shots":[],"foes":[],"gems":[],"spawn":0.5,"hp":5,"safe":0.0,"xp":0,"level":1,"upgrade":false,"power":1,"speed":100.0,"rate":0.67,"choice":0})
			s.text="Keep moving. Your weapon fires automatically."

func message() -> String:
	return String(s.get("text",""))

func input(action:String,down:bool) -> void:
	if s.is_empty():
		return
	if DIRECTIONS.has(action) or action=="action":
		held[action]=down
	if not down or s.done:
		return
	if action=="pause" or action=="p":
		s.paused=not s.paused
		held.clear()
		return
	if s.paused:
		return
	if id=="road-hop":
		_road_move(action)
	elif id=="brick-breaker" and action=="action":
		s.launched=true
		s.text="Bounce the ball into the blocks. Catch falling power-ups!"
	elif id=="survivors" and s.upgrade:
		if action=="left" or action=="up":
			s.choice=posmod(s.choice-1,3)
		elif action=="right" or action=="down":
			s.choice=posmod(s.choice+1,3)
		elif action=="action":
			_pick_upgrade(s.choice)

func pointer(at:Vector2) -> void:
	if s.done or s.paused:
		return
	if id=="brick-breaker":
		s.paddle=clampf(at.x,s.width*.5,480-s.width*.5)
	if id=="survivors":
		if s.upgrade and at.y>130 and at.y<230:
			_pick_upgrade(clampi(int(at.x/160.0),0,2))
		elif not s.upgrade:
			s.target=at
	if id=="road-hop":
		var step:Vector2 = at - _road_pixel()
		if step.length()>12:
			_road_move(("left" if step.x<0 else "right") if absf(step.x)>absf(step.y) else ("up" if step.y<0 else "down"))

func tick(dt:float) -> void:
	if s.is_empty() or s.done or s.paused or not is_finite(dt) or dt<=0:
		return
	dt=minf(dt,.05)
	if id=="survivors" and s.upgrade:
		return
	s.elapsed+=dt
	s.cool=maxf(0,s.cool-dt)
	match id:
		"road-hop": _road_tick()
		"brick-breaker": _brick_tick(dt)
		"maze-chase": _space_tick(dt)
		"survivors": _survivor_tick(dt)

func _road_pixel() -> Vector2:
	return Vector2((s.pos.x+.5)*480.0/9.0,64+(s.top-s.pos.y)*36)

func _road_lane(row:int) -> Dictionary:
	if row<=0:
		return {"kind":"grass"}
	if not s.lanes.has(row):
		var option:=rng.randi_range(0,4)
		if option==0:
			s.lanes[row]={"kind":"trees","trees":[rng.randi_range(0,2),rng.randi_range(3,5),rng.randi_range(6,8)]}
		elif option<=3:
			s.lanes[row]={"kind":"cars","speed":rng.randf_range(1.0,1.65)*(-1 if rng.randf()<.5 else 1),"phase":rng.randf_range(0,14),"truck":option==3}
		else:
			s.lanes[row]={"kind":"grass"}
	return s.lanes[row]

func _road_cars(lane:Dictionary) -> Array[float]:
	var result:Array[float]=[]
	if lane.kind=="cars":
		var positions: Array = [0.0,7.0] if lane.truck else [0.0,4.7,9.4]
		for x:float in positions:
			result.append(fposmod(x+s.elapsed*lane.speed+lane.phase,14.0)-2.0)
	return result

func _road_move(action:String) -> void:
	if s.cool>0 or not DIRECTIONS.has(action):
		return
	var step:Vector2=DIRECTIONS[action]
	step.y*=-1
	var destination:Vector2=(s.pos+step).clamp(Vector2(0,maxi(0,s.top-7)),Vector2(8,INF))
	var lane:=_road_lane(int(destination.y))
	if lane.kind=="trees" and int(destination.x) in lane.trees:
		return
	s.pos=destination
	s.cool=.14
	if s.pos.y>s.best:
		s.best=int(s.pos.y)
		s.score=s.best
		s.top=maxi(7,s.best+3)
		_road_lane(s.top)
		if s.top>10:
			s.lanes.erase(s.top-9)

func _road_tick() -> void:
	var lane:=_road_lane(int(s.pos.y))
	for x:float in _road_cars(lane):
		if absf(x-s.pos.x)<(1.13 if lane.truck else .81):
			_finish("Crossing complete: %d lanes. Play again to beat it!"%s.best)
			return
	for key:String in DIRECTIONS:
		if held.get(key,false):
			_road_move(key)
			break

func _bricks() -> void:
	s.blocks=[]
	for i:int in range(28):
		s.blocks.append(Rect2(22+(i%7)*63,55+floori(i/7.0)*25,57,18))
	s.alive=s.blocks.size()

func _brick_tick(dt:float) -> void:
	if s.elapsed>=120:
		_finish("Time's up! %d points."%s.score)
		return
	s.wide=maxf(0,s.wide-dt)
	s.width=126.0 if s.wide>0 else 90.0
	s.paddle=clampf(s.paddle+_movement().x*300*dt,s.width*.5,480-s.width*.5)
	if s.power.x>=0:
		s.power.y+=93*dt
		if s.power.y>=314:
			if absf(s.power.x-s.paddle)<s.width*.5+6:
				s.wide=12.0
				s.text="Wide paddle power-up!"
			s.power=Vector2(-1,-1)
	if not s.launched:
		s.ball=Vector2(s.paddle,307)
		return
	var steps:=maxi(1,ceili(dt/.006))
	for i:int in range(steps):
		var before:Vector2=s.ball
		s.ball+=s.velocity*(dt/steps)
		if s.ball.x<7 or s.ball.x>473:
			s.ball.x=clampf(s.ball.x,7,473)
			s.velocity.x*=-1.0
		if s.ball.y<39:
			s.ball.y=39
			s.velocity.y=absf(s.velocity.y)
		if s.velocity.y>0 and before.y<=309 and s.ball.y>=309 and absf(s.ball.x-s.paddle)<=s.width*.5+4:
			s.ball.y=309.0
			s.velocity=Vector2(clampf((s.ball.x-s.paddle)*4,-218,218),-absf(s.velocity.y))
		for j:int in range(s.blocks.size()):
			if s.blocks[j]==null:
				continue
			var block:Rect2=s.blocks[j]
			var grown:=block.grow(6)
			if grown.has_point(s.ball):
				if before.x<grown.position.x or before.x>=grown.end.x:
					s.velocity.x*=-1
				else:
					s.velocity.y*=-1
				s.ball=before
				s.blocks[j]=null
				s.score+=20
				s.alive-=1
				if j%7==3 and s.power.x<0:
					s.power=block.get_center()
				if s.alive==0:
					if s.level>=3:
						_finish("All three sectors cleared! %d points."%s.score)
					else:
						s.level+=1
						s.launched=false
						s.velocity=Vector2(120,-180-24*(s.level-1))
						_bricks()
						s.text="Next sector! Press Launch."
					return
				break
		if s.ball.y>355:
			s.tries-=1
			s.launched=false
			s.velocity=Vector2(120,-180-24*(s.level-1))
			s.text="Press Launch for another ball."
			if s.tries<=0:
				_finish("Out of balls. %d points."%s.score)
			return

func _movement() -> Vector2:
	return Vector2(int(held.get("right",false))-int(held.get("left",false)),int(held.get("down",false))-int(held.get("up",false))).limit_length()

func _finish(text:String) -> void:
	s.done=true
	s.text=text
	held.clear()

func _wrap(pos:Vector2) -> Vector2:
	return Vector2(fposmod(pos.x,PORT.x), fposmod(pos.y,PORT.y))

func _rocks() -> void:
	for n:int in range(mini(3+s.round,10)):
		var pos:= Vector2(rng.randf_range(0,480),rng.randf_range(0,360))
		if pos.distance_to(s.pos)<85:
			pos.x=fposmod(pos.x+140,480)
		_rock(pos,22.0)

func _rock(pos:Vector2,radius:float) -> void:
	s.foes.append({"pos":pos,"r":radius,"v":Vector2.RIGHT.rotated(rng.randf_range(0,TAU))*rng.randf_range(30,65),"angle":rng.randf_range(0,PI)})

func _space_tick(dt:float) -> void:
	var move:=_movement()
	s.angle+=move.x*3.5*dt
	var forward:=Vector2.RIGHT.rotated(s.angle)
	if move.y<0:
		s.vel=(s.vel+forward*210*dt).limit_length(205)
	s.vel*=exp(-.62*dt)
	s.pos=_wrap(s.pos+s.vel*dt)
	s.safe=maxf(0,s.safe-dt)
	if held.get("action",false) and s.cool<=0:
		_fire(forward,365.0,.86)
		s.cool=.16
	for foe:Dictionary in s.foes:
		foe.pos=_wrap(foe.pos+foe.v*dt)
		foe.angle+=dt*.6
		if s.safe<=0 and s.pos.distance_to(foe.pos)<foe.r+8:
			s.tries-=1
			s.safe=2.4
			s.pos=PORT*.5
			s.vel=Vector2.ZERO
			if s.tries<=0:
				_finish("Run complete: %d points."%s.score)
				return
	_update_shots(dt,true)
	if s.foes.is_empty():
		s.round+=1
		s.safe=2
		_rocks()
		s.text="Sector %d. More asteroids incoming!"%s.round

func _fire(direction:Vector2,speed:float,ttl:float) -> void:
	s.shots.append({"pos":s.pos+direction*11,"v":direction*speed,"ttl":ttl})

func _update_shots(dt:float,space:bool) -> void:
	for i:int in range(s.shots.size()-1,-1,-1):
		var shot:Dictionary=s.shots[i]
		shot.pos+=shot.v*dt
		shot.ttl-=dt
		if space:
			shot.pos=_wrap(shot.pos)
		if shot.ttl<=0:
			s.shots.remove_at(i)
			continue
		for j:int in range(s.foes.size()-1,-1,-1):
			var foe:Dictionary=s.foes[j]
			if shot.pos.distance_to(foe.pos)>=foe.r+3:
				continue
			if space:
				s.score+=int(48-foe.r)
				s.foes.remove_at(j)
				if foe.r>12:
					_rock(foe.pos,foe.r*.56)
					_rock(foe.pos,foe.r*.56)
			else:
				foe.hp-=s.power
				if foe.hp<=0:
					s.score+=10
					s.gems.append(foe.pos)
					s.foes.remove_at(j)
			s.shots.remove_at(i)
			break

func _survivor_tick(dt:float) -> void:
	var move:=_movement()
	if move==Vector2.ZERO and s.target.x>=0:
		if s.pos.distance_to(s.target)>7:
			move=s.pos.direction_to(s.target)
		else:
			s.target=Vector2(-1,-1)
	s.pos=(s.pos+move*s.speed*dt).clamp(Vector2(12,36),Vector2(468,348))
	s.safe=maxf(0,s.safe-dt)
	s.spawn-=dt
	if s.spawn<=0 and s.foes.size()<44:
		s.spawn=maxf(.33,1.0-s.elapsed*.005)
		var pos:=Vector2(rng.randf_range(10,470),38 if rng.randf()<.5 else 350)
		if rng.randf()<.55:
			pos=Vector2(8 if rng.randf()<.5 else 472,rng.randf_range(40,350))
		s.foes.append({"pos":pos,"r":9.0,"hp":1+floori(s.elapsed/55.0),"speed":rng.randf_range(26,46)+s.elapsed*.18})
	var closest:Vector2=s.pos
	var distance:=INF
	for foe:Dictionary in s.foes:
		foe.pos=foe.pos.move_toward(s.pos,foe.speed*dt)
		var d:float=s.pos.distance_to(foe.pos)
		if d<distance:
			distance=d
			closest=foe.pos
		if d<17 and s.safe<=0:
			s.hp-=1
			s.safe=1.15
			foe.pos+=s.pos.direction_to(foe.pos)*26
			if s.hp<=0:
				_finish("Run complete: %d points."%s.score)
				return
	if distance<INF and s.cool<=0:
		_fire(s.pos.direction_to(closest),250,1.4)
		s.cool=s.rate
	_update_shots(dt,false)
	for i:int in range(s.gems.size()-1,-1,-1):
		var gem:Vector2=s.gems[i]
		var gap:float=s.pos.distance_to(gem)
		if gap<44:
			s.gems[i]=gem.move_toward(s.pos,120*dt)
		if gap<14:
			s.xp+=1
			s.gems.remove_at(i)
	if s.xp>=3+s.level*2:
		s.xp-=3+s.level*2
		s.upgrade=true
		s.text="Choose an upgrade."
	if s.elapsed>=180:
		_finish("You survived three minutes! %d points."%s.score)

func _pick_upgrade(choice:int) -> void:
	match choice:
		0: s.power+=1
		1: s.rate=maxf(.21,s.rate-.10)
		2:
			s.hp=mini(s.hp+2,5)
			s.speed=minf(170,s.speed+12)
	s.level+=1
	s.upgrade=false
	s.target=Vector2(-1,-1)
	held.clear()
	s.text="Level %d. Keep moving!"%s.level

func _text(surface:Control,pos:Vector2,label:String,color:=Color.WHITE,points:=16)->void:
	surface.draw_string(ThemeDB.fallback_font,pos,label,HORIZONTAL_ALIGNMENT_LEFT,-1,points,color)

func draw(surface:Control) -> void:
	if s.is_empty():
		return
	match id:
		"road-hop": _draw_road(surface)
		"brick-breaker": _draw_brick(surface)
		"maze-chase": _draw_space(surface)
		"survivors": _draw_survivors(surface)
	if s.paused:
		surface.draw_rect(Rect2(0,0,480,360),Color(0,0,0,.76))
		_text(surface,Vector2(157,185),"Paused  |  Press P",Color.WHITE,19)

func _draw_road(c:Control)->void:
	c.draw_rect(Rect2(Vector2.ZERO,PORT),Color("#bce7a2"))
	for screen_row:int in range(8):
		var row:int=s.top-screen_row
		var lane:=_road_lane(row)
		var y:=46+screen_row*36
		c.draw_rect(Rect2(0,y,480,36),Color("#647488") if lane.kind=="cars" else Color("#90c979") if row%2==0 else Color("#bcdda3"))
		if lane.kind=="cars":
			for x:int in range(0,480,50):
				c.draw_rect(Rect2(x,y+19,24,2),Color("#eee9b4"))
			for x:float in _road_cars(lane):
				var width:float=120 if lane.truck else 65
				var offset:float=(x+.5)*480.0/9.0-width*.5
				c.draw_rect(Rect2(offset,y+4,width,26),Color("#f3b951") if row%2 else Color("#bf8edd"))
				c.draw_rect(Rect2(offset+19,y+8,23,13),Color("#e5f6ff"))
		if lane.kind=="trees":
			for cell:int in lane.trees:
				var center:=Vector2((cell+.5)*480.0/9.0,y+16)
				c.draw_rect(Rect2(center+Vector2(-4,4),Vector2(8,14)),Color("#82533c"))
				c.draw_circle(center,14,Color("#478860"))
	var here:=_road_pixel()
	c.draw_circle(here,12,Color("#f6eed8"))
	c.draw_circle(here+Vector2(0,-8),7,Color.WHITE)
	c.draw_circle(here+Vector2(2,-10),2,Color("#375d99"))
	c.draw_rect(Rect2(here+Vector2(-4,-16),Vector2(6,5)),Color("#e38778"))
	_text(c,Vector2(12,27),"Road Crossing    Lanes %d"%s.best,Color("#193e43"))

func _draw_brick(c:Control)->void:
	c.draw_rect(Rect2(Vector2.ZERO,PORT),Color("#151e41"))
	for i:int in range(32):
		c.draw_circle(Vector2(posmod(i*113,480),36+posmod(i*79,310)),1,Color("#546ca5"))
	for j:int in range(s.blocks.size()):
		if s.blocks[j]!=null:
			var block:Rect2=s.blocks[j]
			var tint:Color=PALETTE[posmod(floori(j/7.0)+int(s.level)-1,4)]
			c.draw_rect(block,tint)
			c.draw_rect(Rect2(block.position,Vector2(block.size.x,3)),tint.lightened(.38))
	c.draw_rect(Rect2(s.paddle-s.width*.5,316,s.width,12),Color("#78bdf2"))
	c.draw_circle(s.ball,6,Color("#ffc3f2"))
	if s.power.x>=0:
		c.draw_circle(s.power,7,Color("#8afde5"))
	_text(c,Vector2(12,25),"Points %d   Balls %d   Sector %d   %ds"%[s.score,s.tries,s.level,maxi(0,ceili(120-s.elapsed))])

func _draw_space(c:Control)->void:
	c.draw_rect(Rect2(Vector2.ZERO,PORT),Color("#10152b"))
	for i:int in range(39):
		c.draw_circle(Vector2(posmod(i*113,480),28+posmod(i*79,330)),1,Color("#8199bb"))
	for foe:Dictionary in s.foes:
		var points:=PackedVector2Array()
		for j:int in range(9):
			var radius:float=foe.r*(.82+float(posmod(j*11,7))*.03)
			points.append(foe.pos+Vector2.RIGHT.rotated(foe.angle+TAU*j/9)*radius)
		c.draw_colored_polygon(points,Color("#8b7f9a"))
		points.append(points[0])
		c.draw_polyline(points,Color("#b6cbed"),2.0,true)
	for shot:Dictionary in s.shots:
		c.draw_circle(shot.pos,2.5,Color("#ffe58a"))
	if s.safe==0 or int(s.safe*10)%2==0:
		var points:=PackedVector2Array()
		for p:Vector2 in [Vector2(13,0),Vector2(-8,8),Vector2(-5,0),Vector2(-8,-8)]:
			points.append(s.pos+p.rotated(s.angle))
		c.draw_colored_polygon(points,Color("#78eadc"))
	_text(c,Vector2(12,24),"Points %d    Ships %d    Sector %d"%[s.score,s.tries,s.round])

func _draw_survivors(c:Control)->void:
	c.draw_rect(Rect2(Vector2.ZERO,PORT),Color("#263a44"))
	for i:int in range(70):
		c.draw_circle(Vector2(posmod(i*117,480),32+posmod(i*81,320)),2,Color("#354c50"))
	for gem:Vector2 in s.gems:
		c.draw_colored_polygon(PackedVector2Array([gem+Vector2.UP*4,gem+Vector2.RIGHT*4,gem+Vector2.DOWN*4,gem+Vector2.LEFT*4]),Color("#85ece6"))
	for foe:Dictionary in s.foes:
		c.draw_circle(foe.pos,foe.r,Color("#d98993"))
		c.draw_circle(foe.pos+Vector2(-2,-2),2,Color("#56254b"))
	for shot:Dictionary in s.shots:
		c.draw_circle(shot.pos,3,Color("#ffe58a"))
	c.draw_circle(s.pos,10,Color("#b5f68e") if s.safe==0 else Color("#f7eaad"))
	_text(c,Vector2(12,24),"HP %d    Level %d    Gems %d/%d    %ds"%[s.hp,s.level,s.xp,3+s.level*2,ceili(s.elapsed)])
	if s.upgrade:
		c.draw_rect(Rect2(0,100,480,155),Color("#182a40"))
		_text(c,Vector2(12,125),"Choose an upgrade (arrows + Action, or tap)")
		for j:int in range(3):
			c.draw_rect(Rect2(j*160+5,150,150,78),Color("#5f796a") if j==s.choice else Color("#3e5470"))
			_text(c,Vector2(j*160+14,190),["More damage","Faster shots","Heal + speed"][j],Color.WHITE,15)
