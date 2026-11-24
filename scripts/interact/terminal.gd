## 終端機：讀取紀錄（內容在區域資料的 messages）。
class_name Terminal
extends Interactable

signal used(item_name: String)

var _glow: PointLight2D


func _ready() -> void:
	_glow = PointLight2D.new()
	_glow.texture = LightTextures.make_radial()
	_glow.texture_scale = 26.0 / (LightTextures.SIZE * 0.5)
	_glow.color = Color(0.45, 0.85, 1.0)
	_glow.energy = 0.8
	add_child(_glow)


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Use terminal"


func interact(_player: Player) -> void:
	used.emit(item_name)


func _draw() -> void:
	draw_rect(Rect2(-7, -6, 14, 10), Color(0.2, 0.22, 0.25))
	draw_rect(Rect2(-5, -4, 10, 6), Color(0.3, 0.75, 0.9))
