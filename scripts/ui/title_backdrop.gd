## 標題畫面（潛龍諜影式的開場：電影感、安靜、一個大標題、「按任意鍵」）。全部用程式畫，像素對齊。
## 流程（phase）：
##   "intro"  黑畫面上一行一行打出衛星定位的字（地點、座標、時間）
##   "press"  監聽站的夜晚：天線碟、一圈圈傳出去又折回來的訊號、示波器的波形，戴頭盔的主角剪影站在前景；
##            標誌（調頻刻度環＋繞回來的波形）和標題浮現，「PRESS ANY BUTTON」閃爍
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
	# 背景：監聽站的黑夜。不是雪地：一座朝著地底的天線碟、一圈一圈往外傳又折回來的訊號、一條示波器的波形。
	var horizon := floorf(h * 0.66)
	for y in int(horizon):
		var k := pow(float(y) / horizon, 2.2)
		draw_rect(Rect2(0, y, w, 1), Color(0.012, 0.024, 0.036).lerp(Color(0.07, 0.21, 0.21), k) * fade)
	# 訊號的同心圓：從天線碟往外擴散，傳到最遠再淡掉（「迴頻」＝傳出去的訊號會回來）
	var src := Vector2(floorf(w * 0.7), horizon - 46.0)
	for i in 7:
		var phase_k := fposmod(t * 0.11 + float(i) / 7.0, 1.0)
		var r := 14.0 + phase_k * w * 0.62
		var a := (1.0 - phase_k) * 0.34 * fade
		draw_arc(src, r, PI * 0.92, PI * 2.08, 72, Color(0.35, 0.95, 0.75, a), 1.0, false)
		# 回來的那一圈（比較暗、往內縮）
		var rb := 14.0 + (1.0 - phase_k) * w * 0.62
		draw_arc(src, rb, PI * 1.1, PI * 1.9, 48, Color(0.95, 0.62, 0.22, (1.0 - absf(phase_k - 0.5) * 2.0) * 0.12 * fade), 1.0, false)
	# 地面：一條亮線和它下面的暗面
	for y in range(int(horizon), int(h)):
		var gk := float(y - horizon) / (h - horizon)
		draw_rect(Rect2(0, y, w, 1), Color(0.035, 0.085, 0.09).lerp(Color(0.085, 0.13, 0.14), gk) * fade)
	draw_rect(Rect2(0, horizon, w, 1), Color(0.22, 0.48, 0.45, fade))
	var dark := Color(0.0, 0.004, 0.008, fade)
	# 天線碟（右邊，剪影）：支架、碟面、饋源、頂端的紅燈
	var dx := src.x
	draw_colored_polygon(PackedVector2Array([Vector2(dx - 16, horizon), Vector2(dx + 16, horizon), Vector2(dx + 4, horizon - 40), Vector2(dx - 4, horizon - 40)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(dx - 44, horizon - 52), Vector2(dx + 34, horizon - 82), Vector2(dx + 40, horizon - 70),
		Vector2(dx + 10, horizon - 38), Vector2(dx - 30, horizon - 36)]), dark)
	draw_line(Vector2(dx - 4, horizon - 56), Vector2(dx - 30, horizon - 92), dark, 2.0)
	draw_line(Vector2(dx + 24, horizon - 66), Vector2(dx - 30, horizon - 92), dark, 1.0)
	if int(t * 1.2) % 2 == 0:
		draw_rect(Rect2(dx - 32, horizon - 95, 3, 3), Color(1.0, 0.16, 0.1, fade))
	# 遠處的研究站屋頂（左邊，很低），一扇亮著的窗
	var bx := floorf(w * 0.42)
	draw_rect(Rect2(bx, horizon - 12, 70, 12), dark)
	draw_rect(Rect2(bx + 12, horizon - 18, 26, 6), dark)
	draw_rect(Rect2(bx + 50, horizon - 7, 3, 2), Color(1.0, 0.72, 0.35, 0.85 * fade))
	# 示波器的波形：橫過整個畫面，一段乾淨的正弦波在雜訊裡慢慢移動
	var wy := horizon + 22.0
	var prev := Vector2(0, wy)
	for x in range(0, int(w), 2):
		var env := exp(-pow((float(x) - fposmod(t * 46.0, w + 240.0) + 120.0) / 70.0, 2.0))
		var clean := sin(x * 0.16 - t * 5.0) * 9.0 * env
		var hiss := (fposmod(sin(x * 12.9898 + floorf(t * 24.0) * 78.233) * 43758.5453, 1.0) - 0.5) * 3.0 * (1.0 - env)
		var p := Vector2(x, wy + clean + hiss)
		draw_line(prev, p, Color(0.35, 0.95, 0.72, (0.22 + 0.6 * env) * fade), 1.0)
		prev = p
	# 前景的主角剪影（左下）：戴頭盔、背對鏡頭看著天線，面罩側邊一顆琥珀色的燈
	var px := floorf(w * 0.2)
	var py := h - BAR - 22.0
	var sil := Color(0.0, 0.0, 0.0, fade)
	draw_rect(Rect2(px - 5, py - 25, 11, 9), sil)       # 頭盔
	draw_rect(Rect2(px - 4, py - 27, 9, 2), sil)
	draw_rect(Rect2(px - 7, py - 22, 2, 5), sil)        # 耳罩
	draw_rect(Rect2(px + 6, py - 22, 2, 5), sil)
	draw_rect(Rect2(px - 7, py - 33, 1, 11), sil)       # 天線
	draw_rect(Rect2(px - 7, py - 15, 15, 16), sil)      # 身體
	draw_rect(Rect2(px - 6, py + 1, 5, 12), sil)        # 腿
	draw_rect(Rect2(px + 2, py + 1, 5, 12), sil)
	draw_rect(Rect2(px - 10, py - 13, 3, 12), sil)      # 手臂
	draw_rect(Rect2(px + 8, py - 13, 3, 13), sil)
	draw_rect(Rect2(px + 9, py - 1, 6, 3), sil)         # 手上的槍
	draw_rect(Rect2(px + 6, py - 20, 1, 1), Color(1.0, 0.7, 0.25, fade * (0.6 + 0.4 * sin(t * 2.0))))
	draw_rect(Rect2(px - 26, py + 12, 54, 2), Color(0, 0, 0, 0.4 * fade))
	# 空氣裡漂浮的雜訊點（很慢、很淡）
	for sn in _snow:
		var p2 := Vector2(fposmod(sn.x * w + t * 4.0 * sn.z, w), fposmod(sn.y * h - t * 2.5 * sn.z, h))
		draw_rect(Rect2(p2.floor(), Vector2.ONE), Color(0.5, 0.95, 0.8, (0.05 + 0.16 * sn.z) * fade))


## 標誌（原創）：一個調頻刻度環，裡面的波形從環的缺口傳出去、繞一圈又回到環裡。
func _draw_emblem(c: Vector2, r: float, k: float) -> void:
	var ring := Color(0.86, 0.88, 0.9, k)
	var amber := Color(1.0, 0.68, 0.22, k)
	# 刻度環（右上留一個缺口）
	draw_arc(c, r, PI * 0.02, PI * 1.62, 40, ring, 2.0, false)
	for i in 12:
		var a := PI * 0.02 + float(i) / 11.0 * PI * 1.6
		var d := Vector2.from_angle(a)
		draw_line(c + d * (r + 2.0), c + d * (r + (5.0 if i % 3 == 0 else 3.5)), ring, 1.0)
	# 環裡的波形
	var prev := c + Vector2(-r + 3.0, 0)
	for i in range(1, int(r * 2.0 - 5.0)):
		var x := -r + 3.0 + i
		var env := 1.0 - absf(x) / r
		var p := c + Vector2(x, sin(x * 0.75 - t * 3.0) * r * 0.42 * env)
		draw_line(prev, p, amber, 1.0)
		prev = p
	# 從缺口出去、繞回來的那一道（迴頻）
	draw_arc(c, r + 8.0, -PI * 0.42, PI * 0.16, 16, amber, 1.0, false)
	var tip := c + Vector2.from_angle(PI * 0.16) * (r + 8.0)
	draw_line(tip, tip + Vector2(-4, -1), amber, 1.0)
	draw_line(tip, tip + Vector2(1, -4), amber, 1.0)
	# 指針：停在 126.05
	draw_line(c, c + Vector2.from_angle(-PI * 0.33) * (r - 2.0), Color(0.9, 0.2, 0.15, k), 1.0)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), ring)


func _draw_logo(w: float, h: float, fade: float) -> void:
	# 標誌＋標題：選單出現後往上移；一道反光從左掃到右
	var k := clampf((_phase_t - 0.6) / 1.4, 0.0, 1.0) if phase == "press" else 1.0
	var y := 74.0 if phase == "press" else lerpf(74.0, 50.0, clampf(_phase_t / 0.5, 0.0, 1.0))
	var title := "A F T E R S I G N A L"
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var at := Vector2(floorf((w - tw) * 0.5) + 16.0, y)
	_draw_emblem(Vector2(at.x - 24.0, y - 8.0), 12.0, k)
	draw_string(_font, at + Vector2(2, 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0, 0, 0, 0.8 * k))
	draw_string(_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.86, 0.88, 0.9, k))
	var glint := fmod(t * 0.35, 1.6) * (tw + 80.0) - 40.0
	if glint > 0.0 and glint < tw:
		draw_rect(Rect2(at.x + glint, at.y - 18, 3, 22), Color(1, 1, 1, 0.35 * k))
	# 細線＋中文標題＋類型
	draw_rect(Rect2(at.x, y + 6, tw, 1), Color(1.0, 0.68, 0.22, k))
	_text_center("迴 頻", y + 30, Color(1.0, 0.68, 0.22, k), 24)
	_text_center("STEALTH  ・  SURVIVAL  ・  HORROR", y + 46, Color(0.55, 0.62, 0.62, k * fade))


func _text(at: Vector2, s: String, c: Color, fs := 12) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


func _text_center(s: String, y: float, c: Color, fs := 12) -> void:
	var tw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(floorf(size.x * 0.5 - tw * 0.5), y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
