## 主角的智慧型手機：所有功能都在這裡（狀態、物品、任務、訊息、地圖、操作說明），
## 遊戲畫面上就不用一直擺文字。打開時遊戲暫停（由 main 控制）。
## 物品、任務兩個 App 沿用 main 原本的面板（InventoryPanel、MissionPanel），只是擺進手機螢幕裡；
## 其他 App 的內容由 main 用 set_text() 填進來，地圖由這裡自己畫。
class_name Phone
extends Control

signal app_pressed(app: String)
signal close_pressed

const APPS := ["status", "missions", "messages", "codex", "map", "gear"]
const APP_LABELS := {"status": "STAT", "items": "ITEM", "missions": "OPS", "messages": "MSG", "codex": "FILE",
	"map": "MAP", "gear": "GEAR"}
const APP_TITLES := {"status": "Status", "items": "Items", "missions": "Operations", "messages": "Messages",
	"codex": "Field Files", "map": "Map", "gear": "Gear"}

## 手機外框與螢幕（480x270 的畫面座標）
const FRAME := Rect2(136, 4, 208, 262)
const SCREEN := Rect2(144, 14, 192, 242)
## App 內容的範圍（App 列、標題下面）
const CONTENT := Rect2(148, 58, 184, 194)

var app := "missions"
var level: Level
var player_pos := Vector2.ZERO
var portrait: Texture2D
## 物品 App：選到的物品的圖（放大兩倍畫在右上角）
var item_icon: Texture2D
## 圖鑑 App：這一筆的圖、標題（名稱、擊倒數）、還沒解鎖（畫黑色剪影）
var codex_icon: Texture2D
var codex_header: Array[String] = []
var codex_locked := false
## 裝備 App：紙娃娃（本體＋圖層，畫成兩倍大）、左上的欄位說明
var gear_doll: Array[Texture2D] = []
var gear_header: Array[String] = []
## 地圖 App（惡靈古堡式）：map = {rows, explored, known, player, objective, objective_doors, stars, title, info}
var map := {}

var _buttons := {}
var _title: Label
var _text: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var x := SCREEN.position.x + 2
	for id in APPS:
		var b := Button.new()
		b.text = APP_LABELS[id]
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.add_theme_font_size_override("font_size", 12)
		b.position = Vector2(x, SCREEN.position.y + 14)
		b.size = Vector2(27, 16)
		b.pressed.connect(func(): app_pressed.emit(id))
		add_child(b)
		_buttons[id] = b
		x += 27.0
	# 關閉（觸控用；鍵盤按物品鍵、取消鍵也可以）
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.flat = true
	close.add_theme_font_size_override("font_size", 12)
	close.position = Vector2(SCREEN.end.x - 18, SCREEN.position.y + 29)
	close.size = Vector2(16, 16)
	close.pressed.connect(func(): close_pressed.emit())
	add_child(close)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", Color(0.6, 0.95, 0.85))
	_title.position = Vector2(CONTENT.position.x, SCREEN.position.y + 31)
	_title.size = Vector2(CONTENT.size.x, 14)
	add_child(_title)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 12)
	_text.add_theme_color_override("font_color", Color(0.85, 0.92, 0.95))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.clip_text = true
	_text.position = CONTENT.position
	_text.size = CONTENT.size
	add_child(_text)


func set_app(id: String) -> void:
	app = id
	_title.text = tr(APP_TITLES[id])
	for b_id in _buttons:
		var b: Button = _buttons[b_id]
		b.add_theme_color_override("font_color", Color(1, 0.85, 0.4) if b_id == id else Color(0.55, 0.62, 0.66))
	_text.visible = id in ["status", "messages", "codex", "gear"]
	if id == "status":
		_text.position = CONTENT.position + Vector2(0, 40)
		_text.size = CONTENT.size - Vector2(0, 40)
	elif id == "codex" or id == "gear":
		_text.position = CONTENT.position + Vector2(0, 70)
		_text.size = CONTENT.size - Vector2(0, 70)
	else:
		_text.position = CONTENT.position
		_text.size = CONTENT.size
	queue_redraw()


## 狀態、訊息、操作說明 App 的內容
func set_text(text: String) -> void:
	_text.text = text


func get_text() -> String:
	return _text.text


func next_app(step: int) -> String:
	return APPS[(APPS.find(app) + step + APPS.size()) % APPS.size()]


func _draw() -> void:
	# 外框（機身）、螢幕
	draw_rect(FRAME, Color(0.07, 0.07, 0.09))
	draw_rect(FRAME.grow(-1), Color(0.16, 0.17, 0.2), false, 1.0)
	draw_rect(SCREEN, Color(0.03, 0.07, 0.08))
	draw_rect(Rect2(FRAME.get_center().x - 14, FRAME.position.y + 3, 28, 3), Color(0.02, 0.02, 0.03))  # 聽筒
	# 狀態列：時間、訊號、電量（裝飾）
	var t := Time.get_ticks_msec() / 1000
	var clock := "%02d:%02d" % [2 + (t / 3600) % 24, (t / 60) % 60]
	draw_string(get_theme_default_font(), SCREEN.position + Vector2(4, 11), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.7, 0.8, 0.85))
	for i in 4:
		var h := 2 + i * 2
		draw_rect(Rect2(SCREEN.end.x - 40 + i * 4, SCREEN.position.y + 10 - h, 3, h),
			Color(0.7, 0.8, 0.85) if i < 1 else Color(0.25, 0.3, 0.33))  # 收訊很差
	draw_rect(Rect2(SCREEN.end.x - 20, SCREEN.position.y + 3, 14, 7), Color(0.7, 0.8, 0.85), false, 1.0)
	draw_rect(Rect2(SCREEN.end.x - 19, SCREEN.position.y + 4, 6, 5), Color(0.9, 0.6, 0.3))
	draw_line(Vector2(SCREEN.position.x, SCREEN.position.y + 30), Vector2(SCREEN.end.x, SCREEN.position.y + 30),
		Color(0.15, 0.25, 0.27))
	draw_line(Vector2(SCREEN.position.x, SCREEN.position.y + 44), Vector2(SCREEN.end.x, SCREEN.position.y + 44),
		Color(0.15, 0.25, 0.27))
	match app:
		"map":
			_draw_map()
		"items":
			if item_icon:
				var sz := item_icon.get_size() * 2.0
				var at := Vector2(CONTENT.end.x - sz.x - 2, CONTENT.position.y + 2)
				draw_rect(Rect2(at - Vector2(2, 2), sz + Vector2(4, 4)), Color(0.06, 0.12, 0.13))
				draw_texture_rect(item_icon, Rect2(at, sz), false)
		"codex":
			_draw_codex()
		"gear":
			_draw_gear()
		"status":
			if portrait:
				draw_texture_rect(portrait, Rect2(CONTENT.position, Vector2(36, 36)), false)


## 圖鑑：左上是名稱、擊倒數，右上是放大兩倍的圖（沒解鎖 = 黑色剪影）
func _draw_codex() -> void:
	var font := get_theme_default_font()
	var y := CONTENT.position.y + 12
	for i in codex_header.size():
		var col := Color(1, 0.85, 0.4) if i == 1 else Color(0.7, 0.85, 0.8)
		draw_string(font, Vector2(CONTENT.position.x, y), codex_header[i], HORIZONTAL_ALIGNMENT_LEFT, 110, 12, col)
		y += 15
	var box := Rect2(CONTENT.end.x - 68, CONTENT.position.y, 68, 66)
	draw_rect(box, Color(0.06, 0.12, 0.13))
	if codex_icon:
		var k := minf(2.0, minf(64.0 / codex_icon.get_width(), 64.0 / codex_icon.get_height()))
		var sz := (codex_icon.get_size() * k).floor()
		draw_texture_rect(codex_icon, Rect2(box.get_center() - sz * 0.5, sz), false,
			Color(0, 0, 0, 0.9) if codex_locked else Color.WHITE)
	else:
		draw_string(font, box.get_center() + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.5, 0.6, 0.6))


## 裝備：左上是三個欄位穿的東西＋套裝，右上是紙娃娃（兩倍大）
func _draw_gear() -> void:
	var font := get_theme_default_font()
	var y := CONTENT.position.y + 12
	for i in gear_header.size():
		draw_string(font, Vector2(CONTENT.position.x, y), gear_header[i], HORIZONTAL_ALIGNMENT_LEFT, 112, 12,
			Color(1, 0.85, 0.4) if i == gear_header.size() - 1 else Color(0.7, 0.85, 0.8))
		y += 15
	var box := Rect2(CONTENT.end.x - 68, CONTENT.position.y, 68, 66)
	draw_rect(box, Color(0.06, 0.12, 0.13))
	for tex in gear_doll:
		if tex:
			var sz := tex.get_size() * 2.0
			draw_texture_rect(tex, Rect2((box.get_center() - sz * 0.5 + Vector2(0, -2)).floor(), sz), false)


## 地圖（惡靈古堡式）：去過的地方亮、只有地圖還沒去過的地方暗藍、完全不知道的地方不畫。
## 主線方向：金色閃爍（目標在這張地圖 = 目標位置；不在 = 往那邊的門）。藍色星號 = 解鎖情報的隱藏要素。
func _draw_map() -> void:
	if map.is_empty():
		return
	var rows: Array = map.rows
	var w := 0
	for row in rows:
		w = maxi(w, String(row).length())
	var h: int = rows.size()
	var s := floorf(minf(CONTENT.size.x / w, (CONTENT.size.y - 30) / h))
	s = maxf(s, 1.0)
	var origin := CONTENT.position + Vector2(floorf((CONTENT.size.x - w * s) * 0.5), 0)
	var explored: PackedByteArray = map.explored
	var known: bool = map.known
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var seen := explored.size() > y * w + x and explored[y * w + x] > 0
			if not seen and not known:
				continue
			var ch := row[x]
			var col: Color
			if ch == "#":
				col = Color(0.32, 0.4, 0.42)
			elif ch == "C" or ch == "H":
				col = Color(0.16, 0.22, 0.24)
			elif ch == "D":
				col = Color(0.95, 0.7, 0.3)
			elif ch == "+":
				col = Color(0.8, 0.6, 0.3)
			elif ch == "=":
				col = Color(0.5, 0.75, 0.9)
			elif map.safe_cells.has(Vector2i(x, y)):
				col = Color(0.2, 0.42, 0.3)
			else:
				col = Color(0.12, 0.18, 0.2)
			if not seen:
				col = col.darkened(0.45).lerp(Color(0.1, 0.16, 0.3), 0.45)  # 還沒去過：暗藍
			draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s, s)), col)
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	# 藍色星號：解鎖的隱藏要素
	for c: Vector2i in map.stars:
		var p := origin + (Vector2(c) + Vector2(0.5, 0.5)) * s
		var col := Color(0.4, 0.7, 1.0)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), col, 1.0)
		draw_line(p + Vector2(0, -3), p + Vector2(0, 3), col, 1.0)
		draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), col, 1.0)
		draw_line(p + Vector2(-2, 2), p + Vector2(2, -2), col, 1.0)
	# 主線方向
	var gold := Color(1, 0.85, 0.3) if blink else Color(1, 0.6, 0.2)
	for c: Vector2i in map.objective_doors:
		var p := origin + (Vector2(c) + Vector2(0.5, 0.5)) * s
		draw_arc(p, 4.0, 0.0, TAU, 12, gold, 1.0)
	if map.objective != null:
		var p := origin + (Vector2(map.objective) + Vector2(0.5, 0.5)) * s
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), gold, false, 1.0)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), gold)
	if map.player != null:
		var pp := origin + Vector2(map.player) / Level.TILE * s
		draw_rect(Rect2(pp - Vector2(2, 2), Vector2(4, 4)), Color(1, 0.3, 0.25) if blink else Color(1, 0.9, 0.5))
	var font := get_theme_default_font()
	draw_string(font, Vector2(CONTENT.position.x, CONTENT.end.y - 15), map.title, HORIZONTAL_ALIGNMENT_LEFT,
		CONTENT.size.x, 12, Color(0.7, 0.85, 0.8))
	draw_string(font, Vector2(CONTENT.position.x, CONTENT.end.y - 2), map.info, HORIZONTAL_ALIGNMENT_LEFT,
		CONTENT.size.x, 12, Color(0.55, 0.65, 0.68))


func _process(_delta: float) -> void:
	if visible and app == "map":
		queue_redraw()
