## 結晶共鳴（v0.15）：感染者死掉時，結晶化的骨頭碎裂、發出共鳴。
## 畫面：一圈往外擴的淡青色波紋＋幾片飛散的結晶碎片。聲音事件由 Enemy._resonate() 發出。
class_name ResonanceRing
extends Node2D

const LIFE := 1.1
var radius := 60.0
var _t := 0.0
var _shards: Array = []


func _ready() -> void:
	z_index = 2
	for i in 6:
		var a := TAU * i / 6.0 + randf() * 0.5
		_shards.append([Vector2.RIGHT.rotated(a), 14.0 + randf() * 10.0])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	for j in 2:
		var kk := clampf(k * 1.3 - j * 0.25, 0.0, 1.0)
		if kk <= 0.0:
			continue
		draw_arc(Vector2.ZERO, 4.0 + kk * radius * 0.5, 0.0, TAU, 40, Color(0.6, 0.95, 1.0, 0.6 * (1.0 - kk)), 1.0)
	for s in _shards:
		var p: Vector2 = s[0] * s[1] * minf(k * 2.0, 1.0) + Vector2(0, -6.0 * sin(minf(k * 2.0, 1.0) * PI))
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.75, 0.95, 1.0, 1.0 - k))
