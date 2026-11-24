## 滅火器噴出的白霧：幾秒內擋住敵人的視線（手電筒也照不穿）。
class_name SmokeCloud
extends Node2D

const GROUP := "smoke"

var radius := 34.0
var duration := 4.5

var _age := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	z_index = 2
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func current_radius() -> float:
	return radius * clampf(0.6 + _age * 1.5, 0.0, 1.0)


## 從 a 到 b 的視線有沒有穿過任何一團霧
static func blocks(tree: SceneTree, a: Vector2, b: Vector2) -> bool:
	for c in tree.get_nodes_in_group(GROUP):
		var closest := Geometry2D.get_closest_point_to_segment(c.global_position, a, b)
		if closest.distance_to(c.global_position) <= c.current_radius():
			return true
	return false


func _draw() -> void:
	var alpha := 0.55 * clampf((duration - _age) / 1.5, 0.0, 1.0)
	var r := current_radius()
	for i in 6:
		var p := Vector2.RIGHT.rotated(TAU * i / 6.0 + _age * 0.3) * r * 0.45
		draw_circle(p, r * 0.6, Color(0.9, 0.92, 0.95, alpha * 0.6))
	draw_circle(Vector2.ZERO, r * 0.7, Color(0.95, 0.96, 1.0, alpha))
