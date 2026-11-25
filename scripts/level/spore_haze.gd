## 孢子區的視覺：地板偏綠、空氣裡飄著發光的孢子（受光影響：手電筒照到才看得清楚，很恐怖）。
class_name SporeHaze
extends Node2D

var level: Level
var _motes: Array[Dictionary] = []
var _t := 0.0


func setup(lv: Level) -> void:
	level = lv
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash(lv.area_id)
	for h in lv._data.get("hazards", []):
		var r: Rect2i = h.rect
		var area := Rect2(Vector2(r.position) * Level.TILE, Vector2(r.size) * Level.TILE)
		for i in int(r.size.x * r.size.y * 1.2):
			_motes.append({"p": area.position + Vector2(rnd.randf() * area.size.x, rnd.randf() * area.size.y),
				"ph": rnd.randf() * TAU, "sp": rnd.randf_range(0.4, 1.2), "rect": area})


func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for h in level._data.get("hazards", []):
		var r: Rect2i = h.rect
		draw_rect(Rect2(Vector2(r.position) * Level.TILE, Vector2(r.size) * Level.TILE), Color(0.35, 0.65, 0.2, 0.22))
	for m in _motes:
		var rect: Rect2 = m.rect
		var p: Vector2 = m.p + Vector2(sin(_t * m.sp + m.ph) * 6.0, fmod(-_t * 4.0 * m.sp, rect.size.y))
		p.y = rect.position.y + fposmod(p.y - rect.position.y, rect.size.y)
		var a := 0.5 + 0.35 * sin(_t * 2.0 + m.ph)
		var size := 2.0 if int(m.ph * 10.0) % 3 == 0 else 1.0
		draw_rect(Rect2(p.floor(), Vector2(size, size)), Color(0.8, 1.0, 0.5, a))
