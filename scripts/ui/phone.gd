## 主角的智慧型手機：所有功能都在這裡（狀態、物品、任務、訊息、地圖、操作說明），
## 遊戲畫面上就不用一直擺文字。打開時遊戲暫停（由 main 控制）。
## 物品、任務兩個 App 沿用 main 原本的面板（InventoryPanel、MissionPanel），只是擺進手機螢幕裡；
## 其他 App 的內容由 main 用 set_text() 填進來，地圖由這裡自己畫。
class_name Phone
extends Control

signal app_pressed(app: String)
signal close_pressed

const APPS := ["status", "items", "missions", "messages", "map", "controls"]
const APP_LABELS := {"status": "STAT", "items": "ITEM", "missions": "OPS", "messages": "MSG", "map": "MAP",
	"controls": "KEYS"}
const APP_TITLES := {"status": "Status", "items": "Items", "missions": "Operations", "messages": "Messages",
	"map": "Map", "controls": "Controls"}

## 手機外框與螢幕（480x270 的畫面座標）
const FRAME := Rect2(136, 4, 208, 262)
const SCREEN := Rect2(144, 14, 192, 242)
## App 內容的範圍（App 列、標題下面）
const CONTENT := Rect2(148, 58, 184, 194)

var app := "items"
var level: Level
var player_pos := Vector2.ZERO
var portrait: Texture2D

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
		b.size = Vector2(31, 16)
		b.pressed.connect(func(): app_pressed.emit(id))
		add_child(b)
		_buttons[id] = b
		x += 31.5
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
	_text.visible = id in ["status", "messages", "controls"]
	if id == "status":
		_text.position = CONTENT.position + Vector2(0, 40)
		_text.size = CONTENT.size - Vector2(0, 40)
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
		"status":
			if portrait:
				draw_texture_rect(portrait, Rect2(CONTENT.position, Vector2(36, 36)), false)


## 目前區域的地圖：牆、地板、門、安全屋（綠）、主角（閃爍的點）
func _draw_map() -> void:
	if level == null:
		return
	var w := 0
	for row in level._map:
		w = maxi(w, String(row).length())
	var h: int = level._map.size()
	var s := floorf(minf(CONTENT.size.x / w, (CONTENT.size.y - 16) / h))
	s = maxf(s, 1.0)
	var origin := CONTENT.position + Vector2((CONTENT.size.x - w * s) * 0.5, 0)
	for y in h:
		var row: String = level._map[y]
		for x in row.length():
			var c := Vector2i(x, y)
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
			elif level.is_safe_cell(c):
				col = Color(0.2, 0.42, 0.3)
			else:
				col = Color(0.1, 0.15, 0.17)
			draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s, s)), col)
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	var p := origin + player_pos / Level.TILE * s
	draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1, 0.3, 0.25) if blink else Color(1, 0.9, 0.5))
	draw_string(get_theme_default_font(), Vector2(CONTENT.position.x, CONTENT.end.y - 2),
		tr(level.region_title(level.region_at(player_pos))), HORIZONTAL_ALIGNMENT_LEFT, CONTENT.size.x, 12,
		Color(0.7, 0.85, 0.8))


func _process(_delta: float) -> void:
	if visible and app == "map":
		queue_redraw()
