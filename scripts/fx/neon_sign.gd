## 牆上的霓虹燈（80 年代改建時留下來的招牌）。區域資料 neon：{"x,y": {kind, text, color}}，x,y 是一格牆（下面是地板）。
##   kind = "sign"（文字招牌，預設）、"arrow"（箭頭，text = "left"/"right"）、"arcade"（大型電玩機台，螢幕會變色）、
##          "holo"（守門派的全息投影，青色掃描線，偏賽博龐克）
##   color = 十六進位色碼（例如 "ff3df0"）
## 畫在 Structure 圖層（不受黑暗影響，永遠是亮的），另外在牆前的地板放一盞同色的燈。
## 招牌文字是遊戲世界裡的東西，維持英文原文（不翻譯），像真的霓虹燈一樣。
class_name NeonSign
extends Node2D

var kind := "sign"
var text := ""
var color := Color(1.0, 0.24, 0.94)
var flicker := true

var _on := true
var _timer := 0.0
var _t := 0.0
var _light: PointLight2D
var _rnd := RandomNumberGenerator.new()
static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Cubic_11.ttf")
	return _font


static func create(level: Level, cell: Vector2i, info: Dictionary) -> NeonSign:
	var s := NeonSign.new()
	s.kind = info.get("kind", "sign")
	s.text = info.get("text", "")
	s.color = Color.html(info.get("color", "ff3df0"))
	s.flicker = info.get("flicker", true)
	s.position = (Vector2(cell) + Vector2(0.5, 0.5)) * Level.TILE
	s._rnd.seed = hash(cell)
	# 地上的光暈（在主畫面，跟黑暗一起算）
	var light := PointLight2D.new()
	light.texture = LightTextures.make_radial()
	light.texture_scale = 44.0 / (LightTextures.SIZE * 0.5)
	light.color = s.color
	light.energy = 0.55
	light.position = s.position + Vector2(0, Level.TILE * 1.2)
	level.add_child(light)
	s._light = light
	return s


func _process(delta: float) -> void:
	_t += delta
	_timer -= delta
	if _timer <= 0.0:
		# 霓虹燈偶爾閃一下（壞掉的燈管）
		if flicker and _on and _rnd.randf() < 0.18:
			_on = false
			_timer = _rnd.randf_range(0.04, 0.16)
		else:
			_on = true
			_timer = _rnd.randf_range(0.6, 3.5)
		if _light:
			_light.energy = 0.55 if _on else 0.15
		queue_redraw()
	if kind == "arcade" or kind == "holo":
		queue_redraw()


func _draw() -> void:
	var c := color if _on else color.darkened(0.7)
	match kind:
		"arcade":
			_draw_arcade()
		"arrow":
			_draw_arrow(c)
		"holo":
			_draw_holo(c)
		_:
			_draw_text(c)


func _draw_text(c: Color) -> void:
	var font := NeonSign.font()
	var size := 12
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w * 0.5, 4).round()
	# 燈管的外框（暗色底板）
	draw_rect(Rect2(at + Vector2(-3, -11), Vector2(w + 6, 14)), Color(0.04, 0.02, 0.08, 0.85))
	if _on:
		var glow := Color(c, 0.22)
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(font, at + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, glow)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	if _on:
		# 燈管中心比較白
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c.lightened(0.6), 0.35))


func _draw_arrow(c: Color) -> void:
	var dir := -1.0 if text == "left" else 1.0
	draw_rect(Rect2(-7, -6, 14, 12), Color(0.04, 0.02, 0.08, 0.85))
	var pts := PackedVector2Array([Vector2(-5 * dir, -1), Vector2(1 * dir, -1), Vector2(1 * dir, -4),
		Vector2(6 * dir, 0), Vector2(1 * dir, 4), Vector2(1 * dir, 1), Vector2(-5 * dir, 1)])
	pts.append(pts[0])
	draw_polyline(pts, c, 1.0)
	if _on:
		draw_polyline(pts, Color(c, 0.25), 3.0)


func _draw_arcade() -> void:
	# 大型電玩機台：靠牆站著，螢幕顏色會一直換（像在跑示範畫面）
	var body := Rect2(-6, -6, 12, 16)
	draw_rect(body, Color(0.08, 0.05, 0.16))
	draw_rect(Rect2(-6, -6, 12, 2), color)
	var hue := fmod(_t * 0.15, 1.0)
	var screen := Color.from_hsv(hue, 0.7, 0.95)
	draw_rect(Rect2(-4, -3, 8, 6), screen.darkened(0.3))
	var bar := int(_t * 8.0) % 6
	draw_rect(Rect2(-4, -3 + bar, 8, 1), screen)
	draw_rect(Rect2(-4, 5, 8, 2), Color(0.2, 0.15, 0.3))
	draw_rect(Rect2(-2, 5, 1, 1), Color(1.0, 0.3, 0.3))
	draw_rect(Rect2(1, 5, 1, 1), Color(0.3, 0.9, 1.0))
	if _light:
		_light.color = screen


func _draw_holo(c: Color) -> void:
	# 全息投影：半透明、有掃描線、偶爾整排錯位
	var font := NeonSign.font()
	var size := 12
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var jitter := 1.0 if fmod(_t, 2.7) < 0.08 else 0.0
	var at := Vector2(-w * 0.5 + jitter, 4).round()
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c, 0.75 if _on else 0.3))
	var scan := int(_t * 12.0) % 14
	draw_rect(Rect2(at.x - 2, at.y - 11 + scan, w + 4, 1), Color(c, 0.35))
	draw_rect(Rect2(at.x - 2, at.y + 3, w + 4, 1), Color(c, 0.5))
