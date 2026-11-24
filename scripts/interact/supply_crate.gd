## 補給箱：一次拿到幾個空瓶（之後也會有彈藥、藥品）。
class_name SupplyCrate
extends Interactable

@export var bottles := 2


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Open crate"


func interact(player: Player) -> void:
	player.bottles = mini(player.bottles + bottles, player.max_bottles)
	take()


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	draw_rect(Rect2(-7, -5, 14, 10), Color(0.55, 0.42, 0.25))
	draw_rect(Rect2(-7, -5, 14, 10), Color(0.75, 0.6, 0.35), false, 1.0)
	draw_rect(Rect2(-1, -5, 2, 10), Color(0.85, 0.3, 0.25))
