## 丟出去的空瓶：飛一小段拋物線，落地時發出聲音。
class_name ThrownBottle
extends Node2D

const FLIGHT_TIME := 0.45
const ARC_HEIGHT := 10.0
const SHARDS_TIME := 0.6

var noise_radius := 96.0

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _landed := false


func launch(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	global_position = from


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		var k := minf(_t / FLIGHT_TIME, 1.0)
		global_position = _from.lerp(_to, k)
		if k >= 1.0:
			_landed = true
			_t = 0.0
			NoiseBus.emit_noise(_to, noise_radius, self)
	elif _t >= SHARDS_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if not _landed:
		var lift := sin(PI * minf(_t / FLIGHT_TIME, 1.0)) * ARC_HEIGHT
		draw_rect(Rect2(Vector2(-1.5, -1.5 - lift), Vector2(3, 3)), Color(0.6, 0.9, 0.7))
	else:
		var spread := 2.0 + _t * 10.0
		for i in 5:
			var dir := Vector2.RIGHT.rotated(TAU * i / 5.0 + 0.4)
			draw_rect(Rect2(dir * spread - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.6, 0.9, 0.7))
