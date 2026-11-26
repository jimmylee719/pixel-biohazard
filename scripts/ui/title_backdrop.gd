## 標題畫面（潛龍諜影式的開場：電影感、安靜、一個大標題、「按任意鍵」）。全部用程式畫，像素對齊。
## 流程（phase）：
##   "intro"  黑畫面上一行一行打出衛星定位的字（地點、座標、時間）
##   "press"  暴風雪的夜晚：研究站的探照燈掃過雪地，主角的剪影站在前景；標題浮現，「PRESS ANY BUTTON」閃爍
##   "menu"   按下去之後（槍聲＋閃光），標題往上移、選單出現（選單本身是 title.tscn 的按鈕）
## 上下的黑邊是電影的寬銀幕比例。原創畫面，不使用任何既有作品的標誌或文字。
class_name TitleBackdrop
extends Control

const INTRO_LINES := [
	"SAT-LINK  //  NORTHERN RELAY 7",
	"78°14'N   015°31'E   -  GREYCROW ISLAND",
	"NOVEMBER 2026   04:12 LOCAL",
	"SIGNAL: 126.05 MHz   -   SOURCE UNKNOWN",
]
const INTRO_TIME := 4.2
const BAR := 18.0

var phase := "intro"
var t := 0.0
var _phase_t := 0.0
var _flash := 0.0
var _snow: Array[Vector3] = []
var _rnd := RandomNumberGenerator.new()
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Cubic_11.ttf")
	_rnd.seed = 2026
	for i in 140:
		_snow.append(Vector3(_rnd.randf(), _rnd.randf(), _rnd.randf_range(0.25, 1.0)))


func set_phase(p: String) -> void:
	if p == "menu" and phase != "menu":
		_flash = 1.0
	phase = p
	_phase_t = 0.0


func _process(delta: float) -> void:
	t += delta
	_phase_t += delta
	_flash = maxf(_flash - delta * 2.5, 0.0)
	if phase == "intro" and _phase_t > INTRO_TIME:
		set_phase("press")
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.01, 0.012, 0.02))
	if phase == "intro":
		_draw_intro()
		return
	var fade := clampf(_phase_t / 1.6, 0.0, 1.0) if phase == "press" else 1.0
	_draw_scene(w, h, fade)
	_draw_logo(w, h, fade)
	if phase == "press" and _phase_t > 1.6 and int(t * 1.6) % 2 == 0:
		_text_center("PRESS ANY BUTTON", h - BAR - 26, Color(0.85, 0.87, 0.9, 0.9))
	# 寬銀幕黑邊
	draw_rect(Rect2(0, 0, w, BAR), Color.BLACK)
	draw_rect(Rect2(0, h - BAR, w, BAR), Color.BLACK)
	_text(Vector2(w - 70, h - 5), "ver 0.9 DEV", Color(0.35, 0.37, 0.4))
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, _flash * 0.6))


func _draw_intro() -> void:
	# 一個字一個字打出來，最後一行的游標閃爍
	var chars := int(_phase_t * 34.0)
	var y := 96.0
	for line: String in INTRO_LINES:
		var shown := line.substr(0, clampi(chars, 0, line.length()))
		_text(Vector2(64, y), shown, Color(0.72, 0.78, 0.74))
		chars -= line.length() + 6
		y += 18.0
		if chars < 0:
			if int(t * 3.0) % 2 == 0:
				draw_rect(Rect2(64 + _font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 1, y - 28, 5, 11), Color(0.72, 0.78, 0.74))
			break
	# 結尾淡入白噪音
	var k := clampf((_phase_t - INTRO_TIME + 0.8) / 0.8, 0.0, 1.0)
	if k > 0.0:
		for i in 300:
			var p := Vector2(_rnd.randf() * size.x, _rnd.randf() * size.y).floor()
			draw_rect(Rect2(p, Vector2.ONE), Color(1, 1, 1, 0.5 * k))


func _draw_scene(w: float, h: float, fade: float) -> void:
	var horizon := floorf(h * 0.62)
	# 夜空（很暗的藍黑漸層）
	for y in int(horizon):
		var k := float(y) / horizon
		draw_rect(Rect2(0, y, w, 1), Color(0.02, 0.03, 0.06).lerp(Color(0.07, 0.09, 0.13), k) * fade)
	# 遠方的山稜
	for x in int(w):
		var m := horizon - 6.0 - absf(sin(x * 0.017 + 0.6) * 18.0 + sin(x * 0.051) * 5.0)
		draw_rect(Rect2(x, m, 1, horizon - m), Color(0.04, 0.05, 0.08) * fade)
	# 雪地
	for y in range(int(horizon), int(h)):
		var k := float(y - horizon) / (h - horizon)
		draw_rect(Rect2(0, y, w, 1), Color(0.1, 0.12, 0.16).lerp(Color(0.2, 0.23, 0.28), k) * fade)
	# 研究站（右邊）：主建築、兩扇亮著的窗、天線塔
	var sx := floorf(w * 0.6)
	var sy := horizon - 22.0
	var dark := Color(0.015, 0.018, 0.028) * fade + Color(0, 0, 0, 1.0 - fade)
	draw_rect(Rect2(sx, sy, 120, 24), dark)
	draw_rect(Rect2(sx + 18, sy - 10, 46, 10), dark)
	draw_rect(Rect2(sx + 92, sy - 6, 22, 6), dark)
	for wx: float in [sx + 24, sx + 52, sx + 100]:
		var lit: bool = wx != sx + 52 or int(t * 0.7) % 5 != 0
		draw_rect(Rect2(wx, sy + 8, 4, 3), Color(1.0, 0.72, 0.35, 0.9 * fade) if lit else dark)
	var tx := sx + 150.0
	draw_line(Vector2(tx - 6, horizon), Vector2(tx, horizon - 70), dark, 1.0)
	draw_line(Vector2(tx + 6, horizon), Vector2(tx, horizon - 70), dark, 1.0)
	for i in 7:
		var yy := lerpf(horizon, horizon - 70, float(i) / 7.0)
		var half := lerpf(6.0, 0.0, float(i) / 7.0)
		draw_line(Vector2(tx - half, yy), Vector2(tx + half, yy), dark, 1.0)
	if int(t * 1.2) % 2 == 0:
		draw_rect(Rect2(tx - 1, horizon - 73, 2, 2), Color(1.0, 0.15, 0.1, fade))
	# 探照燈：從屋頂掃過雪地
	var origin := Vector2(sx + 40, sy - 10)
	var ang := PI * 0.5 + sin(t * 0.35) * 0.9
	var reach := 260.0
	var a1 := Vector2.from_angle(ang - 0.07) * reach
	var a2 := Vector2.from_angle(ang + 0.07) * reach
	draw_colored_polygon(PackedVector2Array([origin, origin + a1 + Vector2(-reach * 0.6, 0), origin + a2 + Vector2(-reach * 0.6, 0)]),
		Color(0.85, 0.9, 1.0, 0.07 * fade))
	draw_circle(origin, 2.0, Color(1, 1, 0.9, fade))
	# 前景的主角剪影（左下，面向研究站；圍巾被風吹動）
	var px := floorf(w * 0.24)
	var py := h - BAR - 26.0
	var sil := Color(0.0, 0.0, 0.0, fade)
	draw_rect(Rect2(px - 4, py - 22, 9, 10), sil)       # 頭（兜帽）
	draw_rect(Rect2(px - 6, py - 13, 13, 15), sil)      # 身體（外套）
	draw_rect(Rect2(px - 5, py + 2, 4, 9), sil)         # 腿
	draw_rect(Rect2(px + 2, py + 2, 4, 9), sil)
	draw_rect(Rect2(px - 8, py - 11, 3, 11), sil)       # 手臂
	draw_rect(Rect2(px + 6, py - 11, 3, 10), sil)
	var flap := int(t * 6.0) % 3
	draw_rect(Rect2(px - 10 - flap, py - 15, 6 + flap, 2), sil)  # 圍巾
	draw_rect(Rect2(px - 30, py + 10, 60, 2), Color(0, 0, 0, 0.35 * fade))  # 影子
	# 暴風雪：斜著吹的雪，近的大、快
	for s in _snow:
		var sp := 30.0 + 90.0 * s.z
		var p := Vector2(fposmod(s.x * w - t * sp * 0.9, w), fposmod(s.y * h + t * sp * 0.45, h))
		var sz := 2.0 if s.z > 0.85 else 1.0
		draw_rect(Rect2(p.floor(), Vector2(sz, sz)), Color(0.85, 0.88, 0.95, (0.25 + 0.5 * s.z) * fade))


func _draw_logo(w: float, h: float, fade: float) -> void:
	# 標題：選單出現後往上移；一道反光從左掃到右
	var k := clampf((_phase_t - 0.6) / 1.4, 0.0, 1.0) if phase == "press" else 1.0
	var y := 62.0 if phase == "press" else lerpf(62.0, 44.0, clampf(_phase_t / 0.5, 0.0, 1.0))
	var title := "A F T E R S I G N A L"
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var at := Vector2(floorf((w - tw) * 0.5), y)
	draw_string(_font, at + Vector2(2, 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0, 0, 0, 0.8 * k))
	draw_string(_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.86, 0.88, 0.9, k))
	var glint := fmod(t * 0.35, 1.6) * (tw + 80.0) - 40.0
	if glint > 0.0 and glint < tw:
		draw_rect(Rect2(at.x + glint, at.y - 18, 3, 22), Color(1, 1, 1, 0.35 * k))
	# 紅色的細線＋中文標題＋類型
	draw_rect(Rect2(floorf(w * 0.5 - tw * 0.5), y + 6, tw, 1), Color(0.75, 0.12, 0.1, k))
	_text_center("迴 頻", y + 30, Color(0.82, 0.18, 0.14, k), 24)
	_text_center("SURVIVAL  ・  STEALTH  ・  HORROR", y + 48, Color(0.55, 0.58, 0.62, k * fade))


func _text(at: Vector2, s: String, c: Color, fs := 12) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


func _text_center(s: String, y: float, c: Color, fs := 12) -> void:
	var tw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(floorf(size.x * 0.5 - tw * 0.5), y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
