## 裝飾用的光：壁燈在牆面和地上的光暈、螢幕和儀器的微光、警示燈的紅光。
## 用加色的小圖疊在 Structure 圖層（不是 PointLight2D）：很便宜、網頁和手機都能跑，
## 也「不影響」潛行的明暗判定（Level.is_lit、主角身上的光）——只是讓場景有氣氛、看得出哪裡有燈。
## 沒電的時候只剩很暗的緊急照明；恢復電力（或 lit 的區域）才亮。畫一次，電力狀態變了才重畫。
class_name LightAccents
extends Node2D

const LAMP := Color(1.0, 0.82, 0.52)
const DECOR_GLOW := {"monitor": Color(0.35, 1.0, 0.8), "alarm": Color(1.0, 0.25, 0.2), "exit_sign": Color(0.3, 1.0, 0.5),
	"sign_bio": Color(1.0, 0.7, 0.2), "fuse_panel": Color(1.0, 0.75, 0.3)}

var level: Level
var faces: WallFaces
var _powered := false


func setup(lv: Level, wall_faces: WallFaces) -> void:
	level = lv
	faces = wall_faces
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_powered = WorldState.power_on
	queue_redraw()


func _process(_delta: float) -> void:
	if WorldState.power_on != _powered:
		_powered = WorldState.power_on
		queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var pool := Art.tex("decor/glow_pool")
	var small := Art.tex("decor/glow_small")
	var wall := Art.tex("decor/glow_wall")
	if pool == null or small == null or wall == null:
		return
	var t := float(Level.TILE)
	for c in faces.decor:
		var name: String = faces.decor[c]
		var at := (Vector2(c) + Vector2(0.5, 0.0)) * t
		var k := 1.0 if level.is_lit_at(at + Vector2(0, t * 1.5)) else 0.3
		if name == "lamp":
			_glow(wall, at + Vector2(0, 5), Vector2(28, 20), LAMP, 0.42 * k)
			_glow(pool, at + Vector2(0, t + 13), Vector2(56, 40), LAMP, 0.26 * k)
		elif DECOR_GLOW.has(name):
			_glow(small, at + Vector2(0, 8), Vector2(24, 24), DECOR_GLOW[name], 0.3 * maxf(k, 0.6))
	for a in level.accent_lights:
		var k := 1.0 if level.is_lit_at(a.pos) else 0.45
		_glow(pool, a.pos, a.size, a.color, float(a.power) * k)


func _glow(tex: Texture2D, center: Vector2, size: Vector2, color: Color, power: float) -> void:
	draw_texture_rect(tex, Rect2((center - size * 0.5).floor(), size), false, Color(color.r * power, color.g * power, color.b * power, 1.0))
