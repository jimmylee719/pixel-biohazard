## 噴孢者吐出的孢子團：從嘴巴飛到目標（拋物線），落地時炸開一圈綠色的孢子。只是視覺（命中在 Enemy._fire_ranged 算好）。
class_name SporeGlob
extends Node2D

const FLIGHT := 0.35

var from := Vector2.ZERO
var to := Vector2.ZERO
var _t := 0.0


static func launch(parent: Node, a: Vector2, b: Vector2, hit: bool) -> SporeGlob:
	var g := SporeGlob.new()
	g.from = a
	# 沒打中：落在目標旁邊一點
	g.to = b if hit else b + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	g.z_index = 5
	parent.add_child(g)
	return g


func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _process(delta: float) -> void:
	_t += delta
	if _t > FLIGHT + 0.5:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _t < FLIGHT:
		var k := _t / FLIGHT
		var p := from.lerp(to, k) + Vector2(0, -sin(k * PI) * 14.0)
		draw_circle(p, 2.5, Color(0.55, 0.85, 0.25))
		draw_circle(p, 1.2, Color(0.9, 1.0, 0.6))
		draw_circle(from.lerp(to, maxf(k - 0.12, 0.0)) + Vector2(0, -sin(maxf(k - 0.12, 0.0) * PI) * 14.0), 1.5, Color(0.5, 0.8, 0.2, 0.5))
	else:
		var k := (_t - FLIGHT) / 0.5
		draw_circle(to, 3.0 + k * 9.0, Color(0.5, 0.8, 0.2, 0.45 * (1.0 - k)))
		for i in 6:
			var a := float(i) / 6.0 * TAU
			draw_rect(Rect2((to + Vector2.from_angle(a) * (3.0 + k * 10.0)).floor(), Vector2(1, 1)), Color(0.85, 1.0, 0.5, 1.0 - k))
