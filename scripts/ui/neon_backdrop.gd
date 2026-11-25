## 標題畫面的背景：80 年代合成波（synthwave）風格的夜空、條紋太陽、往前捲動的霓虹網格地面，
## 中間是灰鴉島的天線塔剪影（紅燈一閃一閃），飄著雪，偶爾整個畫面像收訊不良一樣錯位一下。
## 全部用程式畫（像素對齊），不需要圖檔。
class_name NeonBackdrop
extends Control

const SKY_TOP := Color(0.03, 0.01, 0.08)
const SKY_MID := Color(0.2, 0.03, 0.28)
const SKY_LOW := Color(0.62, 0.1, 0.45)
const GRID := Color(0.2, 0.95, 1.0)
const SUN_TOP := Color(1.0, 0.85, 0.35)
const SUN_LOW := Color(1.0, 0.2, 0.6)

var _t := 0.0
var _snow: Array[Vector3] = []
var _glitch := 0.0
var _rnd := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rnd.seed = 1962
	for i in 70:
		_snow.append(Vector3(_rnd.randf(), _rnd.randf(), _rnd.randf_range(0.3, 1.0)))


func _process(delta: float) -> void:
	_t += delta
	_glitch = maxf(_glitch - delta, 0.0)
	if _glitch <= 0.0 and _rnd.randf() < delta * 0.25:
		_glitch = 0.12
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := floorf(h * 0.58)
	# 夜空：上暗下亮的漸層（一條一條畫，保持像素感）
	for y in int(horizon):
		var k := float(y) / horizon
		var c := SKY_TOP.lerp(SKY_MID, clampf(k * 1.6, 0.0, 1.0)) if k < 0.6 else SKY_MID.lerp(SKY_LOW, (k - 0.6) / 0.4)
		draw_rect(Rect2(0, y, w, 1), c)
	# 條紋太陽（下半部被一條條切開）
	var sun_c := Vector2(floorf(w * 0.5), horizon - 6)
	var r := floorf(h * 0.22)
	for y in range(int(-r), 1):
		var gap := y > -r * 0.55 and int(y + _t * 6.0) % 5 == 0
		if gap:
			continue
		var half := floorf(sqrt(maxf(r * r - y * y, 0.0)))
		var k := float(y + r) / r
		draw_rect(Rect2(sun_c.x - half, sun_c.y + y, half * 2.0, 1), SUN_TOP.lerp(SUN_LOW, k))
	# 遠山
	for x in int(w):
		var m := horizon - 10.0 - absf(sin(x * 0.021) * 14.0 + sin(x * 0.057 + 1.3) * 6.0)
		draw_rect(Rect2(x, m, 1, horizon - m), Color(0.08, 0.02, 0.14))
	# 天線塔（灰鴉島），塔頂的紅燈
	var tx := floorf(w * 0.72)
	var base_y := horizon - 8.0
	var top_y := horizon - 74.0
	draw_line(Vector2(tx - 9, base_y), Vector2(tx, top_y), Color(0.05, 0.01, 0.1), 2.0)
	draw_line(Vector2(tx + 9, base_y), Vector2(tx, top_y), Color(0.05, 0.01, 0.1), 2.0)
	for i in 6:
		var yy := lerpf(base_y, top_y, float(i) / 6.0)
		var half := lerpf(9.0, 0.0, float(i) / 6.0)
		draw_line(Vector2(tx - half, yy), Vector2(tx + half, yy), Color(0.05, 0.01, 0.1), 1.0)
	if int(_t * 1.5) % 2 == 0:
		draw_rect(Rect2(tx - 1, top_y - 2, 2, 2), Color(1.0, 0.2, 0.2))
		draw_circle(Vector2(tx, top_y - 1), 4.0, Color(1.0, 0.2, 0.2, 0.25))
	# 訊號的同心圓（從塔頂往外擴散）
	for i in 3:
		var rr := fmod(_t * 18.0 + i * 22.0, 66.0)
		draw_arc(Vector2(tx, top_y), rr, PI * 1.05, PI * 1.95, 24, Color(GRID, 0.4 * (1.0 - rr / 66.0)), 1.0)
	# 地面：黑底＋往前捲動的霓虹網格
	draw_rect(Rect2(0, horizon, w, h - horizon), Color(0.02, 0.0, 0.05))
	var depth := h - horizon
	var scroll := fmod(_t * 0.6, 1.0)
	for i in 12:
		var z := (float(i) + scroll) / 12.0
		var yy := horizon + floorf(depth * z * z)
		draw_rect(Rect2(0, yy, w, 1), Color(GRID, 0.25 + 0.6 * z))
	for i in range(-12, 13):
		var x0 := w * 0.5 + i * 8.0
		var x1 := w * 0.5 + i * 70.0
		draw_line(Vector2(x0, horizon), Vector2(x1, h), Color(GRID, 0.45), 1.0)
	draw_rect(Rect2(0, horizon, w, 1), Color(1.0, 0.4, 0.85))
	# 雪
	for s in _snow:
		var p := Vector2(fposmod(s.x * w + sin(_t * s.z + s.y * 9.0) * 6.0, w), fposmod(s.y * h + _t * 14.0 * s.z, h))
		draw_rect(Rect2(p.floor(), Vector2.ONE), Color(0.9, 0.9, 1.0, 0.35 + 0.4 * s.z))
	# 掃描線
	for y in range(0, int(h), 2):
		draw_rect(Rect2(0, y, w, 1), Color(0, 0, 0, 0.12))
	# 收訊不良：偶爾一條錯位的亮帶
	if _glitch > 0.0:
		var gy := floorf(_rnd.randf() * h)
		draw_rect(Rect2(0, gy, w, 3), Color(GRID, 0.35))
		draw_rect(Rect2(0, gy + 3, w, 1), Color(1.0, 0.3, 0.85, 0.4))
