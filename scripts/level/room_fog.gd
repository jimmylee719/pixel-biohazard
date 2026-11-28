## 房間的霧：主角不在的房間蒙一層霧（看得到裡面的地板和家具；敵人本來就只有主角視線看得到才顯示（Enemy._update_visibility），隔著牆靠聲波）。
## v0.10 以前是整個蓋黑；使用者覺得視野太窄，改成整張地圖都看得到。
class_name RoomFog
extends Node2D

var level: Level
var visible_rooms: Array[int] = []
var _cells_by_room := {}
var _last_pos := Vector2.ZERO


func setup(lv: Level) -> void:
	level = lv
	_cells_by_room.clear()
	for cell in level.room_of:
		var r: int = level.room_of[cell]
		if not _cells_by_room.has(r):
			_cells_by_room[r] = []
		_cells_by_room[r].append(cell)


## 房間有幾格（鏡頭依房間大小推近用）
func room_size(room: int) -> int:
	return _cells_by_room.get(room, []).size()


## 另外看得到的格子（從門縫、窗戶看進去的那一間）
var peek_cells: Array[Vector2i] = []


func update(pos: Vector2) -> void:
	var was_out := not level._is_indoor_cell(level.cell_of(_last_pos))
	_last_pos = pos
	if was_out != (not level._is_indoor_cell(level.cell_of(pos))):
		queue_redraw()
	var rooms := level.visible_rooms(pos)
	if rooms.is_empty():
		return  # 站在牆裡（不應該發生）：維持原樣
	_sync_props.call_deferred()
	for c in peek_cells:
		if level.room_of.has(c) and not rooms.has(level.room_of[c]):
			rooms.append(level.room_of[c])
	rooms.sort()
	if rooms != visible_rooms:
		visible_rooms = rooms
		queue_redraw()


## 家具一律顯示（v0.10：別的房間也看得到，只是蒙一層霧）
func _sync_props() -> void:
	level.show_prop_rooms([])


func is_hidden_cell(cell: Vector2i) -> bool:
	return level.room_of.has(cell) and not visible_rooms.has(level.room_of[cell])


## 霧的顏色：主角不在的房間蒙上去（看得到裡面的家具和地板，只是比較暗、偏藍）
const HAZE := Color(0.09, 0.12, 0.17, 0.36)


func _draw() -> void:
	if visible_rooms.is_empty():
		return
	var t := float(Level.TILE)
	for r in _cells_by_room:
		if visible_rooms.has(r):
			continue
		for cell in _cells_by_room[r]:
			draw_rect(Rect2(Vector2(cell) * t, Vector2(t, t)), HAZE)
