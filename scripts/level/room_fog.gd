## 房間的黑幕：主角不在的房間整個蓋黑（進去之前看不到裡面，進去之後看不到外面）。
## 牆壁留著（看得出建築的形狀），只蓋地板、家具和裡面的東西。
class_name RoomFog
extends Node2D

var level: Level
var visible_rooms: Array[int] = []
var _cells_by_room := {}


func setup(lv: Level) -> void:
	level = lv
	_cells_by_room.clear()
	for cell in level.room_of:
		var r: int = level.room_of[cell]
		if not _cells_by_room.has(r):
			_cells_by_room[r] = []
		_cells_by_room[r].append(cell)


func update(pos: Vector2) -> void:
	var rooms := level.visible_rooms(pos)
	if rooms.is_empty():
		return  # 站在牆裡（不應該發生）：維持原樣
	rooms.sort()
	if rooms != visible_rooms:
		visible_rooms = rooms
		queue_redraw()


func is_hidden_cell(cell: Vector2i) -> bool:
	return level.room_of.has(cell) and not visible_rooms.has(level.room_of[cell])


func _draw() -> void:
	if visible_rooms.is_empty():
		return
	var t := float(Level.TILE)
	for r in _cells_by_room:
		if visible_rooms.has(r):
			continue
		for cell in _cells_by_room[r]:
			draw_rect(Rect2(Vector2(cell) * t, Vector2(t, t)), Color(0.0, 0.0, 0.01))
