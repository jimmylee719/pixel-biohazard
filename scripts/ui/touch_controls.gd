## 觸控操作（iOS、手機網頁）：左半邊是浮動虛擬搖桿，右邊是動作按鈕，上方是選單按鈕。
## 全部都是「按下對應的 InputMap 動作」，所以遊戲邏輯完全不用分觸控或鍵盤。
## 面板（物品欄、無線電、發訊介面）也一樣能用：搖桿上下選、USE 確認、ITEMS 關閉、TARGET 切換備忘錄。
## 手機／平板自動顯示；桌面測試可以把專案設定 game/force_touch_ui 設成 true（用滑鼠模擬觸控）。
class_name TouchControls
extends CanvasLayer

const BUTTON_COLOR := Color(1, 1, 1, 0.22)
const LABEL_COLOR := Color(1, 1, 1, 0.75)

## [動作, 標籤, 位置, 半徑]（座標以 480x270 為準）
const BUTTONS := [
	["fire", "FIRE", Vector2(448, 214), 22.0],
	["aim", "AIM", Vector2(402, 238), 16.0],
	["interact", "USE", Vector2(404, 194), 16.0],
	["item", "ITEM", Vector2(450, 166), 14.0],
	["reload", "RLD", Vector2(360, 240), 12.0],
	["run", "RUN", Vector2(362, 206), 12.0],
	["weapon", "WPN", Vector2(408, 156), 11.0],
	["dodge", "DODGE", Vector2(452, 126), 12.0],
	["sneak", "SNEAK", Vector2(122, 248), 12.0],
	["pause", "II", Vector2(16, 40), 10.0],
	["map", "MAP", Vector2(42, 40), 10.0],
	["inventory", "BAG", Vector2(70, 40), 11.0],
	["phone", "OPS", Vector2(98, 40), 10.0],
]

var joystick: TouchStick
var buttons: Array[TouchScreenButton] = []


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	joystick = TouchStick.new()
	add_child(joystick)
	for b in BUTTONS:
		var button := TouchScreenButton.new()
		button.action = b[0]
		button.texture_normal = _circle_texture(b[3], BUTTON_COLOR)
		button.texture_pressed = _circle_texture(b[3], Color(1, 1, 1, 0.45))
		var shape := CircleShape2D.new()
		shape.radius = b[3] + 3.0  # 手指比按鈕粗：判定範圍大一點
		button.shape = shape
		button.shape_centered = true
		button.position = b[2] - Vector2(b[3], b[3])
		var label := Label.new()
		label.text = b[1]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", LABEL_COLOR)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(b[3] * 2, b[3] * 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		add_child(button)
		buttons.append(button)
	set_enabled(should_show())
	apply_layout()
	WorldState.options_changed.connect(apply_layout)


## 選項：按鈕透明度、左右對調（左手模式：搖桿在右、按鈕在左）。上方的選單按鈕不換邊。
func apply_layout() -> void:
	var lefty: bool = WorldState.option("left_handed")
	var alpha := clampf(float(WorldState.option("touch_opacity")) / BUTTON_COLOR.a, 0.3, 3.5)
	for i in buttons.size():
		var b: Array = BUTTONS[i]
		var pos: Vector2 = b[2]
		if lefty and pos.y > 60.0:
			pos.x = 480.0 - pos.x
		buttons[i].position = pos - Vector2(b[3], b[3])
		buttons[i].modulate.a = alpha
	joystick.zone = Rect2(480.0 - TouchStick.ZONE.end.x, TouchStick.ZONE.position.y, TouchStick.ZONE.size.x, TouchStick.ZONE.size.y) \
		if lefty else TouchStick.ZONE


## 手機、平板（含網頁版在手機上開）才自動顯示。
## 注意：開了「滑鼠模擬觸控」之後，桌面版的 DisplayServer.is_touchscreen_available() 也會是 true，所以不能用它判斷。
static func should_show() -> bool:
	if ProjectSettings.get_setting("game/force_touch_ui", false):
		return true
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0", true))
	return false


func set_enabled(on: bool) -> void:
	visible = on
	joystick.active = on
	if not on:
		joystick.release()


func button_for(action: String) -> TouchScreenButton:
	for b in buttons:
		if b.action == action:
			return b
	return null


static func _circle_texture(radius: float, color: Color) -> ImageTexture:
	var size := int(radius * 2.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(radius, radius)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= radius:
				var ring := d > radius - 1.5
				img.set_pixel(x, y, Color(color, color.a * (2.5 if ring else 1.0)))
	return ImageTexture.create_from_image(img)
