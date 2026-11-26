## 安全屋無線電的面板上半部（原創的「野戰無線電」外觀）：
## 類比刻度盤（120～130 MHz，備忘錄裡的頻率有小三角形），紅色指針＝目前的頻率；
## 右邊是訊號強度表；下面是示波器的波形：沒對準是雜訊，越接近電台波形越乾淨，對準了是清楚的正弦波。
class_name RadioDial
extends Control

var freq := 12150
var known: Array = []
var strength := 0.0
var _t := 0.0
var _font: Font
var _needle := 12150.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Cubic_11.ttf")


func _process(delta: float) -> void:
	_t += delta
	_needle = lerpf(_needle, float(freq), 1.0 - exp(-12.0 * delta))
	queue_redraw()


func _x_of(f: float, r: Rect2) -> float:
	return r.position.x + (f - Frequencies.BAND_MIN) / float(Frequencies.BAND_MAX - Frequencies.BAND_MIN) * r.size.x


func _draw() -> void:
	var w := size.x
	var amber := Color(1, 0.8, 0.45)
	var dim := Color(0.45, 0.38, 0.25)
	# 刻度盤
	var dial := Rect2(6, 4, w - 78, 22)
	draw_rect(dial, Color(0.07, 0.06, 0.04))
	draw_rect(dial, dim, false, 1.0)
	for f in range(Frequencies.BAND_MIN, Frequencies.BAND_MAX + 1, 50):
		var x := floorf(_x_of(f, dial))
		var major := f % 200 == 0
		draw_rect(Rect2(x, dial.end.y - (8 if major else 4), 1, 8 if major else 4), amber if major else dim)
		if major:
			draw_string(_font, Vector2(x - 8, dial.position.y + 10), "%d" % (f / 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	for k in known:
		var x := floorf(_x_of(k, dial))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, dial.end.y + 3), Vector2(x + 2, dial.end.y + 3), Vector2(x, dial.end.y)]), amber)
	var nx := floorf(_x_of(_needle, dial))
	draw_rect(Rect2(nx, dial.position.y - 2, 1, dial.size.y + 4), Color(1, 0.25, 0.15))
	# 訊號強度表（10 格）
	var meter := Rect2(w - 66, 4, 60, 22)
	draw_rect(meter, Color(0.07, 0.06, 0.04))
	draw_rect(meter, dim, false, 1.0)
	var bars := roundi(strength * 10.0)
	for i in 10:
		var bh := 3.0 + i * 1.6
		var col := amber if i < bars else Color(0.18, 0.15, 0.1)
		draw_rect(Rect2(meter.position.x + 4 + i * 5.5, meter.end.y - 3 - bh, 4, bh), col)
	# 示波器
	var scope := Rect2(6, 32, w - 12, 22)
	draw_rect(scope, Color(0.03, 0.05, 0.04))
	draw_rect(scope, dim, false, 1.0)
	var mid := scope.position.y + scope.size.y * 0.5
	var prev := Vector2(scope.position.x, mid)
	var noise := 1.0 - strength
	for i in range(1, int(scope.size.x)):
		var x := scope.position.x + i
		var clean := sin(i * 0.22 + _t * 9.0) * 7.0 * strength
		var hiss := (fmod(sin(i * 12.9898 + floorf(_t * 30.0) * 78.233) * 43758.5453, 1.0) - 0.5) * 16.0 * noise
		var p := Vector2(x, mid + clampf(clean + hiss, -10.0, 10.0))
		draw_line(prev, p, Color(0.45, 1.0, 0.6, 0.85), 1.0)
		prev = p
