## 樓梯：原型的終點（二樓還沒做）。
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
	return "Go upstairs"


func interact(_player: Player) -> void:
	reached.emit()


func _draw() -> void:
	for i in 3:
		draw_rect(Rect2(-6, -6 + i * 4, 12, 3), Color(0.3, 0.55 + i * 0.1, 0.38))
