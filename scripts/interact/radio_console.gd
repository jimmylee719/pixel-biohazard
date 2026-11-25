## 安全屋的無線電：存檔，並接收新的支線委託（遠端的微生物學家 Kovac 會透過它聯絡你）。
class_name RadioConsole
extends Interactable

signal used

var _glow: PointLight2D


func _ready() -> void:
	_glow = PointLight2D.new()
	_glow.texture = LightTextures.make_radial()
	_glow.texture_scale = 22.0 / (LightTextures.SIZE * 0.5)
	_glow.color = Color(1.0, 0.75, 0.35)
	_glow.energy = 0.8
	add_child(_glow)


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Radio (save)"


func interact(_player: Player) -> void:
	Sfx.play("radio_static", global_position)
	used.emit()


func _draw() -> void:
	draw_rect(Rect2(-7, -5, 14, 9), Color(0.25, 0.27, 0.22))
	draw_rect(Rect2(-7, -5, 14, 9), Color(0.5, 0.52, 0.42), false, 1.0)
	draw_rect(Rect2(-5, -3, 6, 4), Color(0.9, 0.7, 0.3))
	draw_line(Vector2(4, -5), Vector2(6, -10), Color(0.6, 0.6, 0.6), 1.0)
