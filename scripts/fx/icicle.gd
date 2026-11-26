## Boss 戰的落冰：地上先出現一圈越來越大的影子（預告 warn 秒），然後一根冰錐砸下來。
## 砸中範圍內的主角受傷，砸下來的聲音敵人也聽得到（苔原之母會衝過來）。
class_name Icicle
extends Node2D

const RADIUS := 13.0

var warn := 1.1
var damage := 22.0
var _t := 0.0
var _done := false


static func drop(parent: Node, pos: Vector2, warn_time := 1.1) -> Icicle:
	var ic := Icicle.new()
	ic.position = pos
	ic.warn = warn_time
	ic.z_index = 3
	parent.add_child(ic)
	return ic


func _ready() -> void:
	# 預告要在黑暗中也看得到
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t >= warn:
		_done = true
		Sfx.play("bottle_break", global_position, 0.2, 2.0)
		NoiseBus.emit_noise(global_position, 6.0 * Level.TILE, self)
		for p in get_tree().get_nodes_in_group("player"):
			if p is Player and not p.is_dead and p.global_position.distance_to(global_position) <= RADIUS:
				p.take_hit(damage, 4.0, global_position)
	if _t > warn + 0.6:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _t < warn:
		var k := _t / warn
		draw_circle(Vector2.ZERO, RADIUS * (0.3 + 0.7 * k), Color(0.6, 0.8, 1.0, 0.12 + 0.15 * k))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color(1.0, 0.35, 0.3, 0.4 + 0.5 * k), 1.0)
		# 冰錐從上面掉下來（最後 0.25 秒）
		var fall := clampf((_t - warn + 0.25) / 0.25, 0.0, 1.0)
		if fall > 0.0:
			var y := lerpf(-90.0, 0.0, fall)
			draw_colored_polygon(PackedVector2Array([Vector2(-3, y - 14), Vector2(3, y - 14), Vector2(0, y)]), Color(0.8, 0.95, 1.0))
	else:
		var k := (_t - warn) / 0.6
		for i in 7:
			var a := float(i) / 7.0 * TAU
			draw_rect(Rect2((Vector2.from_angle(a) * (4.0 + k * 14.0)).floor(), Vector2(2, 2)), Color(0.85, 0.95, 1.0, 1.0 - k))
