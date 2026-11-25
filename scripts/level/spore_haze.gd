## 訊號霧（舊名孢子區，類別名稱保留）：迴頻訊號太強的地方，空氣裡浮著青色／洋紅色的雜訊碎片，
## 地板偏藍紫、偶爾整片閃一下（像壞掉的螢幕）。危險類型 id 仍是 "spores"（存檔相容）。
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
		var glitch := 0.1 if fmod(_t * 3.1 + float(r.position.x), 4.0) < 0.12 else 0.0
		draw_rect(Rect2(Vector2(r.position) * Level.TILE, Vector2(r.size) * Level.TILE), Color(0.35, 0.25, 0.75, 0.2 + glitch))
	for m in _motes:
		var rect: Rect2 = m.rect
		var p: Vector2 = m.p + Vector2(sin(_t * m.sp + m.ph) * 6.0, fmod(-_t * 4.0 * m.sp, rect.size.y))
		p.y = rect.position.y + fposmod(p.y - rect.position.y, rect.size.y)
		var a := 0.5 + 0.35 * sin(_t * 2.0 + m.ph)
		# 雜訊碎片：橫向的短線，青色和洋紅色交錯
		var w := 3.0 if int(m.ph * 10.0) % 3 == 0 else 1.0
		var col := Color(0.35, 1.0, 0.95, a) if int(m.ph * 7.0) % 2 == 0 else Color(1.0, 0.35, 0.85, a)
		draw_rect(Rect2(p.floor(), Vector2(w, 1)), col)
