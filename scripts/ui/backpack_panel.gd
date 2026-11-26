## 背包（惡靈古堡式的格子）：打開就看到身上所有道具的圖，可以自己搬位置。
## 兩種模式：
##   bag      平常按物品鍵打開：左邊背包格子＋隨身裝備（小刀／空手、打火機、手電筒），右邊是選到的道具的大圖和說明
##   storage  安全屋的儲物箱：左邊背包、右邊箱子，選一格按確認就搬到另一邊
## 操作：方向 = 移動游標；互動／確認 = 使用（儲物箱模式 = 搬到另一邊）；裝填鍵 = 拿起來／放下（搬位置、同種會疊在一起）；
##       物品鍵／取消 = 關閉。滑鼠、觸控：點一下 = 選，再點一次 = 使用；按住拖到別格 = 搬位置（拖到另一邊 = 存／取）。
## 打開時遊戲暫停（由 main 控制）。這裡只管畫面和游標，真正的「使用」交給 main（use_slot 訊號）。
class_name BackpackPanel
extends Control

signal use_slot(index: int)
signal use_kit(id: String)
signal closed

const COLS := 4
const CELL := Vector2(42, 34)
const BOX_COLS := 5
const BOX_ROWS := 4
const KIT := ["melee", "lighter", "flashlight"]
const BG := Color(0.02, 0.035, 0.045, 0.94)
const FRAME := Color(0.45, 0.55, 0.58)
const CELL_BG := Color(0.07, 0.11, 0.12)
const GOLD := Color(1.0, 0.85, 0.4)
const TEXT := Color(0.86, 0.92, 0.94)
const DIM := Color(0.55, 0.64, 0.67)

var main: Node
var mode := "bag"
## 游標在哪一區：bag（背包）、kit（隨身裝備）、box（儲物箱）
var zone := "bag"
var cursor := 0
## 拿在手上準備搬的那一格（-1 = 沒有）
var held := -1
var _font: Font
var _box_scroll := 0
var _press_zone := ""
var _press_index := -1
var _drag_pos := Vector2.ZERO
var _dragging := false
var _opened_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = load("res://assets/fonts/Cubic_11.ttf")


func open(panel_mode: String) -> void:
	mode = panel_mode
	zone = "bag"
	cursor = 0
	held = -1
	_box_scroll = 0
	_dragging = false
	_opened_frame = Engine.get_process_frames()
	visible = true
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	held = -1
	closed.emit()


# ── 版面 ──────────────────────────────────────────────

func _panel() -> Rect2:
	var view := get_viewport_rect().size
	var size := Vector2(436, 226)
	return Rect2(((view - size) * 0.5).floor(), size)


func _bag_origin() -> Vector2:
	return _panel().position + Vector2(12, 30)


func _bag_rows() -> int:
	return int(ceil(WorldState.inventory().size() / float(COLS)))


func _bag_cell(i: int) -> Rect2:
	return Rect2(_bag_origin() + Vector2(i % COLS, i / COLS) * (CELL + Vector2(2, 2)), CELL)


func _kit_cell(i: int) -> Rect2:
	var y := _bag_origin().y + _bag_rows() * (CELL.y + 2) + 16
	return Rect2(Vector2(_bag_origin().x + i * (CELL.x + 2), y), Vector2(CELL.x, 26))


func _box_origin() -> Vector2:
	return _panel().position + Vector2(12 + COLS * (CELL.x + 2) + 14, 30)


func _box_cell(i: int) -> Rect2:
	var s := Vector2(44, 34)
	return Rect2(_box_origin() + Vector2(i % BOX_COLS, i / BOX_COLS - _box_scroll) * (s + Vector2(2, 2)), s)


func _box_ids() -> Array:
	var ids := WorldState.storage().keys()
	ids.sort()
	return ids


## 游標現在指的物品 id（空格 = ""）
func selected_id() -> String:
	match zone:
		"bag":
			var slot: Dictionary = WorldState.inventory()[cursor]
			return slot.get("id", "")
		"kit":
			return kit_item(KIT[cursor])
		"box":
			var ids := _box_ids()
			return ids[cursor] if cursor < ids.size() else ""
	return ""


## 隨身裝備那一格現在是什麼
func kit_item(kit: String) -> String:
	if kit == "melee":
		return WorldState.melee()
	return kit


# ── 輸入 ──────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("ui_cancel") \
			or Input.is_action_just_pressed("pause"):
		if held >= 0:
			held = -1
			queue_redraw()
		else:
			close()
		return
	var step := Vector2i.ZERO
	if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"):
		step.x = 1
	elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"):
		step.x = -1
	elif Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
		step.y = 1
	elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
		step.y = -1
	if step != Vector2i.ZERO:
		move_cursor(step)
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		activate()
	elif Input.is_action_just_pressed("reload"):
		grab_or_drop()
	queue_redraw()


func move_cursor(step: Vector2i) -> void:
	Sfx.play("ui_move")
	var n := WorldState.inventory().size()
	match zone:
		"bag":
			var col := cursor % COLS
			var row := cursor / COLS
			if step.x != 0:
				if step.x > 0 and (col == COLS - 1 or cursor == n - 1) and mode == "storage" and not _box_ids().is_empty() and held < 0:
					zone = "box"
					cursor = clampi((row + _box_scroll) * BOX_COLS, 0, _box_ids().size() - 1)
				else:
					cursor = row * COLS + posmod(col + step.x, COLS)
					cursor = mini(cursor, n - 1)
			else:
				var r := row + step.y
				if r >= _bag_rows() and mode == "bag" and held < 0:
					zone = "kit"
					cursor = mini(col, KIT.size() - 1)
				else:
					cursor = mini(posmod(r, _bag_rows()) * COLS + col, n - 1)
		"kit":
			if step.x != 0:
				cursor = posmod(cursor + step.x, KIT.size())
			else:
				zone = "bag"
				cursor = mini((_bag_rows() - 1 if step.y < 0 else 0) * COLS + cursor, n - 1)
		"box":
			var ids := _box_ids()
			var col := cursor % BOX_COLS
			if step.x < 0 and col == 0:
				zone = "bag"
				cursor = mini((cursor / BOX_COLS - _box_scroll) * COLS + COLS - 1, n - 1)
				cursor = maxi(cursor, 0)
			else:
				cursor = clampi(cursor + step.x + step.y * BOX_COLS, 0, maxi(ids.size() - 1, 0))
			_scroll_to_cursor()


func _scroll_to_cursor() -> void:
	if zone != "box":
		return
	var row := cursor / BOX_COLS
	_box_scroll = clampi(_box_scroll, row - BOX_ROWS + 1, row)
	_box_scroll = maxi(_box_scroll, 0)


## 確認鍵：背包模式 = 使用；儲物箱模式 = 搬到另一邊。手上拿著東西時 = 放下
func activate() -> void:
	if held >= 0:
		grab_or_drop()
		return
	match zone:
		"bag":
			if mode == "storage":
				if WorldState.store_slot(cursor):
					Sfx.play("ui_confirm")
			else:
				use_slot.emit(cursor)
		"kit":
			use_kit.emit(KIT[cursor])
		"box":
			var ids := _box_ids()
			if cursor < ids.size():
				if WorldState.retrieve(ids[cursor]) == 0:
					Sfx.play("ui_cancel")
					if main:
						main.show_message(tr("No room."))
				else:
					Sfx.play("ui_confirm")
				cursor = clampi(cursor, 0, maxi(_box_ids().size() - 1, 0))
				if _box_ids().is_empty():
					zone = "bag"
					cursor = 0
	queue_redraw()


## 拿起來／放下：搬位置（兩格交換；同一種會疊在一起）
func grab_or_drop() -> void:
	if zone != "bag":
		return
	if held < 0:
		if not WorldState.inventory()[cursor].is_empty():
			held = cursor
			Sfx.play("ui_move")
	else:
		WorldState.move_slot(held, cursor)
		held = -1
		Sfx.play("ui_confirm")
	queue_redraw()


func _hit(pos: Vector2) -> Array:
	for i in WorldState.inventory().size():
		if _bag_cell(i).has_point(pos):
			return ["bag", i]
	if mode == "bag":
		for i in KIT.size():
			if _kit_cell(i).has_point(pos):
				return ["kit", i]
	else:
		var ids := _box_ids()
		for i in ids.size():
			var r := _box_cell(i)
			if r.has_point(pos) and i / BOX_COLS >= _box_scroll and i / BOX_COLS < _box_scroll + BOX_ROWS:
				return ["box", i]
		if Rect2(_box_origin(), Vector2(BOX_COLS * 46, BOX_ROWS * 36)).has_point(pos):
			return ["boxarea", -1]
	return ["", -1]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed and mode == "storage":
			_box_scroll = clampi(_box_scroll + 1, 0, maxi(int(ceil(_box_ids().size() / float(BOX_COLS))) - BOX_ROWS, 0))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_box_scroll = maxi(_box_scroll - 1, 0)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var hit := _hit(mb.position)
			if mb.pressed:
				if _close_rect().has_point(mb.position):
					close()
					return
				_press_zone = hit[0]
				_press_index = hit[1]
				_drag_pos = mb.position
				_dragging = false
				if hit[1] >= 0:
					var again: bool = zone == hit[0] and cursor == hit[1]
					zone = hit[0]
					cursor = hit[1]
					held = -1
					if again:
						_press_zone = "again:" + _press_zone
			else:
				_release(hit, mb.position)
		queue_redraw()
	elif event is InputEventMouseMotion and _press_index >= 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(_drag_pos) > 5.0 or _dragging:
			_dragging = true
			_drag_pos = mm.position
			queue_redraw()


func _release(hit: Array, _pos: Vector2) -> void:
	var from_zone := _press_zone.trim_prefix("again:")
	var from := _press_index
	var was_again := _press_zone.begins_with("again:")
	_press_index = -1
	_press_zone = ""
	if _dragging:
		_dragging = false
		if from_zone == "bag" and hit[0] == "bag" and hit[1] != from:
			WorldState.move_slot(from, hit[1])
			cursor = hit[1]
			Sfx.play("ui_confirm")
		elif from_zone == "bag" and (hit[0] == "box" or hit[0] == "boxarea"):
			if WorldState.store_slot(from):
				Sfx.play("ui_confirm")
		elif from_zone == "box" and hit[0] == "bag":
			var ids := _box_ids()
			if from < ids.size() and WorldState.retrieve(ids[from]) > 0:
				Sfx.play("ui_confirm")
				zone = "bag"
				cursor = hit[1]
		return
	# 點第二次 = 使用／搬到另一邊
	if was_again and hit[0] == from_zone and hit[1] == from:
		activate()


func _close_rect() -> Rect2:
	var p := _panel()
	return Rect2(p.end.x - 20, p.position.y + 4, 16, 16)


# ── 畫面 ──────────────────────────────────────────────

func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.55))
	var p := _panel()
	draw_rect(p, BG)
	draw_rect(p, FRAME, false, 1.0)
	draw_rect(Rect2(p.position, Vector2(8, 1)), TEXT)
	draw_rect(Rect2(p.position, Vector2(1, 8)), TEXT)
	_text(p.position + Vector2(12, 17), tr("BACKPACK") if mode == "bag" else tr("BACKPACK  >>  STORAGE BOX"), GOLD)
	var cr := _close_rect()
	draw_rect(cr, CELL_BG)
	_text(cr.position + Vector2(4, 12), "X", DIM)
	var inv := WorldState.inventory()
	for i in inv.size():
		var slot: Dictionary = inv[i]
		var r := _bag_cell(i)
		var on := zone == "bag" and cursor == i
		_cell(r, slot.get("id", ""), slot.get("count", 0), on, i == held or (_dragging and _press_zone.ends_with("bag") and _press_index == i))
		if not slot.is_empty() and slot.id == WorldState.equipped and Items.get_item(slot.id).kind == "weapon":
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(8, 9)), Color(0.75, 0.6, 0.2))
			_text(r.position + Vector2(3, 10), "E", Color(0.05, 0.05, 0.05))
	if mode == "bag":
		_draw_kit()
		_draw_detail(Rect2(_box_origin() + Vector2(0, 0), Vector2(p.end.x - _box_origin().x - 12, 170)))
	else:
		_draw_box()
		_draw_detail_line(Rect2(p.position + Vector2(12, p.size.y - 46), Vector2(p.size.x - 24, 26)))
	var hint := tr("[%s] use   [%s] move   [%s] close") if mode == "bag" else tr("[%s] transfer   [%s] move   [%s] close")
	if main:
		hint = hint % [main._key_name("interact"), main._key_name("reload"), main._key_name("inventory")]
	_text(Vector2(p.position.x + 12, p.end.y - 7), hint, DIM)
	# 拖曳中的圖示
	if _dragging and _press_index >= 0:
		var id := ""
		if _press_zone.ends_with("bag"):
			id = WorldState.inventory()[_press_index].get("id", "")
		elif _press_zone.ends_with("box") and _press_index < _box_ids().size():
			id = _box_ids()[_press_index]
		var tex := Art.tex("props/" + id) if id != "" else null
		if tex:
			draw_texture(tex, (_drag_pos - tex.get_size() * 0.5).floor(), Color(1, 1, 1, 0.85))


func _draw_kit() -> void:
	var y := _kit_cell(0).position.y
	_text(Vector2(_bag_origin().x, y - 4), tr("ALWAYS CARRIED"), DIM)
	for i in KIT.size():
		var id := kit_item(KIT[i])
		var r := _kit_cell(i)
		var on := zone == "kit" and cursor == i
		draw_rect(r, CELL_BG if not on else Color(0.2, 0.18, 0.09))
		draw_rect(r, GOLD if on else Color(0.2, 0.27, 0.29), false, 1.0)
		var tex := Art.tex("props/" + id)
		if tex:
			var k := minf(1.0, minf((r.size.x - 6) / tex.get_width(), (r.size.y - 4) / tex.get_height()))
			var sz := (tex.get_size() * k).floor()
			draw_texture_rect(tex, Rect2((r.get_center() - sz * 0.5).floor(), sz), false)
		var lit := false
		if main and main._player:
			lit = (KIT[i] == "lighter" and main._player.lighter_on) or (KIT[i] == "flashlight" and main._player.flashlight_on)
		if lit:
			draw_rect(Rect2(r.end - Vector2(6, 6), Vector2(4, 4)), Color(1.0, 0.8, 0.3))


func _draw_box() -> void:
	var ids := _box_ids()
	var o := _box_origin()
	_text(o + Vector2(0, -4), tr("IN THE BOX  (shared by all safe rooms)"), DIM)
	if ids.is_empty():
		_text(o + Vector2(6, 22), tr("Empty."), DIM)
	for i in ids.size():
		var row := i / BOX_COLS
		if row < _box_scroll or row >= _box_scroll + BOX_ROWS:
			continue
		_cell(_box_cell(i), ids[i], WorldState.storage()[ids[i]], zone == "box" and cursor == i,
			_dragging and _press_zone.ends_with("box") and _press_index == i)
	var rows := int(ceil(ids.size() / float(BOX_COLS)))
	if rows > BOX_ROWS:
		var bar := Rect2(o + Vector2(BOX_COLS * 46 + 1, 0), Vector2(2, BOX_ROWS * 36 - 2))
		draw_rect(bar, Color(0.12, 0.16, 0.18))
		draw_rect(Rect2(bar.position + Vector2(0, bar.size.y * _box_scroll / rows), Vector2(2, bar.size.y * BOX_ROWS / rows)), DIM)


func _cell(r: Rect2, id: String, count: int, selected: bool, lifted: bool) -> void:
	draw_rect(r, CELL_BG if not selected else Color(0.2, 0.18, 0.09))
	draw_rect(r, GOLD if selected else Color(0.2, 0.27, 0.29), false, 1.0)
	if id == "":
		return
	var tex := Art.tex("props/" + id)
	var tint := Color(1, 1, 1, 0.35) if lifted else Color.WHITE
	if tex:
		# 圖示盡量放大（整數倍，像素才不會糊）
		var k := maxf(1.0, floorf(minf((r.size.x - 6) / tex.get_width(), (r.size.y - 10) / tex.get_height())))
		k = minf(k, 2.0)
		var sz := tex.get_size() * k
		draw_texture_rect(tex, Rect2((r.get_center() - sz * 0.5 - Vector2(0, 2)).floor(), sz), false, tint)
	else:
		_text(r.position + Vector2(3, 14), Items.display_name(id).substr(0, 5), TEXT)
	if count > 1:
		var s := str(count)
		draw_string(_font, Vector2(r.end.x - 3 - _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, r.end.y - 2), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)


func _detail_text() -> Array:
	var id := selected_id()
	if id == "":
		return ["", ""]
	if id == "fists":
		return [tr("Bare hands"), tr("Knife sheathed. Jab, hook, kick: weak, but it knocks them back and down. Select to draw the knife.")]
	if id == "flashlight":
		return [tr("Flashlight"), tr("Bright and narrow. Everything in the beam can see where it comes from.")]
	return [Items.display_name(id), tr(Items.get_item(id).desc)]


func _draw_detail(r: Rect2) -> void:
	draw_rect(r, Color(0.04, 0.07, 0.08))
	draw_rect(r, Color(0.2, 0.27, 0.29), false, 1.0)
	var id := selected_id()
	if id == "":
		return
	var info := _detail_text()
	var tex := Art.tex("props/" + id)
	if tex:
		var k := floorf(minf(64.0 / tex.get_width(), 44.0 / tex.get_height()))
		k = clampf(k, 1.0, 3.0)
		var sz := tex.get_size() * k
		draw_texture_rect(tex, Rect2((Vector2(r.get_center().x, r.position.y + 30) - sz * 0.5).floor(), sz), false)
	_text(r.position + Vector2(6, 70), info[0], GOLD)
	var count := 0
	if zone == "bag":
		count = WorldState.inv_count(id)
	if count > 1:
		_text(Vector2(r.end.x - 34, r.position.y + 70), "x%d" % count, TEXT)
	draw_multiline_string(_font, r.position + Vector2(6, 86), info[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 12, 6, TEXT)


func _draw_detail_line(r: Rect2) -> void:
	var info := _detail_text()
	if info[0] == "":
		return
	_text(r.position + Vector2(0, 10), info[0], GOLD)
	draw_multiline_string(_font, r.position + Vector2(0, 23), info[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 12, 1, TEXT)


func _text(at: Vector2, s: String, c: Color) -> void:
	draw_string(_font, at.floor(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
