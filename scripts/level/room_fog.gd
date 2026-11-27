## 房間的黑幕：主角不在的房間整個蓋黑（進去之前看不到裡面，進去之後看不到外面）。
## 牆壁留著（看得出建築的形狀），只蓋地板、家具和裡面的東西。
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


## 沒看到的房間：裡面的家具整個藏起來（高的地標才不會從黑幕上面露出來）。黑幕關掉（地圖預覽）= 全部顯示。
func _sync_props() -> void:
	level.show_prop_rooms(visible_rooms if is_visible_in_tree() else [])


func is_hidden_cell(cell: Vector2i) -> bool:
	return level.room_of.has(cell) and not visible_rooms.has(level.room_of[cell])


func _draw() -> void:
	if visible_rooms.is_empty():
		return
	var t := float(Level.TILE)
	# 主角在戶外：沒進去的建築畫成屋頂（從外面看到的是屋頂，不是一塊黑）
	var outside := not level._is_indoor_cell(level.cell_of(_last_pos))
	var roof := Art.tex("tiles/roof_metal")
	var snowy := Art.tex("tiles/roof_snow")
	for r in _cells_by_room:
		if visible_rooms.has(r):
			continue
		for cell in _cells_by_room[r]:
			# 牆頂比地板高、蓋住牆後面一點點地板：那一段不要蓋黑，牆才看得到
			var h := t - Level.WALL_RAISE if level.char_at(cell + Vector2i.DOWN) == "#" else t
			var rect := Rect2(Vector2(cell) * t, Vector2(t, h))
			if outside and roof and level._is_indoor_cell(cell):
				var src := Rect2(Vector2(posmod(cell.x, 4), posmod(cell.y, 4)) * t, Vector2(t, h))
				var snow_patch := level.set_at(level.cell_of(_last_pos)) == "yard" and absi(hash(cell / 3)) % 3 != 0
				draw_texture_rect_region(snowy if snow_patch and snowy else roof, rect, src, Color(0.75, 0.78, 0.85) if snow_patch else Color(0.9, 0.9, 0.95))
			else:
				draw_rect(rect, Color(0.0, 0.0, 0.01))
