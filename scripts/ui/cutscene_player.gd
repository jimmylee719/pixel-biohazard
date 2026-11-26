## 過場（用遊戲本身的畫面演出，不另外跳動畫）：
## 上下黑邊滑進來、鏡頭移到指定的地方、下面的黑邊顯示對白（打字機效果）。
## 播放時遊戲暫停（敵人定格），這個節點自己在暫停中照常運作（PROCESS_MODE_ALWAYS）。
## 互動鍵／攻擊鍵／點一下畫面 = 下一句；暫停鍵 = 跳過整段。
## 內容（步驟）在 scripts/world/cutscenes.gd；由 main.play_cutscene() 依序執行。
class_name CutscenePlayer
extends Control

signal advanced

## 寬銀幕（約 2.39:1）的上黑邊
const BAR := 32.0
## 下面的黑邊比較高：名字＋兩行對白
const BAR_LOW := 44.0
const W := 480.0
const H := 270.0
## 每秒打幾個字
const TYPE_SPEED := 40.0

var active := false
var skipping := false

var _top: ColorRect
var _bottom: ColorRect
var _speaker: Label
var _text: Label
var _caption: Label
var _hint: Label
## 說話的人的頭像（衛星電話的視訊畫面風格：小框＋掃描線）
var _portrait: TextureRect
var _portrait_frame: ColorRect
## 電影式的元素：整個畫面的黑幕（淡入淡出、硬切）、片名卡、人物名牌、片頭字幕
var _black: ColorRect
var _card_title: Label
var _card_sub: Label
var _name_box: Control
var _name_main: Label
var _name_role: Label
var _name_line: ColorRect
var _credit: Label
var _flash: ColorRect
var _typing := 0.0
var _full := ""
var _waiting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_top = _bar(Vector2(0, -BAR))
	_bottom = _bar(Vector2(0, H))
	_bottom.size.y = BAR_LOW
	_speaker = _label(12, Color(1.0, 0.8, 0.4))
	_speaker.position = Vector2(16, H - BAR_LOW + 1)
	_text = _label(12, Color(0.9, 0.92, 0.95))
	_text.position = Vector2(16, H - BAR_LOW + 14)
	_text.size = Vector2(W - 32, 28)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_portrait_frame = ColorRect.new()
	_portrait_frame.color = Color(0.12, 0.2, 0.22)
	_portrait_frame.size = Vector2(40, 40)
	_portrait_frame.position = Vector2(8, H - BAR_LOW + 2)
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.visible = false
	add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size = Vector2(38, 38)
	_portrait.position = Vector2(1, 1)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)
	_caption = _label(12, Color(0.85, 0.88, 0.92))
	_caption.position = Vector2(0, 10)
	_caption.size = Vector2(W, 14)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.size = Vector2(W, H)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	move_child(_black, 0)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = Vector2(W, H)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_card_title = _label(24, Color(0.88, 0.9, 0.92))
	_card_title.size = Vector2(W, 30)
	_card_title.position = Vector2(0, H * 0.5 - 26)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_sub = _label(12, Color(0.8, 0.2, 0.15))
	_card_sub.size = Vector2(W, 14)
	_card_sub.position = Vector2(0, H * 0.5 + 8)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 人物名牌：左邊，一條紅線＋名字（大）＋身分（小），從左邊滑進來
	_name_box = Control.new()
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_box.position = Vector2(-220, BAR + 10)
	_name_box.size = Vector2(220, 40)
	add_child(_name_box)
	_name_line = ColorRect.new()
	_name_line.color = Color(0.8, 0.15, 0.12)
	_name_line.size = Vector2(2, 34)
	_name_line.position = Vector2(14, 2)
	_name_box.add_child(_name_line)
	_name_main = Label.new()
	_name_main.add_theme_font_size_override("font_size", 24)
	_name_main.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97))
	_name_main.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_main.add_theme_constant_override("outline_size", 3)
	_name_main.position = Vector2(22, -4)
	_name_box.add_child(_name_main)
	_name_role = Label.new()
	_name_role.add_theme_font_size_override("font_size", 12)
	_name_role.add_theme_color_override("font_color", Color(0.75, 0.78, 0.8))
	_name_role.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_role.add_theme_constant_override("outline_size", 3)
	_name_role.position = Vector2(22, 24)
	_name_box.add_child(_name_role)
	_credit = _label(12, Color(0.78, 0.8, 0.82))
	_credit.size = Vector2(W - 24, 14)
	_credit.position = Vector2(12, BAR + 6)
	_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credit.add_theme_color_override("font_outline_color", Color.BLACK)
	_credit.add_theme_constant_override("outline_size", 3)
	_hint = _label(12, Color(0.6, 0.62, 0.66))
	_hint.position = Vector2(W - 120, H - BAR_LOW + 1)
	_hint.size = Vector2(112, 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _bar(pos: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0)
	r.position = pos
	r.size = Vector2(W, BAR)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func open() -> void:
	active = true
	skipping = false
	visible = true
	_speaker.text = ""
	_text.text = ""
	_caption.text = ""
	_hint.text = tr("[%s] skip") % tr("Esc")
	var t := create_tween().set_parallel()
	t.tween_property(_top, "position:y", 0.0, 0.4)
	t.tween_property(_bottom, "position:y", H - BAR_LOW, 0.4)
	await t.finished


func close() -> void:
	_portrait_frame.visible = false
	_card_title.text = ""
	_card_sub.text = ""
	_credit.text = ""
	_name_box.position.x = -220
	if _black.color.a > 0.0:
		var tb := create_tween()
		tb.tween_property(_black, "color:a", 0.0, 0.4)
	_speaker.text = ""
	_text.text = ""
	_caption.text = ""
	_hint.text = ""
	var t := create_tween().set_parallel()
	t.tween_property(_top, "position:y", -BAR, 0.35)
	t.tween_property(_bottom, "position:y", H, 0.35)
	await t.finished
	visible = false
	active = false


## 一句對白：打字機效果打完後等玩家按鍵（或 auto 秒後自動下一句）
func say(speaker: String, text: String, auto := 0.0, portrait: Texture2D = null) -> void:
	_portrait.texture = portrait
	_portrait_frame.visible = portrait != null
	_portrait_frame.position.y = _bottom.position.y + 2
	var left := 54.0 if portrait else 16.0
	_speaker.position.x = left
	_text.position.x = left
	_text.size.x = W - left - 16
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color",
		Color(0.55, 0.95, 0.7) if speaker.begins_with("[") else Color(1.0, 0.8, 0.4))
	_full = text
	_typing = 0.0
	_text.text = ""
	if skipping:
		return
	_waiting = true
	if auto > 0.0:
		get_tree().create_timer(auto, true).timeout.connect(func():
			if _waiting and _full == text:
				_waiting = false
				advanced.emit())
	await advanced


## 畫面上方的字幕（地點、時間），顯示 time 秒
func caption(text: String, time: float) -> void:
	_caption.text = text
	_caption.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_caption, "modulate:a", 1.0, 0.5)
	await t.finished
	await wait(time)
	var t2 := create_tween()
	t2.tween_property(_caption, "modulate:a", 0.0, 0.5)
	await t2.finished


## 整個畫面淡到黑（time = 0：硬切）
func fade_out(time: float) -> void:
	if skipping or time <= 0.0:
		_black.color.a = 1.0
		return
	var t := create_tween()
	t.tween_property(_black, "color:a", 1.0, time)
	await t.finished


## 從黑畫面淡回來
func fade_in(time: float) -> void:
	if skipping or time <= 0.0:
		_black.color.a = 0.0
		return
	var t := create_tween()
	t.tween_property(_black, "color:a", 0.0, time)
	await t.finished


## 片名卡：黑畫面中間的大字（片名、章節），停 time 秒
func title_card(text: String, sub: String, time: float) -> void:
	_black.color.a = 1.0
	_card_title.text = text
	_card_sub.text = sub
	_card_title.modulate.a = 0.0
	_card_sub.modulate.a = 0.0
	if skipping:
		_card_title.text = ""
		_card_sub.text = ""
		return
	var t := create_tween()
	t.tween_property(_card_title, "modulate:a", 1.0, 1.0)
	t.tween_property(_card_sub, "modulate:a", 1.0, 0.6)
	await t.finished
	await wait(time)
	var t2 := create_tween().set_parallel()
	t2.tween_property(_card_title, "modulate:a", 0.0, 0.8)
	t2.tween_property(_card_sub, "modulate:a", 0.0, 0.8)
	await t2.finished
	_card_title.text = ""
	_card_sub.text = ""


## 人物名牌（第一次登場）：從左邊滑進來，停 time 秒後滑出去。不擋住接下來的步驟
func name_card(name_text: String, role: String, time := 3.0) -> void:
	_name_main.text = name_text
	_name_role.text = role
	if skipping:
		return
	var t := create_tween()
	t.tween_property(_name_box, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(time)
	t.tween_property(_name_box, "position:x", -220.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## 片頭字幕：右上角的小字，淡入淡出（不擋住接下來的步驟）
func credit(text: String, time := 2.5) -> void:
	_credit.text = text
	_credit.modulate.a = 0.0
	if skipping:
		return
	var t := create_tween()
	t.tween_property(_credit, "modulate:a", 1.0, 0.6)
	t.tween_interval(time)
	t.tween_property(_credit, "modulate:a", 0.0, 0.6)


## 白光一閃（槍響、爆炸、訊號）
func flash(strength := 0.8) -> void:
	_flash.color.a = strength
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, 0.35)


func wait(time: float) -> void:
	if skipping:
		return
	await get_tree().create_timer(time, true).timeout


func _process(delta: float) -> void:
	if not active:
		return
	if _text.text.length() < _full.length():
		_typing += delta * TYPE_SPEED
		_text.text = _full.substr(0, int(_typing))
	if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_cancel"):
		skip()
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("fire") \
			or Input.is_action_just_pressed("ui_accept"):
		next()


func _input(event: InputEvent) -> void:
	if active and event is InputEventScreenTouch and event.pressed:
		next()


## 下一句（還在打字 = 先把這句打完）
func next() -> void:
	if not _waiting:
		return
	if _text.text.length() < _full.length():
		_text.text = _full
		_typing = _full.length()
		return
	_waiting = false
	advanced.emit()


func skip() -> void:
	skipping = true
	if _waiting:
		_waiting = false
		advanced.emit()
