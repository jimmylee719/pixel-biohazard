## 出口：原型的終點。
class_name ExitPoint
extends Interactable

signal reached

var _glow: PointLight2D


func _ready() -> void:
	_glow = PointLight2D.new()
	_glow.texture = LightTextures.make_radial()
	_glow.texture_scale = 24.0 / (LightTextures.SIZE * 0.5)
	_glow.color = Color(0.5, 1.0, 0.6)
	_glow.energy = 0.7
	add_child(_glow)


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Escape"


func interact(_player: Player) -> void:
	reached.emit()


func _draw() -> void:
	draw_rect(Rect2(-6, -6, 12, 12), Color(0.25, 0.6, 0.35), false, 1.0)
	draw_rect(Rect2(-2, -2, 4, 4), Color(0.4, 0.9, 0.5))
