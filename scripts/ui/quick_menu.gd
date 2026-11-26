## 快捷選單（MGS1 式，少按鍵）：
##   道具鍵／武器鍵「按一下」= 直接用選好的道具／換下一把武器
##   「按住」= 跳出一排圖示（時間變慢），用左右（或上下）選，放開 = 選定
## 道具包含：光源（手電筒 → 打火機 → 關）、投擲物、急救包、抗菌藥劑、暖暖包、可以組合的材料。
## 由 main 控制開關與套用；這裡只負責畫圖示列。
class_name QuickMenu
extends Control

const SLOT := 26.0
const Y := 222.0

var kind := ""
var entries: Array[Dictionary] = []
var index := 0
var _name: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 12)
	_name.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_name.add_theme_constant_override("outline_size", 4)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.position = Vector2(0, Y - 18)
	_name.size = Vector2(480, 14)
	add_child(_name)


## entries：[{id, name, icon, count}]
func open(menu_kind: String, list: Array[Dictionary], selected: String) -> void:
	kind = menu_kind
	entries = list
	index = 0
	for i in entries.size():
		if entries[i].id == selected:
			index = i
	visible = true
	_refresh()


func move(step: int) -> void:
	if entries.is_empty():
		return
	index = (index + step + entries.size()) % entries.size()
	Sfx.play("ui_move")
	_refresh()


func selected_id() -> String:
	return entries[index].id if index < entries.size() else ""


func close() -> void:
	visible = false
	kind = ""


func _refresh() -> void:
	_name.text = entries[index].name if not entries.is_empty() else ""
	queue_redraw()


func _draw() -> void:
	if entries.is_empty():
		return
	var total := SLOT * entries.size()
	var vw := get_viewport_rect().size.x
	_name.size.x = vw
	var x0 := (vw - total) * 0.5
	draw_rect(Rect2(x0 - 4, Y - 3, total + 8, SLOT + 6), Color(0, 0.02, 0.03, 0.8))
	var font := get_theme_default_font()
	for i in entries.size():
		var e: Dictionary = entries[i]
		var r := Rect2(x0 + i * SLOT + 1, Y, SLOT - 2, SLOT - 2)
		draw_rect(r, Color(0.08, 0.14, 0.15) if i != index else Color(0.22, 0.2, 0.1))
		if i == index:
			draw_rect(r, Color(1, 0.85, 0.4), false, 1.0)
		var tex: Texture2D = e.get("icon")
		if tex:
			var k := minf(1.0, minf((SLOT - 6) / tex.get_width(), (SLOT - 6) / tex.get_height()))
			var sz := (tex.get_size() * k).floor()
			draw_texture_rect(tex, Rect2((r.get_center() - sz * 0.5).floor(), sz), false)
		if e.get("count", 0) > 1:
			draw_string(font, r.position + Vector2(r.size.x - 12, r.size.y - 1), str(e.count), HORIZONTAL_ALIGNMENT_RIGHT,
				12, 12, Color(0.95, 0.95, 0.95))
