## 儲物箱：所有安全屋共用同一個空間，用不到的東西放這裡。
class_name StorageBox
extends Interactable

signal opened


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Storage box"


func interact(_player: Player) -> void:
	opened.emit()


func _draw() -> void:
	draw_rect(Rect2(-7, -5, 14, 10), Color(0.35, 0.4, 0.45))
	draw_rect(Rect2(-7, -5, 14, 10), Color(0.6, 0.66, 0.72), false, 1.0)
	draw_line(Vector2(-7, -1), Vector2(7, -1), Color(0.6, 0.66, 0.72), 1.0)
