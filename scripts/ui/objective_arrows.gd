## 任務指引：在主角腳邊畫小小的箭頭，指向勾選的任務該往哪走（沿著走得到的路，不是直線穿牆）。
## 每個任務一種顏色（主線黃色；支線藍、紫、紅、綠、白）。箭頭很小、半透明，離目標很近時換成目標上方的小菱形。
## 目標在別張地圖 = 指向通往那邊的門／樓梯。main 每 0.25 秒更新一次路線（targets）。
class_name ObjectiveArrows
extends Control

const RADIUS := 19.0
const NEAR := 40.0

var main: Node
## [{color, pos（世界座標：目標或要走的門）, dir（從主角出發該走的方向）}]
var targets: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if main == null or main._player == null or main._camera == null or targets.is_empty():
		return
	var cam: Camera2D = main._camera
	var view := get_viewport_rect().size
	var z := cam.zoom.x
	var center := cam.get_screen_center_position()
	var pp: Vector2 = (main._player.global_position - center) * z + view * 0.5
	var used: Array[float] = []
	for t in targets:
		var col: Color = t.color
		var to: Vector2 = t.pos - main._player.global_position
		if to.length() < NEAR:
			# 很近了：目標上方一個上下浮動的小菱形
			var sp: Vector2 = (t.pos - center) * z + view * 0.5 + Vector2(0, -14.0 * z + sin(_t * 4.0) * 1.5)
			draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -3), sp + Vector2(3, 0), sp + Vector2(0, 3), sp + Vector2(-3, 0)]),
				Color(col, 0.9))
			continue
		var dir: Vector2 = t.dir
		if dir == Vector2.ZERO:
			continue
		# 兩個箭頭方向差不多時，後面的往外排一點才不會疊在一起
		var ang := dir.angle()
		var r := RADIUS * z
		for a in used:
			if absf(angle_difference(a, ang)) < 0.5:
				r += 6.0
		used.append(ang)
		var tip := pp + Vector2(0, 2) + dir * (r + 1.5 * sin(_t * 5.0))
		var side := dir.orthogonal()
		var pts := PackedVector2Array([tip + dir * 4.0, tip - dir * 1.5 + side * 3.0, tip - dir * 0.2, tip - dir * 1.5 - side * 3.0])
		draw_colored_polygon(pts, Color(col, 0.85))
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.55), 1.0)
