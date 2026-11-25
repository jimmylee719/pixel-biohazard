## 火：汽油彈落地、或點燃的油桶。
## - 範圍內的敵人每隔一段時間受到燒傷（不會因此知道你在哪）；睡著的凍眠體被熱醒。
## - 主角站在火裡也會受傷。
## - 會發光（附近的東西看得到，你站在火光裡也比較容易被發現），也是熱源（失溫）。
## - 滅火器可以撲滅。duration = 0 表示一直燒（油桶）。
class_name Fire
extends Node2D

signal extinguished

const TICK := 0.5
const GROUP := "fires"

var radius := 24.0
var duration := 6.0
## 每一次燒傷的傷害
var damage_per_tick := 9.0
## 會不會燒到人（油桶的火在桶子裡，只發光發熱）
var harmful := true
## 火光照亮的範圍
var light_radius := 80.0
## 熱源範圍（失溫）
var warm_radius := 56.0

var _age := 0.0
var _tick := 0.0
var _light: PointLight2D


func _ready() -> void:
	add_to_group(GROUP)
	Sfx.attach_loop(self, "fire_loop")
	_light = PointLight2D.new()
	_light.texture = LightTextures.make_radial()
	_light.texture_scale = light_radius / (LightTextures.SIZE * 0.5)
	_light.color = Color(1.0, 0.6, 0.3)
	_light.energy = 1.1
	_light.shadow_enabled = true
	add_child(_light)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 1
	NoiseBus.emit_noise(global_position, 3.0 * Player.TILE, self)  # 點燃的「轟」一聲


func _physics_process(delta: float) -> void:
	_age += delta
	if duration > 0.0 and _age >= duration:
		put_out()
		return
	_light.energy = 0.95 + 0.25 * sin(_age * 17.0) + randf() * 0.1
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_burn()
	queue_redraw()


func _burn() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		var d := enemy.global_position.distance_to(global_position)
		if enemy.is_dormant and d <= warm_radius:
			enemy.wake(global_position)  # 熱醒
		if harmful and d <= radius + 6.0:
			enemy.burn(damage_per_tick)
	if harmful:
		for node in get_tree().get_nodes_in_group("player"):
			var player := node as Player
			if player and player.global_position.distance_to(global_position) <= radius:
				player.take_hit(damage_per_tick, 0.0, global_position)


func is_lighting(point: Vector2) -> bool:
	return point.distance_to(global_position) <= light_radius * 0.8


func is_warming(point: Vector2) -> bool:
	return point.distance_to(global_position) <= warm_radius


func put_out() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(GROUP)
	extinguished.emit()
	queue_free()


## 某一點附近有沒有火光
static func lit_at(tree: SceneTree, point: Vector2) -> bool:
	for f in tree.get_nodes_in_group(GROUP):
		if f.is_lighting(point):
			return true
	return false


static func warm_at(tree: SceneTree, point: Vector2) -> bool:
	for f in tree.get_nodes_in_group(GROUP):
		if f.is_warming(point):
			return true
	return false


func _draw() -> void:
	var fade := 1.0
	if duration > 0.0:
		fade = clampf((duration - _age) / 1.5, 0.3, 1.0)
	var r := radius * (0.85 + 0.15 * fade)
	draw_circle(Vector2.ZERO, r, Color(0.9, 0.35, 0.1, 0.28 * fade))
	for i in 7:
		var a := TAU * i / 7.0 + _age * 2.0
		var p := Vector2.RIGHT.rotated(a) * r * (0.3 + 0.5 * fmod(i * 0.37 + _age, 1.0))
		var h := 3.0 + 3.0 * sin(_age * 11.0 + i)
		draw_rect(Rect2(p - Vector2(1.5, h), Vector2(3, h)), Color(1.0, 0.7 if i % 2 else 0.45, 0.15, 0.85 * fade))
