## 地上的空瓶：撿起來可以丟出去製造聲音，把敵人引開。
class_name BottlePickup
extends Interactable


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding and player.bottles < player.max_bottles


func get_prompt(_player: Player) -> String:
	return "Take bottle"


func interact(player: Player) -> void:
	player.bottles += 1
	take()


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	draw_rect(Rect2(-2, -4, 4, 7), Color(0.45, 0.75, 0.55))
	draw_rect(Rect2(-1, -6, 2, 2), Color(0.6, 0.85, 0.7))
