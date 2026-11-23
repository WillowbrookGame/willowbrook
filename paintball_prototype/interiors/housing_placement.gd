
extends RefCounted
## Native local housing placement. Room geometry, decor, and placement use the same scale.
const DATA := preload("res://paintball_prototype/interiors/room_data.json")
const ROOM_STRIDE := 12.0
const USABLE_FLOOR := Rect2(-5.35,-4.5,10.7,9.0)
const ENTRY := Rect2(-1.5,1.5,3.0,3.1)
const WEST_PASSAGE := Rect2(-5.4,-1.5,1.3,3.0)
const EAST_PASSAGE := Rect2(4.1,-1.5,1.3,3.0)
# Measurements from the imported fixtures fitted like the original 0.51.0 web art.
const HEIGHTS := {
	"bed":.9,"sofa":1.25,"chair":1.15,"table":.698906,"plant":1.5,"rug":.025,
	"lamp":1.8,"bookshelf":1.7775,"fridge":2.3,"books":.27625,"scavengerTrophy":1.0,
	"coffeeTable":.556736,"bedside":.701353,"counter":1.151163,"sink":1.253488,"stove":1.151163,
}


static func room_count(profile: Dictionary) -> int:
	return clampi(int(DATA.data.homeVariants.get(profile.get("home",{}).get("variant","starter"),{}).get("rooms",1)),1,3)


static func height(kind: String) -> float:
	return HEIGHTS.get(kind,.78)


static func surface_for(kind: String, surface_id: String) -> Dictionary:
	for surface: Dictionary in DATA.data.furnitureSurfaces.get(kind,[]):
		if surface.id == surface_id:
			return surface
	return {}


static func footprint(item: Dictionary, on_surface := false, relative_rotation := -1) -> Rect2:
	var spec: Dictionary = DATA.data.furnitureCatalog.get(item.get("kind",""),{})
	var w := float(spec.get("surfaceWidth" if on_surface else "width",0))
	var d := float(spec.get("surfaceDepth" if on_surface else "depth",0))
	var turns := int(item.get("rotation",0)) if relative_rotation == -1 else relative_rotation
	var size := Vector2(d,w) if posmod(turns,2)==1 else Vector2(w,d)
	var center := Vector2(float(item.get("x",0)),float(item.get("z",0)))
	return Rect2(center-size*.5,size)


static func _player_conflict(rect: Rect2, room: int, player_at: Vector3, radius: float) -> bool:
	if not player_at.is_finite():
		return false
	var coord := Vector2(player_at.x-room*ROOM_STRIDE,player_at.z)
	var closest := Vector2(clampf(coord.x,rect.position.x,rect.end.x),clampf(coord.y,rect.position.y,rect.end.y))
	return coord.distance_squared_to(closest) < radius*radius


static func transform_to_surface(item: Dictionary, supporter: Dictionary, surface: Dictionary) -> Rect2:
	var offset := Vector2(float(item.x)-float(supporter.x),float(item.z)-float(supporter.z))
	var support_turns := int(supporter.get("rotation",0))
	offset = offset.rotated(support_turns*PI/2)
	var relative := posmod(int(item.rotation)-support_turns,4)
	var dims := footprint(item,true,relative).size
	return Rect2(offset-dims*.5,dims)


static func placement_error(item: Dictionary, pieces: Array, rooms: int, player_at: Vector3, player_radius: float, supporter: Dictionary = {}, surface: Dictionary = {}) -> String:
	var kind := String(item.get("kind",""))
	var room := int(item.get("room",-1))
	var spec: Dictionary = DATA.data.furnitureCatalog.get(kind,{})
	var at := Vector2(float(item.get("x",INF)),float(item.get("z",INF)))
	var turns := int(item.get("rotation",-1))
	if spec.is_empty() or room<0 or room>=rooms or not at.is_finite() or turns<0 or turns>3:
		return "Choose a valid placement inside your home."
	var supported := not supporter.is_empty()
	var rect := footprint(item,supported)
	if not USABLE_FLOOR.encloses(rect):
		return "Leave more space by the walls."
	if supported:
		if not spec.get("surfacePlaceable",false) or supporter.has("supportId") or int(supporter.get("room",-1))!=room or surface.is_empty():
			return "Choose a surface in the same room for small decor."
		var allowed := Vector2(float(surface.width),float(surface.depth))
		var surface_bounds := Rect2(Vector2(float(surface.x),float(surface.z))-allowed*.5,allowed)
		if not surface_bounds.grow(.001).encloses(transform_to_surface(item,supporter,surface)) or (surface.get("clearance")!=null and height(kind)>float(surface.clearance)):
			return "That item does not fit on this surface."
	elif kind!="rug":
		if (room==0 and rect.intersects(ENTRY)) or (room>0 and rect.intersects(WEST_PASSAGE)) or (room<rooms-1 and rect.intersects(EAST_PASSAGE)):
			return "Keep the doorway clear."
		if _player_conflict(rect,room,player_at,player_radius):
			return "Step away from that spot before placing furniture."
	for other: Dictionary in pieces:
		if not other.has("x") or int(other.get("room",-1))!=room:
			continue
		if other.get("supportId","") != item.get("supportId","") or other.get("surfaceId","") != item.get("surfaceId",""):
			continue
		if not supported and (kind=="rug") != (other.get("kind","")=="rug"):
			continue # Rugs remain flat and can sit beneath furniture.
		if footprint(other,supported).intersects(rect):
			return "That spot already has furniture."
	return ""


static func base_height(item: Dictionary, by_id: Dictionary) -> float:
	if not item.has("supportId"):
		return .002 if item.get("kind","")=="rug" else 0.0
	var support: Dictionary = by_id.get(item.supportId,{})
	var surface := surface_for(String(support.get("kind","")),String(item.get("surfaceId","")))
	if surface.is_empty():
		return clampf(float(item.get("y",0)),0.0,2.5)
	return float(surface.y)

