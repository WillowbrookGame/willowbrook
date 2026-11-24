extends RefCounted

const FILE := "res://game/vehicles/side_driveways.json"
static var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FILE))

static func rect(side: int,row: float) -> Rect2:
	var width := float(layout.width)
	var center_x := side*float(layout.houseCenterX)+float(layout.sideOffsetX)
	return Rect2(center_x-width*.5,row+float(layout.rowStartZ),width,float(layout.rowEndZ)-float(layout.rowStartZ))

static func park(side: int,row: float) -> Vector2:
	var lane := rect(side,row)
	return Vector2(lane.get_center().x,row+float(layout.parkZ))

static func is_retired_own_pad(at: Vector3,side: int,row: float) -> bool:
	return absf(at.x-side*float(layout.oldCenterX))<=float(layout.oldHalfX) and absf(at.z-row-float(layout.oldZ))<=float(layout.oldHalfZ)

